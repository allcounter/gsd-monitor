# Project Research Summary

**Project:** GSD Monitor v1.2 — Embedded GSD Command Runner
**Domain:** Native macOS SwiftUI app — CLI process execution, streaming output, ANSI rendering
**Researched:** 2026-02-17
**Confidence:** HIGH

## Executive Summary

GSD Monitor v1.2 adds an embedded command runner to a fully working v1.1 app. The task is not greenfield — it is a well-scoped additive layer. The core engineering challenge is reliably spawning the `claude` CLI as a child process, streaming its output live to the SwiftUI UI across a 10+ minute execution window, and integrating that runner cleanly with the existing FSEvents-driven project reload cycle. Research across all four areas converges on a clear architecture: a dedicated `ProcessActor` (Swift `actor`) owns the child process lifecycle, an `AsyncThrowingStream` bridges GCD callbacks to Swift concurrency, and a `@MainActor @Observable` `CommandRunnerService` drives the UI — matching patterns already established in the codebase.

The recommended approach requires zero new Swift Package Manager dependencies. All needed capabilities — `Foundation.Process`, `Darwin.openpty` (if PTY is needed), `AsyncThrowingStream`, `AttributedString`, Swift Regex — are available in the project's existing Swift 6 / macOS 14+ runtime. ANSI output should be stripped (not color-rendered) for the MVP, with an optional color rendering pass using a custom 50-line parser. The command palette, phase detail view, and an output panel in the detail area are the three UI integration points.

The highest risks are process management pitfalls that cause silent failures: the 64 KiB pipe deadlock, Swift 6 `Sendable` violations in `readabilityHandler` closures, and orphaned child processes when Swift Task cancellation does not propagate to the OS process. These are all solvable with established patterns documented in PITFALLS.md, but they must be addressed in Phase 1 before any UI work begins. The FSEvents feedback loop during active commands is the highest-risk integration concern and requires explicit coordination between `CommandRunnerService` and `ProjectService`.

## Key Findings

### Recommended Stack

