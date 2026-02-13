# Architecture Research

**Domain:** SwiftUI macOS App — Embedded GSD Command Runner (v1.2)
**Researched:** 2026-02-17
**Confidence:** HIGH (existing arch) / MEDIUM (Process/concurrency integration patterns)

---

## Context: What Already Exists

This is a subsequent-milestone research document. GSD Monitor v1.1 is a complete, working app.
The question is specifically: **how does a command runner layer graft onto what's there?**

### Existing Architecture (v1.1)

```
GSDMonitorApp
    └── ContentView (@State ProjectService, @State NotificationService)
        ├── NavigationSplitView
        │   ├── SidebarView(projectService) --> shows grouped projects
        │   └── DetailView(selectedProject) --> phases, stats, timeline
        │       ├── StatsGridView
        │       ├── MilestoneTimelineView
        │       └── PhaseCardView(phase, project) [tap → sheet]
        │           └── → PhaseDetailView(phase, project) [sheet]
        │               └── PlanCard(plan)
        └── CommandPaletteView [sheet, Cmd+K]
            └── searches projects/phases/requirements by text
```

**Service layer pattern:** `@MainActor @Observable final class XxxService`
- All services isolated to MainActor
- Services own async Tasks using `_Concurrency.Task {}`
- AsyncStream for event delivery (FileWatcherService pattern)
- No singleton — services passed as parameters or stored as `@State` in root

**Key constraints from existing code:**
- Swift 6 strict concurrency throughout
- `nonisolated(unsafe)` used for C callback pointers (see FileWatcherService)
- Models are `Sendable` (all value types + `struct`)
- Services are `@MainActor` class instances — NOT passed across actor boundaries

---

## New System: Command Runner Layer

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                          View Layer (existing + new)                  │
│                                                                        │
│  CommandPaletteView     PhaseDetailView    CommandOutputView           │
│  (extended: +GSD cmds)  (+ context btns)  (NEW: output panel)        │
│       │                      │                    │                   │
│       └──────────────────────┴────────────────────┘                   │
│                              │                                         │
│              CommandRunnerService (NEW, @MainActor @Observable)        │
│                              │                                         │
│       ┌──────────────────────┼──────────────────────┐                 │
│       │                      │                       │                 │
│   CommandSpec        OutputLine model           CommandState           │
│  (value type)        (value type, Sendable)    (enum, published)      │
│                              │                                         │
├──────────────────────────────┼─────────────────────────────────────────┤
│                   Foundation.Process Layer                              │
│                              │                                         │
│              ProcessActor (NEW, actor) — owns Process lifecycle        │
│              Pipe + FileHandle readabilityHandler                      │
│              AsyncStream<OutputLine> delivery to MainActor             │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Component Responsibilities

### New Components

| Component | Responsibility | Isolation | File |
|-----------|---------------|-----------|------|
| `CommandRunnerService` | Owned by ContentView (@State), exposes run/cancel API, holds execution state | `@MainActor @Observable` | Services/CommandRunnerService.swift |
| `ProcessActor` | Owns Foundation.Process lifecycle, reads pipes, yields OutputLines | `actor` (nonisolated from MainActor) | Services/ProcessActor.swift |
| `CommandSpec` | Value type describing a GSD command: name, args, workingDir, displayName | `struct Sendable` | Models/CommandSpec.swift |
| `OutputLine` | Single line of output with metadata: text, stream (stdout/stderr), timestamp | `struct Sendable` | Models/OutputLine.swift |
| `CommandState` | Enum: idle / running(pid) / completed(exitCode) / failed(error) | `enum Sendable` | Models/CommandState.swift |
| `GSDCommands` | Catalog of all GSD commands: static factory methods returning CommandSpec | `enum` (namespace) | Models/GSDCommands.swift |
| `CommandOutputView` | Scrollable output panel, raw or structured mode | `struct View` | Views/CommandRunner/CommandOutputView.swift |
| `CommandRunnerButton` | Reusable button that triggers a specific CommandSpec | `struct View` | Views/CommandRunner/CommandRunnerButton.swift |

### Modified Components

