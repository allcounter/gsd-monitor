# Pitfalls Research

**Domain:** Embedded GSD Command Runner — SwiftUI macOS app with Process/PTY spawning, ANSI output streaming, long-running CLI commands
**Researched:** 2026-02-17
**Confidence:** HIGH (process/pipe/concurrency pitfalls), MEDIUM (FSEvents integration, UI rendering at scale)

## Critical Pitfalls

### Pitfall 1: Pipe Buffer Deadlock (The Silent Freeze)

**What goes wrong:**
Using `Pipe` with `readDataToEndOfFile()` or `waitUntilExit()` before draining the pipe deadlocks the app silently. The child process (gsd/claude CLI) fills the 64 KiB OS pipe buffer, then blocks waiting for the buffer to drain. Your app is waiting for the process to exit. Neither side makes progress. The UI freezes with no error, no crash, no log. For a 10+ minute CLI command that produces substantial output, this is nearly certain to occur.

**Why it happens:**
Unix pipes have a hard 64 KiB kernel buffer. Any naive "wait for process, then read output" approach exhausts this buffer immediately for verbose tools. Developers copy-paste examples using `waitUntilExit()` + `standardOutput.fileHandleForReading.readDataToEndOfFile()` because that's what appears in most tutorials—it works in tests but explodes on real output.

**How to avoid:**
Never block on process exit before draining output. Use `readabilityHandler` exclusively:

```swift
let pipe = Pipe()
process.standardOutput = pipe
pipe.fileHandleForReading.readabilityHandler = { handle in
    let data = handle.availableData
    guard !data.isEmpty else {
        handle.readabilityHandler = nil
        return
    }
    // Send data to async stream / accumulate buffer
}
try process.run()
// Process termination is handled via terminationHandler, NOT waitUntilExit()
```

Set `readabilityHandler` on both stdout AND stderr pipes before calling `process.run()`. Never use `waitUntilExit()` on the main thread or any Swift actor thread.

**Warning signs:**
- App hangs with no error for commands that produce >50 KB of output
- Xcode shows thread blocked in `waitUntilExit` or `read(2)` syscall
- Works fine for short commands, breaks for long GSD research phases
- Process shows as running in Activity Monitor but app is unresponsive

**Phase to address:**
Process Foundation Phase — Implement and verify before any UI work. Add a stress test that generates 1 MB of output to catch this before ship.

---

### Pitfall 2: Swift 6 Sendable Violations in readabilityHandler Closures

**What goes wrong:**
Swift 6 strict concurrency flags `readabilityHandler` closures as Sendable. Any mutation of captured actor-isolated state inside the handler produces a compile error: "Actor-isolated property X can not be mutated from a Sendable closure." Wrapping in `Task { }` inside the handler looks like it fixes it, but creates a new problem: you're spawning one Task per data chunk (potentially hundreds per second), each hopping to the actor, creating an actor queue backlog that manifests as lagged UI.

**Why it happens:**
`FileHandle.readabilityHandler` is typed as `(@Sendable (FileHandle) -> Void)?` in Swift 6. This closure can be called from any thread (GCD dispatch queue inside Foundation). It cannot directly mutate actor-isolated state. The instinct to wrap every mutation in `Task { await mainActor.doThing() }` is correct in principle but wrong in granularity—it creates per-chunk overhead.