The v1.2 stack additions build entirely on Foundation and Darwin — no new dependencies. `Foundation.Process` paired with `Pipe` handles child process spawning. `Darwin.openpty` can be used if `claude` CLI requires a pseudo-terminal to emit ANSI (use `openpty`, not `forkpty` — Apple engineers explicitly warn `forkpty` is unsafe in Swift's runtime). `AsyncThrowingStream<OutputLine, Error>` bridges `readabilityHandler` GCD callbacks into the Swift concurrency model. `AttributedString` with `LazyVStack` in a `ScrollView` handles the output panel rendering; `scrollPosition(id:)` (macOS 14+) enables auto-scroll.

**Core technologies:**
- `Foundation.Process` + `Pipe`: spawn `claude` CLI, stream stdout/stderr — native, no deps, in production use across macOS apps
- `Darwin.openpty`: pseudo-terminal allocation for ANSI output — use instead of `forkpty` (confirmed unsafe in Swift by Apple engineer Quinn)
- `AsyncThrowingStream<OutputLine, Error>`: bridge GCD callbacks to async/await — the correct Swift 6 concurrency pattern for this problem
- `actor ProcessActor`: thread-safe process lifecycle ownership — prevents Swift 6 data races in `readabilityHandler` without `nonisolated(unsafe)`
- `AttributedString` + `LazyVStack` + `scrollPosition(id:)`: streaming output panel — native SwiftUI, zero AppKit bridging
- Custom ANSI parser (~50 lines, Swift Regex `#/\e\[(\d+(?:;\d+)*)m/#`): ANSI escape codes to `AttributedString` — all available third-party libs are output-generators, not parsers

### Expected Features

The embedded runner solves a specific problem: running GSD slash commands from the app without opening a terminal, watching them run for 10+ minutes, and reviewing results without context switching. Research identified a clear MVP boundary.

**Must have (P1 — table stakes for v1.2 launch):**
- Live streaming output with auto-scroll — commands run 10+ min; users will abandon app if no feedback
- Running/stopped state indicator with elapsed timer — critical for long-running jobs
- Cancel/kill with `withTaskCancellationHandler` wiring to `process.terminate()` + process group kill
- ANSI escape code stripping — required before display; raw codes corrupt SwiftUI `Text` views
- Exit code / success-failure indication — users need binary outcome without reading full output
- stderr visually distinct from stdout (Gruvbox red) — `claude` CLI errors go to stderr
- Context run buttons on `PhaseDetailView` — primary trigger surface for `/gsd:quick`
- Working directory per project — GSD commands must run in `project.path`, not app cwd
- Environment resolution via login shell — `claude` not on launchd PATH; commands always fail without this

**Should have (P2 — add after core validated):**
- Structured output view — parse GSD banners/task markers; toggle with raw mode
- Command palette integration — add GSD commands to existing Cmd+K palette
- Command history with re-run — records runs per project with timestamp and exit code
- Plan-level run buttons on `PlanCard` in `PhaseDetailView`

**Defer (v2+):**
- Full PTY / interactive stdin — GSD commands are non-interactive by design (`--dangerously-skip-permissions`)
- Multiple simultaneous commands per project — queue instead; one per project is correct for GSD's agent model
- Output search, scheduling, export — marginal value for 10-minute runs

### Architecture Approach

The architecture grafts cleanly onto v1.1's established patterns. A new `ProcessActor` (plain Swift `actor`, not `@MainActor`) owns the `Foundation.Process` lifecycle, preventing data races without unsafe annotations. A new `CommandRunnerService` (`@MainActor @Observable`, matching `ProjectService`) holds the UI state machine and consumes the output stream. Views observe `CommandRunnerService` via SwiftUI's `@Observable` machinery — the same zero-glue-code pattern used throughout the codebase. The output panel appears in `DetailView` as a conditional `CommandOutputView` block when state is not `.idle`. The implementation is directly analogous to how `FileWatcherService` uses `AsyncStream` and C callback patterns.

**Major components:**
1. `ProcessActor` (actor) — owns `Foundation.Process`, pipes, `readabilityHandler`; yields `OutputLine` via `AsyncThrowingStream`
2. `CommandRunnerService` (@MainActor @Observable) — exposes `run()`, `cancel()`, `state`, `outputLines`; consumes stream from `ProcessActor`
3. `CommandSpec` / `OutputLine` / `CommandState` (Sendable value types) — cross-actor data models
4. `GSDCommands` (enum namespace) — static factory for `CommandSpec` instances; resolves `claude` CLI path from known install locations
5. `CommandOutputView` (SwiftUI view) — scrollable output panel with raw/structured toggle and auto-scroll
6. `CommandRunnerButton` (SwiftUI view) — reusable trigger button, disabled while `commandRunner.isRunning`

**Modified files:** `ContentView`, `DetailView`, `CommandPaletteView`, `PhaseDetailView` (4 files, surgical changes)
**New files:** 7 (`CommandSpec`, `OutputLine`, `CommandState`, `GSDCommands`, `CommandRunnerService`, `ProcessActor`, `CommandOutputView`, `CommandRunnerButton`)

### Critical Pitfalls

1. **Pipe buffer deadlock** — Using `readDataToEndOfFile()` or `waitUntilExit()` before draining stdout/stderr deadlocks silently when output exceeds 64 KiB. GSD commands will always exceed this. Use `readabilityHandler` exclusively; never call `waitUntilExit()` on any actor thread.

2. **Task cancellation does not kill child process** — Cancelling a Swift `Task` does not send SIGTERM. `claude` CLI spawns sub-agents that keep running. Use `withTaskCancellationHandler` wired to `process.terminate()` + a delayed process group kill (`kill(-pid, SIGTERM)` then `SIGKILL` after 2 seconds).

3. **Swift 6 Sendable violations in `readabilityHandler`** — `readabilityHandler` is `@Sendable`; direct mutation of `@MainActor` state causes compile errors. Wrapping each chunk in `Task { await }` creates actor queue backlog. Bridge to `AsyncThrowingStream` continuation (`Data` is `Sendable`); consume the stream on `MainActor` via a single `for try await` loop.

4. **PATH not inherited from login shell** — GUI apps inherit launchd's minimal PATH. `claude` (installed via npm, Homebrew, or nvm) is not on it. Source the login shell environment via `zsh -l -c env` at startup; cache the result; use it as the base for all child process environments.

5. **FSEvents feedback loop during command execution** — GSD commands write files to `.planning/` continuously. The existing `FileWatcherService` triggers `ProjectService.reloadProject()` on each write, causing hundreds of unnecessary reloads during a 10-minute run. `CommandRunnerService` must signal `ProjectService` on start and completion; suppress file-reload (not the watcher itself) while a command is active for that project.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Process Foundation
**Rationale:** All other phases depend on a reliable, Swift 6-compliant process execution layer. Ship nothing to UI until the process layer is verified. The three most critical pitfalls (deadlock, Task cancellation, Swift 6 concurrency) all live here and are invisible without explicit stress tests. No UI work should begin until this phase passes its verification gate.
**Delivers:** `ProcessActor`, `CommandRunnerService`, `CommandSpec`, `OutputLine`, `CommandState`, environment resolution via login shell, ANSI stripping utility, `GSDCommands` catalog — the entire headless engine.
**Addresses features:** CommandRunnerService foundation, environment variable resolution, cancel/kill, working directory per project
**Avoids:** Pipe deadlock (readabilityHandler pattern), Swift 6 Sendable violations (actor isolation), Task cancellation orphans (withTaskCancellationHandler), PATH failures (login shell env capture)
**Verification gate:** Stress test with 200 KB output process — no hang. Cancel during 5-min command — zero orphaned processes in Activity Monitor. `claude --version` succeeds from app on a fresh macOS account without .zshrc.

### Phase 2: Output Panel UI
**Rationale:** With a verified process layer, the output UI is a straightforward SwiftUI binding exercise. ANSI rendering is the main new complexity; build and unit-test the ANSI parser against real claude CLI output before integrating into UI. Raw display (stripped ANSI) is the MVP; structured view and color rendering are enhancements.
**Delivers:** `CommandOutputView` (raw mode, auto-scroll, stderr coloring, exit code display, running indicator, cancel button, elapsed timer), ANSI strip/parse utilities, `CommandRunnerButton`, integration into `DetailView` and `PhaseDetailView`.
**Addresses features:** Live streaming output, running indicator, cancel UX, auto-scroll, stderr distinction, exit code display, context run buttons on PhaseDetailView
**Uses stack:** `LazyVStack` + `ScrollViewReader` + `scrollPosition(id:)`, `AttributedString`, Gruvbox theme colors, custom ANSI state-machine parser
**Avoids:** ANSI split-sequence corruption (stateful buffer parser, not stateless regex), unbounded output buffer (2000-line rolling cap)

### Phase 3: FSEvents + CommandRunner Integration
**Rationale:** FSEvents coordination is the highest-risk integration concern. It touches both the new `CommandRunnerService` and the existing `ProjectService`. Isolating this in its own phase allows independent verification and clean rollback if the coordination design needs rework.
**Delivers:** `CommandRunnerService` to `ProjectService` coordination protocol, command-active suppression of file-reload (pause or extend debounce to 10s), single forced reload on command completion.
**Addresses features:** Prevents UI flicker and CPU waste during long-running commands; ensures project state is fresh immediately after GSD command writes complete
**Avoids:** FSEvents feedback loop (Pitfall 5), same-project double-run (per-project running state guard), multiple-command state corruption

### Phase 4: Command Palette + History (P2 features)
**Rationale:** Core value is validated by Phase 2. These are ergonomic enhancements. Command palette is a surgical extension of the existing `CommandResult` enum; history is an additive model. Both are low-risk after the foundation is stable. Either can be trimmed to v1.2.x if timeline is tight.
**Delivers:** GSD command section in Cmd+K palette (`CommandPaletteView` + new `.gsdCommand` case in `CommandResult`), `CommandRun` history model, plan-level run buttons on `PlanCard`.
**Addresses features:** Command palette integration, command history, plan-level run buttons
**Implements:** `CommandPaletteView` extension pattern already present in codebase

### Phase Ordering Rationale

- Process layer must precede UI — discovering pitfalls like deadlock or PATH failure in production is high-cost; they are cheap to fix in Phase 1 with stress tests
- ANSI rendering belongs in Phase 2 (same phase as UI) because stripped output is the working fallback; color rendering is a polish layer on top
- FSEvents coordination is intentionally isolated in Phase 3 because it involves cross-service state that is easy to break and needs its own verification criteria separate from the output UI
- Command palette and history (Phase 4) have no blocking dependency on Phase 3 other than `CommandRunnerService` existing; they can be moved earlier or deferred without risk

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Process Foundation):** The `openpty` vs Pipe decision is documented but requires a prototype to validate. Specifically: does `claude` CLI detect a non-TTY context and auto-strip its ANSI output, or does it always emit ANSI regardless? The answer changes whether PTY is needed at all. Spike this before writing the phase plan.
- **Phase 3 (FSEvents Integration):** The `ProjectService` to `CommandRunnerService` coordination protocol has no prior art in the codebase. The three design options (pause reload / extend debounce / post-run reload) need a spike before committing to an implementation plan.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Output Panel UI):** `LazyVStack` + `ScrollViewReader` + `AttributedString` is well-documented and partially in use in the project. ANSI stripping is a solved problem. ARCHITECTURE.md provides the exact view code pattern.
- **Phase 4 (Palette + History):** Extending an existing enum and adding a history model follows established project patterns with no new architectural territory.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies are Foundation/Darwin built-ins. Rejections of SwiftTerm, swift-subprocess, and forkpty verified against official sources and library documentation. Zero new dependencies conclusion is strong. |
| Features | HIGH | Table stakes derived from VS Code, IntelliJ, Xcode, GitHub Actions output panel analysis. GSD-specific output patterns sourced from GSD workflow docs. P1/P2/v2+ split is clear and well-motivated. |
| Architecture | HIGH | ProcessActor + AsyncThrowingStream pattern verified from Swift Forums thread on this exact Swift 6 issue. Pattern is directly analogous to FileWatcherService already in the codebase (highest-confidence source). |
| Pitfalls | HIGH (process/concurrency), MEDIUM (FSEvents/UI scale) | Pipe deadlock, Swift 6 Sendable, PATH isolation all sourced from Apple engineer posts and official documentation. FSEvents feedback loop is an integration inference — high likelihood but rate not measured against production GSD output. |