| Component | Modification | Impact |
|-----------|-------------|--------|
| `ContentView` | Add `@State private var commandRunner = CommandRunnerService()`, pass down | Low — add one @State |
| `CommandPaletteView` | Add GSD command section alongside search results, trigger CommandRunnerService.run() | Medium — new section + state |
| `PhaseDetailView` | Add context buttons ("Plan this phase", "Execute") calling CommandRunnerService | Medium — new button row |
| `DetailView` | Add CommandOutputView panel (shown when commandRunner.state != .idle) | Medium — conditional panel |

### Unchanged Components

- All models (Project, Phase, Plan, Task, Roadmap, etc.)
- ProjectService, FileWatcherService, NotificationService, EditorService
- All parsers (RoadmapParser, PlanParser, etc.)
- SidebarView, PhaseCardView, StatsGridView, MilestoneTimelineView
- Theme system

---

## Process/Concurrency Architecture

### The Core Challenge

Foundation.Process is not `Sendable`. It owns FileHandles with `readabilityHandler` closures that run on a dispatch queue. Swift 6 strict concurrency requires explicit actor boundaries.

**Solution: Dedicated ProcessActor wrapping all Process lifecycle.**

This pattern mirrors how FileWatcherService uses `nonisolated(unsafe)` for C callback pointers. Here, we use an `actor` instead to get proper isolation without unsafe escape hatches.

### ProcessActor Pattern

```swift
// ProcessActor.swift
// Isolated actor — NOT @MainActor
// Owns Foundation.Process and its pipes entirely within actor isolation

actor ProcessActor {
    private var process: Process?

    // Runs command and yields OutputLines via AsyncThrowingStream
    func run(spec: CommandSpec) -> AsyncThrowingStream<OutputLine, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: spec.executablePath)
            process.arguments = spec.arguments
            process.currentDirectoryURL = spec.workingDirectory
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            process.environment = buildEnvironment()

            // readabilityHandler runs on GCD, not actor — use Task to re-enter actor
            stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                if let text = String(data: data, encoding: .utf8) {
                    for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                        continuation.yield(OutputLine(text: line, stream: .stdout))
                    }
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    return
                }
                if let text = String(data: data, encoding: .utf8) {
                    for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                        continuation.yield(OutputLine(text: line, stream: .stderr))
                    }
                }
            }

            process.terminationHandler = { p in
                continuation.finish(throwing: p.terminationStatus == 0 ? nil : CommandError.nonZeroExit(p.terminationStatus))
            }

            self.process = process

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    func cancel() {
        process?.terminate()
        process = nil
    }

    func isRunning() -> Bool {
        process?.isRunning ?? false
    }

    private func buildEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        // Ensure PATH includes common tool locations
        let paths = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", env["PATH"] ?? ""]
        env["PATH"] = paths.joined(separator: ":")
        return env
    }
}
```

**Why actor not @MainActor:** ProcessActor must NOT be on the main actor. Process.run() can block briefly. readabilityHandler fires on GCD. Keeping it on its own actor avoids blocking UI.

### CommandRunnerService Pattern

```swift
// CommandRunnerService.swift
// @MainActor @Observable — follows exact pattern of existing services

@MainActor
@Observable
final class CommandRunnerService {
    var state: CommandState = .idle
    var outputLines: [OutputLine] = []
    var currentCommand: CommandSpec?

    private let processActor = ProcessActor()
    private var runningTask: _Concurrency.Task<Void, Never>?

    func run(_ spec: CommandSpec) {
        guard case .idle = state else { return } // Prevent double-run

        state = .running
        currentCommand = spec
        outputLines = []

        runningTask = _Concurrency.Task {
            do {
                let stream = await processActor.run(spec: spec)
                for try await line in stream {
                    // We're back on MainActor — safe to mutate @Observable properties
                    self.outputLines.append(line)
                }
                self.state = .completed(exitCode: 0)
            } catch CommandError.nonZeroExit(let code) {
                self.state = .completed(exitCode: code)
            } catch {
                self.state = .failed(error: error)
            }
        }
    }

    func cancel() {
        runningTask?.cancel()
        runningTask = nil
        _Concurrency.Task { await processActor.cancel() }
        state = .idle
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }
}
```

**Key insight:** The `for try await line in stream` loop automatically resumes on the calling actor (MainActor). Each `outputLines.append(line)` is safely on MainActor. This is the same pattern FileWatcherService uses for `for await changedURLs in eventStream`.

---

## Data Models

### CommandSpec (Sendable value type)