**How to avoid:**
Bridge readabilityHandler to an AsyncStream continuation, then consume the stream on the actor. This separates the "collect data" concern (happens on Foundation's queue, no actor needed) from the "update model" concern (happens on actor, batched):

```swift
// In a nonisolated context — no actor involvement in data collection
let (stream, continuation) = AsyncStream<Data>.makeStream()
pipe.fileHandleForReading.readabilityHandler = { handle in
    let data = handle.availableData
    if data.isEmpty {
        continuation.finish()
        handle.readabilityHandler = nil
    } else {
        continuation.yield(data)  // Sendable: Data is Sendable
    }
}
// On the actor: consume the stream
Task { @MainActor in
    for await chunk in stream {
        self.processOutput(chunk)  // Single actor hop per batch
    }
}
```

`Data` is `Sendable`, so `continuation.yield(data)` is legal from the Sendable closure. The actor only hops once per AsyncStream element, not once per byte.

**Warning signs:**
- Swift 6 compiler errors about actor-isolated mutations in Sendable closures
- Excessive Task creation (Instruments shows thousands of short-lived Tasks)
- UI updates lag even though data is arriving fast
- `@unchecked Sendable` appearing in the codebase as a "fix"

**Phase to address:**
Process Foundation Phase — Design the data collection architecture before any concurrency issues accumulate.

---

### Pitfall 3: Process Not Receiving SIGTERM on Task Cancellation

**What goes wrong:**
Cancelling the Swift `Task` managing a process does NOT terminate the child process. The `Process` object continues running, consuming CPU and spawning its own child processes (claude CLI spawns sub-agents). The cancelled Task stops consuming output, but the process keeps running. After 10 minutes it either completes or zombie-lingers.

**Why it happens:**
Swift task cancellation is cooperative—it sets a flag, it does not send OS signals. `Process` is an OS-level concept with no connection to Swift's cancellation system. Developers assume `.cancel()` on a Task is sufficient. It isn't. The child keeps running until it exits naturally or the parent app terminates.

**How to avoid:**
Wire `process.terminate()` to Task cancellation explicitly using `withTaskCancellationHandler`:

```swift
try await withTaskCancellationHandler {
    // The actual work: await process completion
    await withCheckedContinuation { continuation in
        process.terminationHandler = { _ in
            continuation.resume()
        }
    }
} onCancel: {
    process.terminate()  // Sends SIGTERM to child process
    // If process doesn't respond within ~2s, escalate to SIGKILL
    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
        if process.isRunning { process.interrupt() }
    }
}
```

Note: `process.terminate()` sends SIGTERM. Claude CLI may spawn subprocesses; those inherit the parent's process group. Use `killpg()` via `kill(-processGroupID, SIGTERM)` if you need to kill the whole process tree.

**Warning signs:**
- Activity Monitor shows `claude` processes accumulating after user cancels
- CPU usage remains high after cancellation in the app
- Multiple `claude` processes running when only one command was issued
- Process count grows over multiple cancelled runs

**Phase to address:**
Process Foundation Phase — Verify cancellation kills the process before implementing any UI. Manual test: start a 5-minute command, cancel it, verify no orphaned processes in Activity Monitor.

---

### Pitfall 4: ANSI Escape Code Parsing with Split Sequences

**What goes wrong:**
ANSI escape sequences can be split across `readabilityHandler` chunks. If you process each chunk independently with a regex or simple string search, you'll display raw escape code fragments as visible text (`\x1b[31m` appearing literally) or miss the start of a sequence and render garbage for the rest of the output. Claude CLI uses ANSI colors heavily.

**Why it happens:**
The pipe delivers data in arbitrary chunk sizes determined by the OS. A 4-byte escape sequence like `\x1b[0m` can arrive as `\x1b[` in one chunk and `0m` in the next. Any stateless parser that processes each chunk independently will fail on boundary splits. Simple regex on `Data` chunks misses this.

**How to avoid:**
Maintain a carry-over buffer across chunks. Implement a state-machine ANSI parser (not regex) that handles partial sequences:

```swift
actor ANSIParser {
    private var buffer = Data()

    func process(_ chunk: Data) -> [OutputSegment] {
        buffer.append(chunk)
        var segments: [OutputSegment] = []
        // Parse complete sequences from buffer
        // Leave incomplete escape sequence prefix in buffer for next chunk
        // State: normal / in-escape / in-CSI / etc.
        return segments
    }
}
```

Key sequences to handle: SGR (colors `\x1b[Xm`), cursor movement, clear line, carriage return `\r` for progress bars, and OSC sequences. For GSD/claude output, focus on SGR color codes and `\r` for progress overwrites.

Do NOT use regex for this — use a proper state machine. The VT100 state machine specification at vt100.net is authoritative.

**Warning signs:**
- Raw `\x1b[` characters visible in output UI
- Colors cut off mid-segment or bleed into subsequent text
- Output looks garbled for first line after a color change
- Works in testing but breaks with real claude output

**Phase to address:**
ANSI Rendering Phase — Build and unit-test the parser with a corpus of real GSD/claude output before integrating with UI.

---

### Pitfall 5: FSEvents Watcher Triggering on GSD Command Output Files

**What goes wrong:**
GSD commands write files to `.planning/` (ROADMAP.md, STATE.md, phase files). The existing `FileWatcherService` monitors `.planning/` and triggers `ProjectService.reloadProject()` on every change. A running GSD command creates a feedback loop: command writes file → FSEvents fires → parser re-reads files → UI updates → command continues writing → FSEvents fires again. During a 10+ minute research phase, this triggers hundreds of unnecessary reloads, degrading performance.

**Why it happens:**
The `ProjectService` already has a 1-second debounce, which helps, but GSD commands can write files continuously (research notes, interim STATE.md updates). The watcher and the command runner share the same watched paths with no coordination about which changes come from "user edits" vs. "command output."

**How to avoid:**
Suppress file watcher reloads while a command is actively running for that project. Options:

1. **Pause watcher during command run:** Set a flag in `ProjectService` (`isCommandRunning: Set<ProjectID>`). In the FSEvents handler, skip reload if that project has a running command. Resume after command completes.
2. **Extend debounce during commands:** Increase debounce from 1s to 10s while any command is running.
3. **Post-run reload:** Do a single forced reload when the command completes rather than relying on FSEvents during execution.

Option 1 is cleanest. The command runner signals `ProjectService` on start and on completion.

**Warning signs:**
- Instruments shows `parseProject()` called continuously during command execution
- UI "flickers" showing intermediate state while command runs
- High CPU from file parsing during 10-minute commands
- FSEvents callback firing 5+ times per second during GSD research commands

**Phase to address:**
Integration Phase — Design the ProjectService ↔ CommandRunner coordination protocol before wiring them together. This is the highest-risk integration pitfall.

---

### Pitfall 6: PATH Environment Not Inherited from User Shell

**What goes wrong:**
`Process` launched from a macOS GUI app inherits the app's environment, which is the launchd agent environment—not the user's login shell environment. This means `node`, `claude` (if installed via nvm or homebrew), and `gsd` (if in `~/.local/bin` or a nvm-managed path) are not on PATH. The command fails with "command not found" or picks up a system version instead of the user's configured version.

**Why it happens:**
macOS apps launched from the Dock or Finder run with a minimal environment. The user's `.zshrc`, `.zprofile`, `.bashrc`, etc. are never sourced. `PATH` is something like `/usr/bin:/bin:/usr/sbin:/sbin`. The `claude` CLI and GSD scripts are typically installed in paths like `/opt/homebrew/bin`, `~/.nvm/versions/node/v20.x/bin`, or `~/.bun/bin` — none of which are in the launchd PATH.

**How to avoid:**
Source the user's shell environment before building the process environment:

```swift
// Get the user's full login shell environment
func loginEnvironment() async -> [String: String] {
    let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: shell)
    process.arguments = ["-l", "-c", "env"]  // -l = login shell
    // ... capture output and parse KEY=VALUE pairs
}
```

Cache this at app startup. Use the captured environment as the base for all spawned processes, merging with any overrides (e.g., `TERM=xterm-256color` for ANSI support).

Alternative: Let the user configure the PATH override in Settings if automatic detection fails.

**Warning signs:**
- `claude` command fails with "command not found" on first run
- Works when launched from Terminal but not from Dock
- Different behavior depending on how app is launched
- `echo $PATH` in spawned process shows minimal path

**Phase to address:**
Process Foundation Phase — Implement and test environment capture before any command execution. Test with nvm-managed node, homebrew-installed tools, and custom PATH entries.

---

### Pitfall 7: Unbounded Output Buffer Causing Memory Growth

**What goes wrong:**
Storing the complete raw output of a 10+ minute GSD command in memory as a string or Data object causes unbounded memory growth. Claude research commands can produce megabytes of output. If the app accumulates the full output of multiple simultaneous commands (user can trigger several), memory pressure triggers, SwiftUI re-renders the text view on every append (even more expensive), and eventually the app gets jetsam-killed on a resource-constrained system.

**Why it happens:**
The natural implementation is `var output = ""` with `output += newChunk`. String concatenation in Swift is O(n) due to copy-on-write semantics when there are multiple references. Storing the full history for display purposes feels intuitive. It doesn't scale to 100K+ lines of output.

**How to avoid:**
- Cap the in-memory output buffer at a fixed line count (e.g., 2000 lines). Discard oldest lines when cap is exceeded.
- Store the full output to a temp file and tail-display from it.
- Use NSTextView's `textStorage.append()` directly instead of binding a String to SwiftUI Text/TextEditor—NSTextView handles large attributed strings better.
- Parse and discard intermediate ANSI output during processing; only retain final state changes (e.g., files written).

For GSD Monitor: the primary value is knowing what GSD _did_ (files changed, phase completed), not the full terminal transcript. Keep only the last N lines for display; rely on FSEvents for the real state changes.

**Warning signs:**
- Memory usage grows monotonically during command execution
- App becomes slow to respond during output-heavy commands
- Xcode Memory Report shows large allocations in String or Data categories
- SwiftUI performance degrades as output string grows

**Phase to address:**
ANSI Rendering Phase — Design the output buffer strategy before implementing UI. 2000-line rolling buffer is the safe default.

---

### Pitfall 8: Multiple Simultaneous Commands Without Coordination

**What goes wrong:**
User triggers GSD command on Project A, then on Project B before A completes. Both commands write to their respective `.planning/` directories. FSEvents fires for both. ProjectService reloads both projects. But if both commands also share a global resource (e.g., a claude API rate limit, a shared npm cache being modified), they interfere. Worse: if the user triggers two commands on the same project, state writes conflict and files are corrupted.

**Why it happens:**
The command runner is implemented as "fire and forget" without thinking about per-project concurrency constraints. Multiple `Process` objects run simultaneously with no coordination. There's no concept of "project is busy."

**How to avoid:**
- Maintain a per-project command queue (one active command per project at a time).
- Track `runningCommands: [ProjectID: CommandRunner]` in `ProjectService`.
- Queue additional commands rather than rejecting them (user expects them to run eventually).
- Show per-project "running" indicator in the sidebar.
- For global resource limits (claude API): use a semaphore or actor to limit concurrent API-hitting processes (max 1-2 simultaneously).

**Warning signs:**
- STATE.md files contain garbled content after running two commands on same project
- User triggers same command twice because UI didn't show it was running
- `claude` rate limit errors appear when running commands on multiple projects

**Phase to address:**
Process Foundation Phase — Design command state tracking before implementing UI affordances. The `ProjectService` needs `runningCommands` state from day one.

---

### Pitfall 9: readabilityHandler Not Called on Termination (EOF Handling)

**What goes wrong:**
`readabilityHandler` is NOT reliably called with empty data at EOF on macOS in all cases. When the process exits, the file descriptor closes, but the handler may not fire, or may fire with 0 bytes once, or may not fire at all. Relying solely on the handler's empty-data check to detect process completion means the command "completes" but the app doesn't know it's done.

**Why it happens:**
This is a Foundation quirk on macOS. The reliable way to detect process completion is `process.terminationHandler`, not inferring it from pipe EOF. Many code examples conflate these, leading to commands that show "running" indefinitely after they've finished.

**How to avoid:**
Use BOTH mechanisms:

```swift
// Pipe EOF: may or may not fire reliably
pipe.fileHandleForReading.readabilityHandler = { handle in
    let data = handle.availableData
    if data.isEmpty {
        handle.readabilityHandler = nil
        // Don't complete here — wait for terminationHandler
    } else {
        // Process data
    }
}

// Process exit: always fires reliably
process.terminationHandler = { process in
    // Always fires when process exits
    let exitCode = process.terminationStatus
    // Now close stream, update state
}
```

Track both signals. Mark completion only when `terminationHandler` fires, regardless of whether `readabilityHandler` saw EOF.

**Warning signs:**
- Commands show "running" in UI after they've clearly finished (Activity Monitor shows them as gone)
- Cancellation leaves "still running" indicator stuck
- Output stops appearing but spinner never stops

**Phase to address:**
Process Foundation Phase — Write an integration test that verifies completion state after a short `echo hello` process.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| `readDataToEndOfFile()` instead of readabilityHandler | Simple, one-liner | Deadlocks on >64 KiB output — certain for GSD commands | Never |
| `waitUntilExit()` on actor thread | Synchronous, easier to reason about | Blocks the actor for 10+ minutes, app freezes | Never |
| `@unchecked Sendable` to silence concurrency warnings | Eliminates compiler errors | Removes safety guarantees, real data races possible | Only as temporary bridge with manual lock documentation |
| String accumulation for full output | Easy to display | Memory unbounded growth, O(n) append | Never for long-running processes; use rolling buffer |
| Same Process environment as app | Zero configuration | `claude`, `node`, `gsd` not found — commands always fail | Never; capture login shell env at startup |
| `process.terminate()` only (no process group kill) | Simple | Claude sub-agents keep running after termination | Acceptable for commands that don't spawn subprocesses; use `killpg` for claude |
| Skip FSEvents suppression during commands | No extra coordination code | Hundreds of unnecessary reloads, CPU waste, UI flicker | Only acceptable for milestone 1 if debounce is 10s+ |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| FSEvents + Command Runner | Watcher fires on every file write from command | Pause watcher reload (not the watcher itself) while command runs for that project |
| ProjectService + CommandRunner | CommandRunner as standalone service with no ProjectService awareness | CommandRunner notifies ProjectService of running/completed state |
| Swift Task + Process | Assuming Task cancel kills the process | Wire `withTaskCancellationHandler` to `process.terminate()` explicitly |
| FileHandle + Swift 6 | Mutating actor state directly in readabilityHandler | Bridge via AsyncStream continuation (Data is Sendable) |
| Process + PATH | Using `ProcessInfo.processInfo.environment` directly | Source login shell env (`zsh -l -c env`) at startup and cache |
| Multiple commands | No per-project serialization | `runningCommands: [ProjectID: CommandRunner]` in ProjectService |
| ANSI parser + chunked data | Stateless regex per chunk | Stateful buffer that carries partial escape sequences across chunks |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| readabilityHandler spawning one Task per chunk | Actor queue backlog, lagged UI | Bridge to AsyncStream, batch updates on actor | When output rate exceeds 1 chunk/ms |
| Full output string growing unbounded | Memory pressure, slow NSTextView redraws | Rolling 2000-line buffer; write full output to temp file | Commands producing >5 MB output |
| FSEvents reload during command execution | Continuous `parseProject()` calls, CPU waste | Suppress reload (not watcher) while command is active | Any command that writes files continuously |
| Per-chunk actor hop via Task { await } | Main thread congestion, dropped frames | Use AsyncStream to batch; only hop actor on meaningful state changes | Output rate >10 chunks/second |
| NSAttributedString rebuilt on every append | Text view blinks, slow for large output | Use `textStorage.append()` directly on NSTextView | Output exceeding ~500 KB displayed at once |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Passing unsanitized project path as shell argument | Path with spaces or special chars causes argument injection | Always pass paths as explicit Process `arguments` array elements, never via shell interpolation |
| Inheriting app environment without vetting | Sensitive env vars (API keys) passed to child process | Build explicit environment dict; only pass known-safe keys |
| No output size limit | Malicious or runaway command fills disk with output temp file | Cap temp file at 100 MB; abort command if exceeded |
| SIGPIPE not handled | App crashes if child process exits while we're writing to stdin | Set `Signal.SIG_IGN` for SIGPIPE at startup, or check `isRunning` before writing |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No progress indication for 10+ min commands | User thinks app is frozen, triggers command again | Show elapsed time counter + last N lines of output in UI |
| Cancel button that doesn't work | User kills the whole app to stop a command | Verify `process.terminate()` + process group kill works before shipping cancel UI |
| Output disappears when command finishes | User can't review what GSD did | Persist last command's output summary in ProjectService; show in sidebar |
| No distinction between stdout and stderr | Errors look like normal output | Color-code stderr differently (red/yellow) from stdout |
| Commands silently failing due to PATH issues | User sees "command not found" with no context | Show shell setup validation on first launch; guide user to fix PATH |

## "Looks Done But Isn't" Checklist

- [ ] **Pipe deadlock:** Command produces 100 KB+ of output without hanging — verify with `yes | head -c 200000 | cat` as a stress process
- [ ] **Task cancellation:** Cancel during active command — verify no orphaned processes in Activity Monitor after 5 seconds
- [ ] **ANSI rendering:** Real claude output renders with colors — not raw `\x1b[` literals visible in UI
- [ ] **ANSI split sequences:** Parser handles escape code split across chunk boundary — unit test with manually split sequences
- [ ] **Process completion:** UI shows "done" when process actually exits — verify with short `sleep 1` command
- [ ] **FSEvents suppression:** File watcher doesn't trigger continuous reloads during command — verify Instruments shows parseProject() calm during execution
- [ ] **PATH resolution:** `claude` found without user configuring anything — verify on fresh macOS user account without .zshrc sourced
- [ ] **Memory:** 15-minute command leaves memory usage stable — verify no unbounded growth in Xcode Memory Report
- [ ] **Multiple commands:** Two simultaneous commands on different projects both complete correctly — verify no state corruption
- [ ] **Same-project guard:** Triggering two commands on same project queues correctly — second starts only when first completes

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Pipe deadlock discovered post-ship | HIGH | Rewrite output collection to use readabilityHandler; all tests must be re-run |
| Swift 6 concurrency violations spread through codebase | HIGH | Refactor all Process handling through a single actor-isolated CommandRunner service; one place to fix |
| FSEvents feedback loop degrading performance | MEDIUM | Add `isCommandRunning` flag to ProjectService; suppress reload in FSEvents handler |
| Orphaned processes accumulating | MEDIUM | Add `atexit` handler to terminate all tracked processes; add process group kill to cancellation |
| PATH issues blocking CLI tools | LOW | Add Settings "Shell Path Override" text field; document known PATH locations in setup guide |
| Memory growth crashing app | MEDIUM | Switch output storage from String to rolling circular buffer; no API change needed if CommandRunner is properly encapsulated |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Pipe buffer deadlock | Phase 1: Process Foundation | Stress test with 200 KB output process; no hang |
| Swift 6 Sendable violations | Phase 1: Process Foundation | Zero `@unchecked Sendable` in CommandRunner code; clean Swift 6 build |
| Task cancellation doesn't kill process | Phase 1: Process Foundation | Cancel during 5-min command; verify 0 orphaned processes |
| readabilityHandler EOF handling | Phase 1: Process Foundation | `sleep 1` command shows "done" within 2s of process exit |
| PATH not inherited from login shell | Phase 1: Process Foundation | `claude --version` succeeds from GUI app on fresh account |
| ANSI split sequences | Phase 2: ANSI Rendering | Unit tests with split sequences; corpus of real claude output renders correctly |
| Unbounded output buffer | Phase 2: ANSI Rendering | 15-min command's memory footprint <50 MB incremental |
| FSEvents feedback loop | Phase 3: Integration | Instruments shows <2 parseProject() calls during 10-min command execution |
| Multiple simultaneous commands | Phase 3: Integration | Two commands on different projects complete without state corruption |
| Same-project command queueing | Phase 3: Integration | Second command queues, shows in UI, starts after first completes |

## Sources

**Pipe Deadlock and Process Management:**
- [Working with Process Pipe and Its 64KiB Limit — Christian Tietze (2025)](https://christiantietze.de/posts/2025/03/process-pipe-64kib-limit/)
- [Running a Child Process with Standard IO — Apple Developer Forums](https://developer.apple.com/forums/thread/690310)
- [Deadlocking Linux subprocesses using pipes — tey.sh](https://tey.sh/TIL/002_subprocess_pipe_deadlocks)
- [Process() run() and waitForExit() — Apple Developer Forums](https://developer.apple.com/forums/thread/738911)

**Swift 6 Concurrency with Process/FileHandle:**
- [Swift 6 Concurrency + NSPipe Readability Handlers — Swift Forums](https://forums.swift.org/t/swift-6-concurrency-nspipe-readability-handlers/59834)
- [Adopting strict concurrency in Swift 6 apps — Apple Developer Documentation](https://developer.apple.com/documentation/swift/adoptingswift6)
- [Beware @unchecked Sendable — Jared Sinclair (2024)](https://jaredsinclair.com/2024/11/12/beware-unchecked.html)
- [Swift concurrency hack for passing non-sendable closures — Jesse Squires (2024)](https://www.jessesquires.com/blog/2024/06/05/swift-concurrency-non-sendable-closures/)

**Task Cancellation and Process Lifecycle:**
- [Task Cancellation in Swift Concurrency — Swift with Majid (2025)](https://swiftwithmajid.com/2025/02/11/task-cancellation-in-swift-concurrency/)
- [Understanding Task cancellation — Swift Forums](https://forums.swift.org/t/understanding-task-cancellation/75329)

**ANSI Parsing:**
- [A parser for DEC's ANSI-compatible video terminals (state machine spec) — VT100.net](https://vt100.net/emu/dec_ansi_parser)
- [ANSI escape code — Wikipedia](https://en.wikipedia.org/wiki/ANSI_escape_code)

**Environment / PATH:**
- [Node installed via nvm is not available in tools not run from terminal — nvm GitHub Issue #2025](https://github.com/nvm-sh/nvm/issues/2025)
- [Process currentDirectoryURL strange behaviour — Swift Forums](https://forums.swift.org/t/process-currentdirectoryurl-strange-behaviour/36968)

**Actor Hopping Performance:**
- [What is actor hopping and how can it cause problems? — Hacking with Swift](https://www.hackingwithswift.com/quick-start/concurrency/what-is-actor-hopping-and-how-can-it-cause-problems)
- [Common Swift-Concurrency mistakes that can kill app performance — Medium (2024)](https://medium.com/@lucasmrowskovskypaim/common-swift-concurrency-mistakes-that-can-be-killing-your-app-performance-b180a7ede4df)

**UI Performance with Large Output:**
- [SwiftUI TextEditor performance issues — Apple Developer Forums](https://developer.apple.com/forums/thread/672909)
- [NSTextView — Apple Developer Documentation](https://developer.apple.com/documentation/appkit/nstextview)

**SIGPIPE Handling:**
- [Debugging Broken Pipes — Apple Developer Forums](https://developer.apple.com/forums/thread/773307)
- [Effective handling of the SIGPIPE informational signal — pixelbeat.org](http://www.pixelbeat.org/programming/sigpipe_handling.html)

---
*Pitfalls research for: GSD Monitor v1.2 — Embedded Command Runner*
*Researched: 2026-02-17*