**Overall confidence:** HIGH

### Gaps to Address

- **PTY requirement for claude CLI:** Research recommends using `Pipe` with ANSI stripping for the MVP. It is unclear whether `claude` CLI detects a non-TTY context and automatically strips its own ANSI output or always emits ANSI regardless. Validate with `claude --version` via `Foundation.Process` before committing to the ANSI stripping approach. If claude strips codes itself in non-TTY context, no parser is needed. If not, the stateful ANSI parser (PITFALLS.md Pitfall 4) is required to handle split sequences.

- **`readabilityHandler` EOF reliability on macOS 14+:** PITFALLS.md documents that `readabilityHandler` may not reliably fire on EOF. Research recommends using `terminationHandler` as the authoritative completion signal. Validate with a short `sleep 1` process during Phase 1 before relying on this behavior.

- **`scrollPosition(id:)` with dynamic content:** STACK.md rates this MEDIUM confidence. Auto-scroll behavior with rapidly-appending `LazyVStack` content needs hands-on validation. Fallback is `ScrollViewReader` + `onChange(of: outputLines.count)` + `scrollTo(_:anchor:)`, which is more established and can serve as the Phase 2 starting point.

- **Process group kill for claude sub-agents:** Research recommends killing the whole process group (`kill(-pid, SIGTERM)`) when cancelling, because `claude` spawns sub-agents. Validate that `process.processIdentifier` is the process group leader before using `killpg`. If not, explicit process group management may be needed.