```swift
struct CommandSpec: Sendable, Identifiable {
    let id: UUID = UUID()
    let displayName: String      // "Plan Phase 3"
    let executablePath: String   // "/usr/local/bin/node" or absolute path
    let arguments: [String]      // ["~/.claude/...", "gsd:new-plan", ...]
    let workingDirectory: URL    // project.path
    let contextDescription: String  // shown in output header
}
```

### OutputLine (Sendable, drives UI)

```swift
struct OutputLine: Sendable, Identifiable {
    let id: UUID = UUID()
    let text: String
    let stream: OutputStream   // stdout | stderr
    let timestamp: Date = Date()

    enum OutputStream: Sendable { case stdout, stderr }
}
```

### CommandState (drives UI state machine)

```swift
enum CommandState: Sendable {
    case idle
    case running
    case completed(exitCode: Int32)
    case failed(error: Error)   // Note: Error is not Sendable — wrap in string if needed
}
```

**Swift 6 note on Error:** `Error` is not `Sendable`. Use `String` or a custom `Sendable` error type in `CommandState.failed` to avoid concurrency warnings.

### GSDCommands (catalog)

```swift
enum GSDCommands {
    // Returns CommandSpec configured for the given context
    static func quick(description: String, projectPath: URL) -> CommandSpec {
        CommandSpec(
            displayName: "Quick Task",
            executablePath: resolveClaude(),
            arguments: ["--no-stream", "gsd:quick"],
            workingDirectory: projectPath,
            contextDescription: "Running /gsd:quick in \(projectPath.lastPathComponent)"
        )
    }

    static func executePhase(_ phase: Phase, projectPath: URL) -> CommandSpec {
        CommandSpec(
            displayName: "Execute Phase \(phase.number)",
            executablePath: resolveClaude(),
            arguments: ["--no-stream", "/gsd:execute-phase"],
            workingDirectory: projectPath,
            contextDescription: "Executing Phase \(phase.number): \(phase.name)"
        )
    }

    private static func resolveClaude() -> String {
        // Check common Claude CLI locations
        let candidates = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            (ProcessInfo.processInfo.environment["HOME"] ?? "") + "/.claude/bin/claude"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "claude"
    }
}
```

---

## View Architecture: New Views

### CommandOutputView

A scrollable output panel that appears in DetailView when a command is running or has completed.

```swift
struct CommandOutputView: View {
    let commandRunner: CommandRunnerService

    @SwiftUI.State private var showRaw = false
    @SwiftUI.State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header bar: command name, status, toggle, cancel
            commandHeader

            Divider()

            // Output: raw lines or structured view
            if showRaw {
                rawOutputView
            } else {
                structuredOutputView
            }
        }
        .background(Theme.bg0Hard)
        .cornerRadius(8)
    }

    private var rawOutputView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(commandRunner.outputLines) { line in
                        Text(line.text)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(line.stream == .stderr ? Theme.brightRed : Theme.fg2)
                            .id(line.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: commandRunner.outputLines.count) { _, _ in
                // Auto-scroll to bottom as output streams in
                if let last = commandRunner.outputLines.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}
```

**Auto-scroll pattern:** onChange drives scrollTo on outputLines.count change. Mirrors pattern used in terminal apps. No complex binding needed because CommandRunnerService is @Observable.

### CommandRunnerButton

A reusable button component placed on PhaseDetailView and PlanCard:

```swift
struct CommandRunnerButton: View {
    let spec: CommandSpec
    let commandRunner: CommandRunnerService
    let label: String
    let icon: String

    var body: some View {
        Button {
            commandRunner.run(spec)
        } label: {
            Label(label, systemImage: icon)
        }
        .disabled(commandRunner.isRunning)
        .buttonStyle(.bordered)
        .tint(Theme.accent)
    }
}
```

---

## Integration Points

### 1. ContentView → CommandRunnerService Injection

**Pattern:** Same as how ProjectService is owned and injected.

```swift
// ContentView.swift — only change: add one @State
@SwiftUI.State private var commandRunner = CommandRunnerService()

// Pass to DetailView
DetailView(
    selectedProject: ...,
    projectName: ...,
    commandRunner: commandRunner   // NEW parameter
)

// CommandOutputView shown when not idle
if !commandRunner.state.isIdle {
    CommandOutputView(commandRunner: commandRunner)
        .frame(height: 300)
}
```

