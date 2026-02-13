# Phase 13: Process Foundation - Research

**Researched:** 2026-02-17
**Domain:** macOS subprocess execution — Foundation.Process, PTY, Swift 6 concurrency, PATH resolution, command history persistence
**Confidence:** HIGH (core APIs verified via Apple docs and Swift forums), MEDIUM (Claude CLI TTY behavior), LOW (GSD output parsing specifics)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Cancel behavior
- Graceful shutdown first: send SIGINT, wait (Claude's discretion on timeout duration), then SIGKILL if still running
- Cancellation requires user confirmation before executing
- Cancelled commands are marked with a distinct "cancelled" state, separate from "failed"

#### Queue & blocking
- Per-project queue: each project has its own independent command queue — commands for different projects can run in parallel
- Unlimited queue depth: users can stack as many commands as they want, they run in order
- Queued commands are visible and individually removable before they start

#### Command lifecycle
- Capture per run: command string, project, start time, duration, exit code (basics)
- Store full stdout/stderr output for later review
- Parse GSD-specific metadata from output: phase, plan, task status
- Command history persists to disk across app restarts
- One-click re-run from history: users can re-trigger a previous command with the same parameters

#### Error & recovery
- On non-zero exit: show exit code + contextual recovery suggestions (e.g., "re-run", "check logs")
- If claude CLI path not found: guide user with clear installation/configuration instructions
- Auto-retry once on failure, then stop — user must manually re-trigger after that
- Crashed processes (externally killed, system issues) get a distinct "crashed" state, different from normal failure

### Claude's Discretion
- Graceful shutdown timeout duration (likely 3-5 seconds)
- History retention policy (count-based vs time-based)
- Persistence storage format and location
- GSD output parsing patterns for metadata extraction
- Exact recovery suggestion content per error type

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PROC-01 | User can run a GSD command from the app via embedded command runner | Foundation.Process API with PTY stdin; CommandRunnerService + ProcessActor pattern |
| PROC-02 | App resolves claude CLI path from user's shell environment (PATH augmentation) | `zsh -l -c env` shell environment capture; known install locations fallback |
| PROC-03 | App spawns process with PTY for ANSI color support | Darwin.openpty() pattern; PTY stdin required to prevent claude CLI hanging |
| PROC-04 | User sees live-streamed output as command runs | readabilityHandler on Pipe for stdout/stderr; AsyncStream bridging pattern |
| PROC-05 | User can cancel a running command with process group kill | process.interrupt() (SIGINT) then Darwin.killpg() (SIGKILL); 3-5s timeout window |
| SAFE-01 | Only one command runs per project at a time (queue model) | AsyncStream-based FIFO queue per project; actor isolation for per-project state |
</phase_requirements>

---

## Summary

Phase 13 is a headless process execution engine built on `Foundation.Process` (Swift 6, macOS 14+). The implementation splits into five distinct technical domains: (1) subprocess spawning with PTY for stdin, (2) shell environment capture for PATH resolution, (3) live output streaming via readabilityHandler bridged to AsyncStream, (4) graceful cancellation with SIGINT+SIGKILL, and (5) per-project FIFO queue using AsyncStream.

**Critical blocker discovered in research:** The Claude CLI has a documented fundamental TTY dependency — it hangs indefinitely when spawned from a non-TTY context even with the `-p` flag (GitHub issue #9026, closed as "not planned"). GSD commands run as interactive sessions (not `-p` print mode), which makes this even more critical. The architecture decision to "validate with `claude --version` first; PTY only if claude emits ANSI in non-TTY context" is **incorrect based on current evidence** — PTY for stdin is required just to prevent the CLI from hanging, regardless of ANSI. The spike must validate this and confirm the PTY approach resolves the hang.

**Swift version constraint:** Project uses Swift 6.0, macOS 14.0 deployment target. The `swiftlang/swift-subprocess` package (which would simplify much of this) requires Swift 6.1 and is therefore **not available**. Use `Foundation.Process` directly.

**Primary recommendation:** Use `Darwin.openpty()` for the slave descriptor as stdin for the spawned claude process (prevents hang), while using separate `Pipe` objects for stdout/stderr to enable readabilityHandler streaming. Bridge readabilityHandler callbacks to AsyncStream via `Task { await actor.append(data) }` pattern. Use per-project AsyncStream as the FIFO command queue.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Foundation.Process | macOS 14.0 (built-in) | Spawn and manage child processes | Only stable macOS API for subprocess; swift-subprocess requires Swift 6.1 |
| Foundation.Pipe | macOS 14.0 (built-in) | Connect stdout/stderr to readable FileHandles | Standard IPC mechanism for child process output |
| Darwin (system) | macOS 14.0 (built-in) | openpty(), killpg(), POSIX signals | Required for PTY creation and process group kill |
| Swift Concurrency | Swift 6.0 (built-in) | actor, AsyncStream, Task | Project already uses Swift 6 strict concurrency |
| Foundation.FileManager | macOS 14.0 (built-in) | ApplicationSupport directory for history persistence | Standard macOS file I/O |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AsyncAlgorithms | Already in project (see ProjectService.swift) | debounce, etc. | Project already imports; avoid re-adding if not needed for process phase |
| Foundation.JSONEncoder/JSONDecoder | Built-in | Command history persistence as JSON | Simple, Codable-compatible, human-readable |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Foundation.Process | swiftlang/swift-subprocess | swift-subprocess requires Swift 6.1; project targets Swift 6.0 |
| Foundation.Process | posix_spawnp() | posix_spawn gives more control (e.g., POSIX_SPAWN_SETPGROUP) but requires more boilerplate; Foundation.Process sufficient |
| Darwin.openpty() | forkpty() | forkpty() is unsafe from Swift (fork without exec in Swift runtime); use openpty() instead |
| JSON file persistence | UserDefaults | UserDefaults not suited for large structured history; JSON file in ApplicationSupport is correct |
| JSON file persistence | SwiftData | SwiftData is overkill for this read/append use case; plain Codable JSON is simpler |

**Installation:** No new packages needed — all required APIs are built-in to Swift 6.0 / macOS 14.

## Architecture Patterns

### Recommended Project Structure
```
GSDMonitor/
├── Models/
│   ├── CommandRun.swift          # Codable model: id, command, project, state, output, metadata
│   └── CommandState.swift        # Enum: queued, running, succeeded, failed, cancelled, crashed
├── Services/
│   ├── ProcessActor.swift        # actor: owns one running Foundation.Process, streams output
│   ├── CommandRunnerService.swift # @MainActor @Observable: per-project queues, history, public API
│   └── ShellEnvironmentService.swift # nonisolated: zsh -l -c env, PATH resolution, claude discovery
└── Utilities/
    └── GSDOutputParser.swift     # nonisolated struct: parse GSD metadata from output lines
```

### Pattern 1: ProcessActor — Owns a Single Running Process

**What:** A Swift `actor` that owns one `Foundation.Process` and its associated PTY/Pipes. Exposes an `AsyncStream<OutputLine>` for live output and a cancellation method.

**When to use:** One `ProcessActor` per active command run. Discarded when the process terminates.

**Key design:** Mirrors FileWatcherService's AsyncStream + C callback pattern already in the codebase.

```swift
// Source: Based on FileWatcherService.swift pattern in codebase + Swift Forums PTY guidance
actor ProcessActor {
    private var process: Process?
    private var continuation: AsyncStream<OutputLine>.Continuation?

    // PTY for stdin (prevents claude CLI from hanging in non-TTY context)
    private var ptyMasterFD: Int32 = -1
    private var ptyMasterHandle: FileHandle?

    // Separate pipes for stdout/stderr (enables readabilityHandler streaming)
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    struct OutputLine: Sendable {
        enum Stream { case stdout, stderr }
        let stream: Stream
        let text: String
        let timestamp: Date
    }

    func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        currentDirectoryURL: URL
    ) -> AsyncStream<OutputLine> {
        return AsyncStream<OutputLine> { continuation in
            self.continuation = continuation
            // Setup process, PTY, pipes, readabilityHandler, terminationHandler
            // See Code Examples section
        }
    }

    func cancel() {
        // SIGINT first, then SIGKILL after timeout
        process?.interrupt()  // Sends SIGINT
        // Start 3-5s timer, then Darwin.killpg(pid32, SIGKILL)
    }
}
```

### Pattern 2: Per-Project FIFO Queue via AsyncStream

**What:** Each project gets an `AsyncStream<CommandRequest>` that serializes command execution. Commands are enqueued as values, consumed one at a time by a `Task` that awaits each run to completion before pulling the next.

**Critical note:** Swift actors alone do NOT guarantee FIFO ordering — their executor is not strictly first-in-first-out (confirmed by Apple developer forums and multiple Swift community sources). AsyncStream IS a FIFO queue by design and is the correct primitive here.

```swift
// Source: Swift Forums https://forums.swift.org/t/how-do-you-use-asyncstream-to-make-task-execution-deterministic/57968
// Per-project queue in CommandRunnerService
@MainActor
@Observable
final class CommandRunnerService {
    // One AsyncStream per project ID
    private var queues: [String: (stream: AsyncStream<CommandRequest>, continuation: AsyncStream<CommandRequest>.Continuation)] = [:]
    private var queueTasks: [String: Task<Void, Never>] = [:]

    func enqueue(_ command: CommandRequest, forProject projectID: String) {
        let (stream, continuation) = getOrCreateQueue(for: projectID)
        continuation.yield(command)
    }

    private func startConsuming(projectID: String, stream: AsyncStream<CommandRequest>) {
        queueTasks[projectID] = Task {
            for await request in stream {
                guard !Task.isCancelled else { break }
                await executeCommand(request)  // Awaits full completion before next
            }
        }
    }
}
```

### Pattern 3: readabilityHandler to AsyncStream Bridge (Swift 6 Safe)

**What:** `FileHandle.readabilityHandler` is a callback-based API that cannot directly mutate actor state in Swift 6. Bridge it safely with a `Task` dispatch.

```swift
// Source: Swift Forums https://forums.swift.org/t/swift-6-concurrency-nspipe-readability-handlers/59834
// Inside ProcessActor.run():
stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
    guard let self else { return }
    let data = fileHandle.availableData
    guard !data.isEmpty else { return }  // Empty data = EOF signal (unreliable on macOS)
    if let text = String(data: data, encoding: .utf8) {
        Task {
            // Safe: dispatches to actor's isolated context
            await self.appendOutput(OutputLine(stream: .stdout, text: text, timestamp: Date()))
        }
    }
}

// terminationHandler is the authoritative completion signal (not EOF from readabilityHandler)
process.terminationHandler = { [weak self] proc in
    Task {
        await self?.handleTermination(exitCode: proc.terminationStatus, reason: proc.terminationReason)
    }
}
```

### Pattern 4: PTY for Stdin — Preventing claude CLI Hang

**What:** The claude CLI checks whether stdin is a TTY and hangs indefinitely if it is not, even with `-p` flag (GitHub issue #9026). For GSD interactive sessions, this is the primary show-stopper. Use `Darwin.openpty()` to allocate a master/slave pair, assign the slave as the process's stdin, and hold the master open.

```swift
// Source: Apple Developer Forums thread 688534, Darwin manual pages
func setupPTY() throws -> (masterFD: Int32, slaveFD: Int32) {
    var masterFD: Int32 = -1
    var slaveFD: Int32 = -1
    guard Darwin.openpty(&masterFD, &slaveFD, nil, nil, nil) == 0 else {
        throw ProcessError.ptyCreationFailed
    }
    return (masterFD, slaveFD)
}

// Usage in process setup:
let (masterFD, slaveFD) = try setupPTY()
let slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)
process.standardInput = slaveHandle
// Keep masterFD open (ptyMasterFD) — closing it causes SIGHUP to child
// stdout/stderr use separate Pipes, not the PTY
```

**Warning:** Do NOT use `forkpty()` from Swift — fork without exec in a multithreaded Swift runtime is unsafe. Use `openpty()` instead.

### Pattern 5: Shell Environment Capture for PATH Resolution

**What:** macOS GUI apps launched via launchd inherit a minimal PATH (`/usr/bin:/bin:/usr/sbin:/sbin`) that does not include Homebrew (`/opt/homebrew/bin`), nvm (`~/.nvm/`), or the claude CLI install location. Capture the user's login shell environment by running `zsh -l -c env`.

```swift
// Source: Multiple community sources; verified behavior of macOS launchd PATH limitation
func captureLoginShellEnvironment() async throws -> [String: String] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-l", "-c", "env"]
    // Note: process.environment = nil → inherits current process env (minimal launchd PATH)
    // This is correct: we want zsh to load .zprofile/.zshrc and output the full env

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()  // Discard stderr from shell init

    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard let output = String(data: data, encoding: .utf8) else {
        throw ShellEnvironmentError.parseFailure
    }

    var env: [String: String] = [:]
    for line in output.components(separatedBy: "\n") {
        let parts = line.split(separator: "=", maxSplits: 1)
        if parts.count == 2 {
            env[String(parts[0])] = String(parts[1])
        }
    }
    return env
}

func resolveClaude(in environment: [String: String]) -> URL? {
    // 1. Search PATH from shell environment
    let pathComponents = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
    for dir in pathComponents {
        let candidate = URL(fileURLWithPath: dir).appendingPathComponent("claude")
        if FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
    }
    // 2. Fallback: common install locations
    let fallbacks = [
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude",
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin/claude",
        "\(FileManager.default.homeDirectoryForCurrentUser.path)/.nvm/versions/node/\(latestNodeVersion())/bin/claude",
    ]
    return fallbacks.compactMap { URL(fileURLWithPath: $0) }.first {
        FileManager.default.isExecutableFile(atPath: $0.path)
    }
}
```

### Pattern 6: Graceful Cancel — SIGINT then SIGKILL

**What:** `Process.interrupt()` sends SIGINT to the process and "all of its subtasks" (per Apple docs). Wait 3-5 seconds, then force-kill with `Darwin.killpg()`.

**Key finding:** `Process.terminate()` sends SIGTERM, not SIGINT. For claude CLI, SIGINT is the correct graceful signal (simulates Ctrl+C). Use `process.interrupt()`.

```swift
// Source: Apple Developer Documentation on interrupt() and terminate()
func cancel(processID: Int32) async {
    // 1. Graceful: SIGINT (simulates Ctrl+C, claude can clean up)
    process?.interrupt()

    // 2. Wait up to 4 seconds for graceful shutdown
    let deadline = Date().addingTimeInterval(4)
    while Date() < deadline {
        try? await Task.sleep(for: .milliseconds(200))
        if !(process?.isRunning ?? false) { return }  // Clean exit
    }

    // 3. Force kill: entire process group to prevent orphans
    // processIdentifier is the PID; on macOS, Foundation.Process does not automatically
    // set a new process group, so PGID == parent's PGID by default.
    // Using killpg with the child's PID as PGID only works if a new group was set.
    // Safer: kill the specific PID and any children via -PID syntax
    Darwin.kill(-processID, SIGKILL)  // Negative PID = kill process group
}
```

**Process group caveat (MEDIUM confidence):** Foundation.Process does not automatically create a new process group by default — the child inherits the parent's PGID. Using `Darwin.kill(-pid, SIGKILL)` (which kills the process group with PGID == pid) only works if a new process group was created. To ensure clean kill, the implementation must either:
- Set a new process group explicitly using `posix_spawn` attributes, OR
- Use process.terminate() followed by Darwin.kill(pid, SIGKILL) for the specific PID, OR
- Accept that child-of-child processes may survive (low risk for claude's use case since claude manages its own subprocess cleanup)

For the spike, validate whether claude spawns additional processes (node workers, etc.) that survive `process.interrupt()`.

### Anti-Patterns to Avoid
- **Using `process.waitUntilExit()` while also reading from Pipe**: Creates a deadlock when the pipe buffer fills. Always use readabilityHandler (async drain) rather than blocking reads.
- **Relying on readabilityHandler for EOF detection**: On macOS, readabilityHandler does not reliably fire with empty data on EOF. Use `terminationHandler` as the authoritative completion signal.
- **Mutating actor state directly from readabilityHandler**: In Swift 6, this is a compile error. Always dispatch via `Task { await actor.method() }`.
- **Using `forkpty()` from Swift**: Unsafe — fork in a multithreaded Swift runtime without immediate exec corrupts the process state.
- **Actors for FIFO queue**: Swift actors are not strictly FIFO. Use AsyncStream as the queue data structure.
- **Storing history in UserDefaults**: Not appropriate for potentially large, structured command history. Use a JSON file in ApplicationSupport.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| FIFO queue | Custom linked list / DispatchQueue wrapper | AsyncStream | AsyncStream is explicitly FIFO; built into Swift |
| Shell env capture | Manual parsing of .zshrc | `zsh -l -c env` subprocess | zsh handles all sourcing, nvm, brew shellenv, path_helper |
| Process completion | Poll process.isRunning | terminationHandler | terminationHandler is the authoritative signal; polling is wasteful and racy |
| ANSI stripping | Custom regex parser | Check first if claude strips automatically in non-TTY | claude may or may not emit ANSI when stdout is a pipe — spike required |

**Key insight:** The combination of PTY (stdin only) + Pipe (stdout/stderr) is the correct hybrid approach: PTY prevents the claude CLI hang, Pipes enable clean readabilityHandler streaming.

## Common Pitfalls

### Pitfall 1: Claude CLI Hangs Without TTY
**What goes wrong:** Process starts but produces no output and never exits. Activity Monitor shows it running.
**Why it happens:** Claude CLI checks `isatty(stdin)` and blocks waiting for interactive input when stdin is not a TTY.
**How to avoid:** Assign a PTY slave as `process.standardInput`. Keep PTY master open (closing it sends SIGHUP).
**Warning signs:** First test of `claude --version` with piped stdin appears to work (it does not require TTY), but interactive commands hang.

### Pitfall 2: readabilityHandler EOF Unreliability
**What goes wrong:** Output streaming stops before process exits; final output lines are missed.
**Why it happens:** `readabilityHandler` may not fire with empty data on EOF on macOS (documented in swift-corelibs-foundation issue #3275).
**How to avoid:** Do not rely on `readabilityHandler` empty-data call for completion. Use `terminationHandler` as the authoritative signal. On termination, do one final `fileHandleForReading.readDataToEndOfFile()` to flush any buffered data.
**Warning signs:** Some output lines missing from runs that complete correctly; stream appears to end early.

### Pitfall 3: Actor Non-FIFO Ordering
**What goes wrong:** Commands within a project run out of order — later-enqueued command starts before earlier one finishes.
**Why it happens:** Swift actors prioritize tasks, not FIFO order. High-priority tasks can preempt earlier-submitted ones.
**How to avoid:** Use AsyncStream as the queue. The consuming `Task` awaits each command to full completion before pulling the next item.
**Warning signs:** Under load or with task priority differences, second command starts mid-way through first.

### Pitfall 4: PATH Resolution Timing
**What goes wrong:** `zsh -l -c env` is called at app launch but the user installs claude CLI afterward; the cached PATH is stale.
**Why it happens:** Shell environment is captured once and stored.
**How to avoid:** Re-capture on each command run (or at minimum on each "claude not found" error). It's fast (< 200ms) and always current.
**Warning signs:** "claude not found" error after user has installed claude and the app shows it correctly in a new Terminal session.

### Pitfall 5: Orphaned Processes After Cancel
**What goes wrong:** After cancellation, `claude` subprocess or its node workers remain visible in Activity Monitor.
**Why it happens:** `process.interrupt()` sends SIGINT to the direct child only. If claude spawns worker processes in a new process group, they are not signaled.
**How to avoid:** After the grace period, use `Darwin.kill(-processID, SIGKILL)` targeting the process group. If Foundation.Process doesn't set a new PGID, use `process.terminate()` + `Darwin.kill(processID, SIGKILL)` for the direct child. Validate in spike whether node workers survive parent SIGINT.
**Warning signs:** `ps aux | grep claude` shows zombie processes after several cancel operations.

### Pitfall 6: PTY Master Close Causes SIGHUP
**What goes wrong:** Child process receives SIGHUP and exits unexpectedly.
**Why it happens:** The controlling terminal (PTY master) is closed before the child exits, sending SIGHUP.
**How to avoid:** Keep `ptyMasterHandle` alive for the full lifetime of the `ProcessActor` instance. Only close after `terminationHandler` fires.
**Warning signs:** Process exits with signal-based termination reason unexpectedly early.

### Pitfall 7: Swift 6 Sendable Closure Violations
**What goes wrong:** Compiler error: "Mutation of captured var in concurrently-executing code" in readabilityHandler.
**Why it happens:** readabilityHandler closure runs on a GCD thread; Swift 6 strict concurrency disallows direct access to actor state from it.
**How to avoid:** Pattern: `Task { await actor.method(data) }` inside readabilityHandler. All mutations go through actor isolation.
**Warning signs:** Build errors referencing readabilityHandler closures and Sendable conformance.

## Code Examples

### Complete ProcessActor Run Setup
```swift
// Source: Synthesized from FileWatcherService.swift codebase pattern,
// Swift Forums thread 688534 (PTY), and Apple docs (readabilityHandler + terminationHandler)
actor ProcessActor {
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String],
        workingDirectory: URL
    ) -> AsyncStream<OutputLine> {
        AsyncStream<OutputLine> { [weak self] continuation in
            guard let self else { continuation.finish(); return }

            Task {
                do {
                    // 1. Create PTY for stdin (prevents claude CLI TTY hang)
                    var masterFD: Int32 = -1, slaveFD: Int32 = -1
                    guard Darwin.openpty(&masterFD, &slaveFD, nil, nil, nil) == 0 else {
                        throw ProcessError.ptyCreationFailed
                    }
                    await self.storePTY(masterFD: masterFD)

                    // 2. Create pipes for stdout/stderr
                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()

                    // 3. Configure process
                    let process = Process()
                    process.executableURL = executableURL
                    process.arguments = arguments
                    process.environment = environment
                    process.currentDirectoryURL = workingDirectory
                    process.standardInput = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    await self.storeProcess(process)

                    // 4. Bridge readabilityHandler to AsyncStream (Swift 6 safe)
                    stdoutPipe.fileHandleForReading.readabilityHandler = { fh in
                        let data = fh.availableData
                        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                        continuation.yield(OutputLine(stream: .stdout, text: text, timestamp: Date()))
                    }
                    stderrPipe.fileHandleForReading.readabilityHandler = { fh in
                        let data = fh.availableData
                        guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                        continuation.yield(OutputLine(stream: .stderr, text: text, timestamp: Date()))
                    }

                    // 5. Authoritative completion via terminationHandler
                    process.terminationHandler = { proc in
                        // Flush any remaining data
                        let remainingStdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                        if !remainingStdout.isEmpty, let text = String(data: remainingStdout, encoding: .utf8) {
                            continuation.yield(OutputLine(stream: .stdout, text: text, timestamp: Date()))
                        }
                        // Clean up handlers
                        stdoutPipe.fileHandleForReading.readabilityHandler = nil
                        stderrPipe.fileHandleForReading.readabilityHandler = nil
                        continuation.finish()
                    }

                    try process.run()

                } catch {
                    continuation.finish()
                }
            }
        }
    }
}
```

### Shell Environment Capture
```swift
// Source: macOS launchd PATH behavior (documented community knowledge, HIGH confidence)
func captureShellEnvironment() throws -> [String: String] {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-l", "-c", "env"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    try process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    // Parse KEY=VALUE lines (value may contain '=')
    return String(data: data, encoding: .utf8)?
        .components(separatedBy: "\n")
        .compactMap { line -> (String, String)? in
            guard let eq = line.firstIndex(of: "=") else { return nil }
            let key = String(line[line.startIndex..<eq])
            let val = String(line[line.index(after: eq)...])
            return (key, val)
        }
        .reduce(into: [:]) { $0[$1.0] = $1.1 }
        ?? [:]
}
```

### Command History Persistence
```swift
// Source: Standard macOS ApplicationSupport file pattern
struct CommandHistoryStore {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("GSDMonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("command-history.json")
    }

    func load() throws -> [CommandRun] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([CommandRun].self, from: data)
    }

    func save(_ runs: [CommandRun]) throws {
        let data = try JSONEncoder().encode(runs)
        try data.write(to: fileURL, options: .atomic)
    }
}
```

### Cancel with SIGINT + SIGKILL
```swift
// Source: Apple docs on interrupt() and terminate(); Darwin kill() manual
func cancel() async {
    guard let process, process.isRunning else { return }
    let pid = process.processIdentifier

    // Step 1: Graceful — SIGINT (Ctrl+C equivalent)
    process.interrupt()

    // Step 2: Wait up to 4 seconds
    let timeout: TimeInterval = 4.0
    let start = Date()
    while process.isRunning && Date().timeIntervalSince(start) < timeout {
        try? await Task.sleep(for: .milliseconds(100))
    }

    // Step 3: Force kill if still running
    if process.isRunning {
        Darwin.kill(pid, SIGKILL)          // Kill direct child
        Darwin.kill(-pid, SIGKILL)         // Attempt process group kill (may be no-op if PGID != pid)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| OperationQueue for serialized work | AsyncStream as FIFO queue | Swift 5.5+ concurrency | AsyncStream is the correct primitive; OperationQueue is unnecessary with async/await |
| NSTask | Foundation.Process | Long ago (NS prefix dropped) | Same API, new name |
| forkpty() | openpty() + posix_spawn | Always (forkpty unsafe in multithreaded) | forkpty was never safe from Swift; openpty is the correct approach |
| swiftlang/swift-subprocess | Foundation.Process | Swift 6.1+ only | swift-subprocess unavailable at Swift 6.0 |
| Poll process.isRunning | terminationHandler | Foundation always had this | terminationHandler is correct; polling wastes CPU and introduces race conditions |

**Deprecated/outdated:**
- `process.launch()`: Deprecated; use `process.run()` which throws on failure instead of crashing.
- `pipe.fileHandleForReading.readDataToEndOfFile()` during run: Blocks and can deadlock; use readabilityHandler instead.
- `NSPipe`: Old name for `Pipe`; same API, avoid the NS prefix.

## Claude's Discretion Recommendations

### Graceful Shutdown Timeout Duration
**Recommendation: 4 seconds.**
- claude CLI agents can run multi-step operations; 3s may cut off legitimate cleanup
- 5s feels slow to users in the UI (Phase 14 shows cancel feedback)
- 4s balances cleanup time with UX responsiveness

### History Retention Policy
**Recommendation: Count-based, last 200 runs per project, hard limit.**
- Time-based (e.g., 30 days) requires background cleanup and date math
- Count-based is simpler: on save, trim array to last 200 entries
- 200 runs is ample for re-run workflows; JSON file stays < 5 MB assuming typical output stored separately or truncated

### Persistence Storage Format and Location
**Recommendation: JSON file at `~/Library/Application Support/GSDMonitor/command-history.json`**
- Matches existing `bookmarkService` pattern (already uses ApplicationSupport implicitly via `NSPersistentContainer` or similar)
- Codable + JSONEncoder is already used throughout the project (all models are Codable)
- Atomic write (`Data.write(options: .atomic)`) prevents corruption on crash
- One file per project risks many small files; one global file is simpler for Phase 13
- Store full output as `[String]` array of lines within CommandRun; truncate to last 5000 lines if output is very large

### GSD Output Parsing Patterns
**Recommendation: Lightweight line-by-line regex patterns for initial implementation.**

GSD command output is natural language with structured markdown banners. The following patterns are commonly emitted:

```swift
// Source: Observed GSD workflow output patterns (LOW confidence — verify during implementation)
struct GSDOutputParser {
    // Phase progress: "## Phase X" or "Phase X:" headers
    static let phasePattern = /##?\s+Phase\s+(\d+)/
    // Plan execution: "## Plan X" or "Executing plan X"
    static let planPattern = /[Pp]lan\s+(\d+)/
    // Task completion markers from gsd-executor
    static let taskCompletePattern = /✅|DONE|completed?/
    // GSD tool output (from gsd-tools.cjs)
    static let gsdToolPattern = /\[GSD\]|\bgsd-tools\b/
    // Error/failure markers
    static let errorPattern = /ERROR:|FAILED:|❌/
}
```

**Caveat:** GSD output is LLM-generated natural language. Patterns will need iteration. Treat parsed metadata as best-effort, not authoritative.

### Exact Recovery Suggestion Content
**Recommendation:** Per exit code category:
- Exit 1 (general failure): "Command exited with error. Check output for details. [Re-run] [View Logs]"
- Exit 130 (SIGINT): "Command was interrupted. [Re-run] [View Logs]"
- Exit code > 1 (crash-like): "Process crashed unexpectedly. [Re-run] [Check Logs]"
- claude not found: "claude CLI not found. Install via: npm install -g @anthropic-ai/claude-code. Then restart GSD Monitor."

## Open Questions

1. **Does claude CLI hang in non-TTY context for ALL GSD commands or only interactive mode?**
   - What we know: GitHub issue #9026 confirms hang with `claude -p` in non-TTY. GSD commands use interactive mode (no `-p`).
   - What's unclear: Does `claude --dangerously-skip-permissions /gsd:quick "..."` also hang? Does PTY for stdin fully resolve the issue?
   - **Recommendation:** Run spike: `claude --version` with plain Pipe stdin to confirm it works (claude --version doesn't need TTY); then test a GSD command with PTY stdin to confirm it runs. This is the first task in any plan.

2. **Does claude CLI strip ANSI escape codes when stdout is a Pipe (non-TTY)?**
   - What we know: Issue #18728 was resolved as "ANSI works in claude slash commands" — but that was stdout going to a terminal. When stdout is a Pipe (as in our case), the child process sees `isatty(stdout) == false`.
   - What's unclear: Whether claude explicitly forces ANSI off when stdout is a pipe, or always emits it.
   - **Recommendation:** Test `claude --version` with piped stdout and check for ANSI sequences. If stripped automatically, no parser needed. If not stripped, Phase 14 will need to strip them from stored output (but can render them in the UI).

3. **Does Foundation.Process create a new process group by default on macOS 14?**
   - What we know: POSIX default is child inherits parent PGID unless `POSIX_SPAWN_SETPGROUP` is set. Foundation.Process uses posix_spawn internally.
   - What's unclear: Whether Foundation.Process sets `POSIX_SPAWN_SETPGROUP` internally on macOS.
   - **Recommendation:** In spike, after spawning, run `ps -o pid,pgid -p <pid>` to check if PGID == PID (new group) or PGID == parent PID (inherited). This determines whether `kill(-pid, SIGKILL)` is effective.

4. **What node worker processes does claude spawn, and do they survive SIGINT to the parent?**
   - What we know: claude CLI is a Node.js application that may spawn worker threads or subprocesses for API calls, MCP servers, etc.
   - What's unclear: Whether node workers are in the same process group and respond to SIGINT.
   - **Recommendation:** After a running command, check `ps aux | grep claude` to count processes. After SIGINT, check again to confirm cleanup.

5. **History file contention between multiple projects running simultaneously**
   - What we know: Per-project parallelism is a design requirement; multiple projects can run at the same time.
   - What's unclear: If history writes happen simultaneously from two CommandRunnerService actions, file corruption is possible.
   - **Recommendation:** Serialize all history writes through an actor. Single history file with actor-protected access prevents any contention.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — `Foundation.Process`, `interrupt()`, `terminate()`, `terminationHandler`, `readabilityHandler`, `processIdentifier` (https://developer.apple.com/documentation/foundation/process)
- Project codebase — `FileWatcherService.swift`: existing AsyncStream + callback bridge pattern; `GSDMonitorApp.swift`: Swift 6.0 confirmed; `GSDMonitor.xcodeproj`: macOS 14.0 deployment target confirmed
- Claude CLI reference docs — https://code.claude.com/docs/en/cli-reference: confirmed `-p` mode, `--dangerously-skip-permissions` flag semantics

### Secondary (MEDIUM confidence)
- GitHub issue #9026 (anthropics/claude-code) — Claude CLI hangs without TTY: https://github.com/anthropics/claude-code/issues/9026
- Swift Forums — Swift 6 Concurrency + NSPipe Readability Handlers: https://forums.swift.org/t/swift-6-concurrency-nspipe-readability-handlers/59834
- Swift Forums — AsyncStream for deterministic task ordering: https://forums.swift.org/t/how-do-you-use-asyncstream-to-make-task-execution-deterministic/57968
- Apple Developer Forums — Swift Process with PTY: https://developer.apple.com/forums/thread/688534
- swift-corelibs-foundation issue #3275 — readabilityHandler EOF unreliability: https://github.com/swiftlang/swift-corelibs-foundation/issues/3275
- swiftlang/swift-subprocess — requires Swift 6.1; confirms posix_spawn process group options: https://github.com/swiftlang/swift-subprocess

### Tertiary (LOW confidence)
- GSD output patterns — inferred from GSD workflow file structure and community examples; needs verification during implementation
- Process group inheritance behavior of Foundation.Process on macOS — requires spike to confirm; POSIX default documented but Foundation.Process internals are not
- Node worker subprocess behavior from claude CLI — requires runtime observation

## Metadata

**Confidence breakdown:**
- Standard stack (Foundation.Process, Darwin): HIGH — built-in APIs, version confirmed
- PTY requirement for claude CLI: MEDIUM-HIGH — GitHub issue confirms hang; PTY solution is standard workaround but needs spike
- AsyncStream FIFO queue pattern: HIGH — Swift community consensus, multiple forum sources agree
- readabilityHandler EOF unreliability: HIGH — documented bug in swift-corelibs-foundation
- GSD output parsing patterns: LOW — LLM output, no stable schema
- Process group kill effectiveness: MEDIUM — POSIX behavior documented; Foundation.Process internals unclear

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (stable macOS/Swift APIs; claude CLI behavior may change with updates)