## Sources

### Primary (HIGH confidence)
- [Foundation.Process — Apple Developer Documentation](https://developer.apple.com/documentation/foundation/process) — Process lifecycle API
- [AsyncThrowingStream — Apple Developer Documentation](https://developer.apple.com/documentation/swift/asyncthrowingstream) — Async stream with error
- [Adopting strict concurrency in Swift 6 apps — Apple](https://developer.apple.com/documentation/swift/adoptingswift6) — Swift 6 migration guide
- [Swift 6 Concurrency + NSPipe Readability Handlers — Swift Forums](https://forums.swift.org/t/swift-6-concurrency-nspipe-readability-handlers/59834) — Actor pattern for readabilityHandler (HIGH confidence)
- [Swift Process with Pseudo Terminal — Swift Forums](https://forums.swift.org/t/swift-process-with-psuedo-terminal/51457) — openpty vs forkpty; Quinn warning confirmed
- [Running a Child Process with Standard IO — Apple Developer Forums](https://developer.apple.com/forums/thread/690310) — Pipe-based process output patterns
- [Working with Process Pipe and Its 64KiB Limit — Christian Tietze (2025)](https://christiantietze.de/posts/2025/03/process-pipe-64kib-limit/) — Pipe deadlock
- GSDMonitor/Services/FileWatcherService.swift (existing codebase) — AsyncStream + C callback pattern; direct architectural analogue for ProcessActor pattern

### Secondary (MEDIUM confidence)
- [VS Code Panel UX Guidelines](https://code.visualstudio.com/api/ux-guidelines/panel) — Panel placement and toolbar patterns
- [IntelliJ Run Tool Window](https://www.jetbrains.com/help/idea/run-tool-window.html) — Stop/Kill, cancel UX patterns
- [Task Cancellation in Swift Concurrency — Swift with Majid (2025)](https://swiftwithmajid.com/2025/02/11/task-cancellation-in-swift-concurrency/) — withTaskCancellationHandler
- [What is actor hopping — Hacking with Swift](https://www.hackingwithswift.com/quick-start/concurrency/what-is-actor-hopping-and-how-can-it-cause-problems) — Actor hop performance implications

### Tertiary (LOW confidence / needs validation)
- Structured output parsing patterns — based on observed GSD banner patterns from workflow docs; may not match all GSD command output variants in practice
- FSEvents feedback loop rate during active commands — inferred from .planning/ write frequency; not measured against real claude CLI output volume or timing

---
*Research completed: 2026-02-17*
*Ready for roadmap: yes*