**Why not @EnvironmentObject:** Existing services follow parameter injection, not environment. Consistent with codebase pattern. CommandRunner is project-context-specific.

### 2. CommandPaletteView Extension

The existing CommandPaletteView supports searching projects/phases/requirements. Extend with GSD command section:

```swift
// In CommandPaletteView:
// Add CommandResult.gsdCommand(CommandSpec, projectID: UUID) case

// New section in resultsList:
Section("GSD Commands") {
    ForEach(gsdCommandResults) { result in
        CommandResultRow(result: result)
    }
}

// On selection: call commandRunner.run(spec) and dismiss
```

**Existing CommandResult enum** must gain a new case — only breaking change is adding `.gsdCommand`. All existing switch statements need a new case, but most will fall through to default.

### 3. PhaseDetailView Context Buttons

Add a button row to the existing header in PhaseDetailView:

```swift
// In PhaseDetailView header HStack — after existing "Open in Editor" button:
if let project = project {  // already available
    CommandRunnerButton(
        spec: GSDCommands.planPhase(phase, projectPath: project.path),
        commandRunner: commandRunner,  // NEW parameter to PhaseDetailView
        label: "Plan this Phase",
        icon: "wand.and.stars"
    )
}
```

**PhaseDetailView signature change:** Add `commandRunner: CommandRunnerService` parameter. All call sites (DetailView line 121) must pass it.

### 4. DetailView Output Panel

Output panel appears between header section and phase list when command is active:

```swift
// In DetailView, between Divider and ScrollView:
if !commandRunner.state.isIdle {
    CommandOutputView(commandRunner: commandRunner)
        .frame(height: 300)
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))

    Divider()
}
```

**Layout impact:** Output panel pushes phase cards down. 300pt height is reasonable for a macOS window. Consider making it resizable (NSViewRepresentable drag handle) in future.

---

## Data Flow Diagrams

### Command Execution Flow

```
User taps "Plan this Phase" button (PhaseDetailView)
    │
    ▼
CommandRunnerButton.action() [MainActor]
    │
    ▼
CommandRunnerService.run(spec) [MainActor]
    │ sets state = .running
    │ creates _Concurrency.Task {}
    │
    ▼
ProcessActor.run(spec) [actor, background]
    │ creates Foundation.Process
    │ sets up Pipe + readabilityHandler
    │ calls process.run()
    │ returns AsyncThrowingStream<OutputLine>
    │
    ▼
readabilityHandler fires [GCD queue, nonisolated]
    │ reads availableData from FileHandle
    │ continuation.yield(OutputLine) — Sendable, safe across actors
    │
    ▼
for await line in stream [back on MainActor via Task]
    │
    ▼
CommandRunnerService.outputLines.append(line) [MainActor]
    │
    ▼
@Observable triggers view update [SwiftUI]
    │
    ▼
CommandOutputView re-renders new line
    │ auto-scrolls to bottom via ScrollViewReader
    │
    ▼
Process terminates → terminationHandler fires [GCD]
    │ continuation.finish()
    │
    ▼
for-await loop exits [MainActor]
    │
    ▼
CommandRunnerService.state = .completed(exitCode: N) [MainActor]
    │
    ▼
FSEvents detects .planning/ change [within ~1 second]
    │ (GSD commands write to .planning/)
    │
    ▼
ProjectService.reloadProject() [existing flow]
    │
    ▼
All views update with new project data [existing @Observable]
```

### State Machine

```
              run(spec)          terminationHandler
    .idle ──────────────▶ .running ──────────────▶ .completed(exitCode)
      ▲                      │
      │                      │ error thrown
      │           cancel()   ▼
      └──────────────── .failed(error)
```

---

## Recommended Project File Structure

```
GSDMonitor/
├── App/
│   ├── GSDMonitorApp.swift     (unchanged)
│   └── AppDelegate.swift        (unchanged)
├── Models/
│   ├── (existing models)        (unchanged)
│   ├── CommandSpec.swift        (NEW)
│   ├── OutputLine.swift         (NEW)
│   ├── CommandState.swift       (NEW)
│   └── GSDCommands.swift        (NEW — command catalog)
├── Services/
│   ├── (existing services)      (unchanged)
│   ├── CommandRunnerService.swift (NEW — @MainActor @Observable)
│   └── ProcessActor.swift       (NEW — actor, owns Process lifecycle)
├── Views/
│   ├── ContentView.swift        (MODIFIED — add commandRunner @State)
│   ├── DetailView.swift         (MODIFIED — add CommandOutputView panel)
│   ├── CommandPalette/
│   │   └── CommandPaletteView.swift  (MODIFIED — add GSD command section)
│   ├── Dashboard/
│   │   └── PhaseDetailView.swift    (MODIFIED — add context buttons)
│   └── CommandRunner/           (NEW folder)
│       ├── CommandOutputView.swift  (NEW — scrollable output panel)
│       └── CommandRunnerButton.swift (NEW — reusable trigger button)
├── Theme/
│   └── Theme.swift              (unchanged)
└── Utilities/
    └── PreviewData.swift        (updated — add CommandRunnerService preview)
```

**New files:** 7 (CommandSpec, OutputLine, CommandState, GSDCommands, CommandRunnerService, ProcessActor, CommandOutputView, CommandRunnerButton)
**Modified files:** 4 (ContentView, DetailView, CommandPaletteView, PhaseDetailView)
**Total new/modified:** ~11 files

---

## Architectural Patterns

### Pattern 1: Actor-Isolated Process Ownership

**What:** Wrap Foundation.Process in a dedicated `actor` so all process lifecycle operations are actor-isolated, preventing data races without unsafe annotations.

**When to use:** Any time a reference type with callbacks (Process, URLSession delegate) needs to live in a Swift 6 concurrent context.

**Trade-offs:**
- Pro: Full Swift 6 compliance, no `nonisolated(unsafe)` needed
- Pro: Clean separation — MainActor service never touches Process directly
- Con: Slight async overhead for cancel() calls (hop to ProcessActor)
- Con: More indirection than synchronous approach

**Example:**

```swift
actor ProcessActor {
    private var process: Process?

    func run(spec: CommandSpec) -> AsyncThrowingStream<OutputLine, Error> { ... }
    func cancel() { process?.terminate() }
}

@MainActor
@Observable
final class CommandRunnerService {
    private let processActor = ProcessActor()

    func run(_ spec: CommandSpec) {
        _Concurrency.Task {
            for try await line in await processActor.run(spec: spec) {
                self.outputLines.append(line)   // safe: back on MainActor
            }
        }
    }
}
```

### Pattern 2: AsyncThrowingStream for Live Output

**What:** Use `AsyncThrowingStream<OutputLine, Error>` to bridge GCD-based FileHandle callbacks into async/await. readabilityHandler calls `continuation.yield()` (safe from any queue because continuation is Sendable).

**When to use:** When bridging callback-based APIs (delegates, handlers, C callbacks) into Swift concurrency.

**Trade-offs:**
- Pro: Naturally composable with `for await` loops
- Pro: Cancellation propagates automatically via Task cancellation
- Pro: Back-pressure built-in (producer blocks if consumer is slow)
- Con: AsyncThrowingStream (not AsyncStream) needed for termination errors — adds `try` to for-await

**Note on readabilityHandler and EOF:** Apple's documentation does not guarantee that readabilityHandler fires on EOF. The termination pattern should use `process.terminationHandler` to call `continuation.finish()`, not rely on an empty data read.

### Pattern 3: Observable State Machine for UI

**What:** CommandRunnerService exposes `state: CommandState` and `outputLines: [OutputLine]` as `@Observable` properties. Views subscribe automatically via SwiftUI's observation machinery.

**When to use:** Always — this is the existing pattern for all services in the codebase.

**Trade-offs:**
- Pro: Zero glue code — SwiftUI observation handles view updates automatically
- Pro: Consistent with ProjectService, NotificationService patterns
- Con: All state in one service — if multiple parallel runs needed in future, need refactor

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Foundation.Process on MainActor

**What people do:** Put Process creation and management directly in a `@MainActor @Observable` service, calling `process.run()` from MainActor.

**Why it's wrong:** `process.run()` can briefly block. `process.waitUntilExit()` definitely blocks. Blocking the main thread causes UI freezes. `readabilityHandler` closures also cause data race warnings in Swift 6 when accessing actor-isolated properties.

**Do this instead:** Dedicated `actor ProcessActor` owns all Process operations. CommandRunnerService only holds the AsyncThrowingStream and drives UI state.

### Anti-Pattern 2: readabilityHandler Accessing MainActor State Directly

**What people do:**

```swift
// WRONG — Swift 6 data race
pipe.fileHandleForReading.readabilityHandler = { handle in
    let text = String(data: handle.availableData, encoding: .utf8)!
    self.outputLines.append(text)  // ❌ self is @MainActor, handler runs on GCD
}
```

**Why it's wrong:** `readabilityHandler` runs on a GCD queue. `self.outputLines` is MainActor-isolated. Swift 6 flags this as a data race.

**Do this instead:** Yield to AsyncThrowingStream continuation (which is Sendable) and let the `for await` loop re-enter MainActor:

```swift
// CORRECT
pipe.fileHandleForReading.readabilityHandler = { handle in
    let data = handle.availableData
    guard !data.isEmpty else { return }
    continuation.yield(OutputLine(text: String(data: data, encoding: .utf8) ?? ""))
    // continuation.yield is Sendable — safe from any queue
}
// Then in CommandRunnerService:
for try await line in stream {
    self.outputLines.append(line)  // ✅ back on MainActor
}
```

### Anti-Pattern 3: Blocking the Async Task with waitUntilExit

**What people do:**

```swift
_Concurrency.Task {
    process.run()
    process.waitUntilExit()  // ❌ blocks the Task's thread
    completion(process.terminationStatus)
}
```

**Why it's wrong:** `waitUntilExit()` blocks the thread. Swift concurrency Tasks run on a cooperative thread pool — blocking one thread starves other async work.

**Do this instead:** Use `terminationHandler` callback + continuation, or rely on the AsyncThrowingStream finishing when the process exits.

### Anti-Pattern 4: Embedding Full Terminal Emulator

**What people do:** Add SwiftTerm or similar PTY-based terminal emulator to get "real" terminal behavior.

**Why it's wrong for this project:** The project explicitly calls out "not a full terminal emulator." SwiftTerm adds significant complexity (PTY management, ANSI escape code rendering, input forwarding). GSD commands don't require interactive input — they run to completion.

**Do this instead:** Plain Pipe + readabilityHandler. Strip ANSI escape codes from output before displaying (simple regex). Show raw text in monospaced font. This handles 95% of GSD command output without PTY complexity.

### Anti-Pattern 5: Shared Global CommandRunnerService

**What people do:** Make CommandRunnerService a singleton or inject via @EnvironmentObject.

**Why it's wrong:** CommandRunner is inherently project-contextual. A command runs against a specific project's working directory. Sharing across projects causes context confusion.

**Do this instead:** Owned by ContentView as `@State`, passed to child views as a parameter — exactly the pattern ProjectService uses.

---

## Integration Boundaries

### New vs Existing Boundaries

| Boundary | Communication Method | Notes |
|----------|---------------------|-------|
| CommandRunnerService ↔ ProcessActor | async/await method calls across actor boundary | ProcessActor is NOT MainActor — hop is intentional |
| ProcessActor ↔ Foundation.Process | Synchronous within actor isolation | Process owned entirely by actor |
| readabilityHandler ↔ AsyncThrowingStream | continuation.yield() — Sendable | GCD → async boundary |
| CommandRunnerService ↔ SwiftUI views | @Observable property reads | Same pattern as ProjectService |
| CommandRunnerService ↔ ProjectService | None directly | FSEvents picks up .planning/ changes after GSD command writes |
| PhaseDetailView ↔ CommandRunnerService | Parameter injection | CommandRunner passed as parameter (not environment) |
| CommandPaletteView ↔ CommandRunnerService | Parameter injection | Add to existing view initializer |

### Execution Environment

GSD commands invoke Claude CLI (`claude`) which must be findable on PATH. The app inherits the user's login shell environment via `ProcessInfo.processInfo.environment`, but this may not include Homebrew paths in a sandboxed or non-login context.

**Mitigation:** `GSDCommands.resolveExecutable()` probes common install locations:
- `/usr/local/bin/claude` (Intel Homebrew / manual)
- `/opt/homebrew/bin/claude` (Apple Silicon Homebrew)
- `~/.claude/bin/claude` (Claude's own install path)

**App sandbox:** PROJECT.md confirms sandbox is disabled ("Developer utility needs ~/Developer filesystem access"). Process.run() requires `com.apple.security.temporary-exception.mach-lookup.global-name` in sandboxed apps, but this is moot since sandbox is disabled.

---

## Build Order (Dependency-Respecting)

**Phase 1 (Foundation — no dependencies on other new code):**
1. `CommandSpec.swift` — pure value type, no deps
2. `OutputLine.swift` — pure value type, no deps
3. `CommandState.swift` — pure enum, no deps
4. `ProcessActor.swift` — depends only on Foundation + new models
5. `CommandRunnerService.swift` — depends on ProcessActor + models

**Phase 2 (Command Catalog — depends on Phase 1 models):**
6. `GSDCommands.swift` — static factory for CommandSpec instances, needs CommandSpec

**Phase 3 (Output View — depends on Phase 1 service):**
7. `CommandOutputView.swift` — depends on CommandRunnerService for @Observable state
8. `CommandRunnerButton.swift` — depends on CommandRunnerService + CommandSpec

**Phase 4 (Integration — depends on all above):**
9. `ContentView.swift` — add commandRunner @State, pass to DetailView
10. `DetailView.swift` — add CommandOutputView panel, pass commandRunner to PhaseDetailView
11. `PhaseDetailView.swift` — add context buttons using CommandRunnerButton
12. `CommandPaletteView.swift` — add GSD command section

**Rationale:** Service layer builds bottom-up (models → actors → services). Views build after their dependencies. ContentView is last because it integrates all other new pieces. No circular dependencies.

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single command at a time | Recommended architecture — CommandRunnerService holds one state machine |
| Parallel commands | Add `[UUID: CommandRunnerService]` dictionary, one per project or one per command |
| Command history | Add `[CommandExecution]` array to service, persist to UserDefaults or JSON |
| Complex output parsing | Add `OutputParser` struct that transforms OutputLine stream into structured data (task names, progress markers) |

**First bottleneck:** Output volume. GSD commands via Claude can produce hundreds of lines rapidly. LazyVStack in ScrollView handles this well. If performance degrades, add line count cap (keep last 1000 lines).

**Second bottleneck:** ANSI escape codes. Claude CLI output may contain ANSI color codes that render as garbage text. Add simple stripping before displaying.

---

## Sources

### Official Apple Documentation
- [Foundation.Process | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/process) — Process lifecycle API
- [Pipe | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/pipe) — Pipe for stdout/stderr
- [FileHandle.readabilityHandler | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/filehandle/1412413-readabilityhandler) — Async reads
- [AsyncThrowingStream | Apple Developer Documentation](https://developer.apple.com/documentation/swift/asyncthrowingstream) — Async stream with error
- [Adopting strict concurrency in Swift 6 apps](https://developer.apple.com/documentation/swift/adoptingswift6) — Swift 6 migration guide

### Swift Forums / Community (MEDIUM confidence, verified against Apple docs)
- [Swift 6 Concurrency + NSPipe Readability Handlers — Swift Forums](https://forums.swift.org/t/swift-6-concurrency-nspipe-readability-handlers/59834) — Actor pattern for readabilityHandler isolation
- [Running a Child Process with Standard Input and Output — Apple Developer Forums](https://developer.apple.com/forums/thread/690310) — Pipe-based process output patterns
- [Swift Process with Pseudo Terminal — Swift Forums](https://forums.swift.org/t/swift-process-with-psuedo-terminal/51457) — PTY vs Pipe tradeoffs (confirms Pipe is sufficient for non-interactive commands)

### Existing Codebase (HIGH confidence — ground truth)
- `GSDMonitor/Services/FileWatcherService.swift` — AsyncStream + C callback pattern (directly analogous)
- `GSDMonitor/Services/NotificationService.swift` — @Observable @MainActor service with withObservationTracking
- `GSDMonitor/Services/ProjectService.swift` — _Concurrency.Task usage pattern, @Observable @MainActor class
- `GSDMonitor/Views/CommandPalette/CommandPaletteView.swift` — Existing CommandResult enum extension point

---

*Architecture research for: GSD Monitor v1.2 — Embedded GSD Command Runner*
*Researched: 2026-02-17*
*Integration points: CommandRunnerService (new service), ProcessActor (new actor), 4 modified views, 7 new files*
