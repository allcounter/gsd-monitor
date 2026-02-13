# Feature Research: Embedded GSD Command Runner

**Domain:** Embedded task/command runner in native macOS SwiftUI app
**Researched:** 2026-02-17
**Confidence:** MEDIUM-HIGH

## Context

This research targets **v1.2 features only** — an embedded GSD command runner added to the existing GSD Monitor app. The app already has multi-project sidebar, phase cards, plan detail views, file watching, notifications, editor integration, command palette (navigation), and full Gruvbox Dark theme.

The new capability: trigger GSD CLI slash commands (`/gsd:quick`, `/gsd:plan-phase`, etc.) from within the app, watch them run for 10+ minutes, and view structured output — without ever leaving the app to a terminal.

**Commands run via:** `claude --dangerously-skip-permissions -p "/gsd:quick <description>"` (or similar GSD invocation pattern) in the project's working directory.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features a developer using an embedded command runner expects to exist. Missing any of these makes the runner feel incomplete or unsafe.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Live streaming output | Commands take 10+ minutes; users need to see what's happening or they'll think the app hung | HIGH | `Process` + `AsyncThrowingStream` on background thread. Pipe stdout/stderr line-by-line to SwiftUI state on main actor. |
| Running / stopped state indicator | Users must know at a glance if a command is in progress. Critical for long-running jobs. | LOW | Bool `isRunning` state drives spinner + button state. SwiftUI `ProgressView` with `.circular` style in toolbar. |
| Cancel / kill running command | Long-running commands must be stoppable. Users will need to abort bad runs. | MEDIUM | `process.terminate()` (SIGTERM). If process doesn't exit in ~3s, follow with `process.interrupt()` (SIGKILL via interrupt). Show confirmation only for runs > 30 seconds. |
| Clear output | Output log fills up; users need to wipe it between runs | LOW | Button clears `outputLines: [String]`. Only enabled when not running. |
| Exit code / success or failure indication | Users need to know if the command succeeded without reading all output | LOW | Check `process.terminationStatus`. Show green checkmark or red X in panel header after completion. |
| Scroll-to-bottom with auto-scroll | New output always visible as it streams in. User can scroll up to read history without losing auto-scroll context. | MEDIUM | `ScrollViewReader` + `onChange` on outputLines. Pause auto-scroll when user scrolls up; resume when user scrolls to bottom. |
| Errors on stderr distinguished from stdout | Claude CLI and GSD tools write errors to stderr; must be visually distinct | MEDIUM | Separate `stdoutLines` and `stderrLines`. In raw view, stderr lines shown in red (Gruvbox red). In structured view, errors shown in dedicated section. |
| Working directory per project | GSD commands must run in the project directory, not the app's cwd | LOW | Pass project path as `currentDirectoryURL` to `Process`. Already have `project.path` in model. |
| Output panel togglable | Panel should not consume screen space when not in use | LOW | Collapsible bottom panel or popover. State persisted across sessions via UserDefaults. |

### Differentiators (Competitive Advantage)

Features that make this runner better than "just open a terminal." These justify why the runner exists in the app at all.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Structured output view | Parse GSD/Claude output to show tasks, status icons, and phase progress instead of raw text — transforming a wall of terminal noise into an actionable summary | HIGH | Regex/string parsing on output lines. Detect "GSD COMPLETE", task check/cross markers, phase names. Toggle between structured and raw. |
| Context-triggered commands | "Run plan-phase for Phase 3" button directly on a phase card — zero typing, zero context switching | MEDIUM | `CommandAction` enum with associated project + phase data. Phase card and plan card show action buttons contextually. Buttons only appear for eligible phases/plans (e.g., not-started phases). |
| Command palette integration | Extend existing Cmd+K palette to list runnable GSD actions alongside navigation results — power users stay on keyboard | MEDIUM | Add `.gsdCommand(CommandAction)` case to existing `CommandResult` enum. Separate "Run GSD" section in palette results. |
| Command history | Show list of previously run commands with status, timestamp, and quick re-run | MEDIUM | `[CommandRun]` array in `@Observable CommandRunnerService`. Persisted via JSON in UserDefaults or `.planning/` file. |
| Progress parsing from output | Extract and display high-level progress from streaming output (e.g., "Executing task 2/4") before run completes | HIGH | Pattern match streaming output lines for GSD banner patterns. Update structured progress view in real time as output streams. |
| Environment variable passthrough | claude CLI needs PATH, HOME, and shell env to locate tools (node, git, claude) | MEDIUM | `process.environment` must include user's full environment. Derive from `ProcessInfo.processInfo.environment`. Add claude/gsd-specific PATH entries if needed. |
| Per-project run history | Each project tracks its own command run history separately | LOW | Key run history by `project.id`. Displayed in project detail panel. |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Full embedded terminal emulator (PTY/VT100) | "Just show a real terminal" | PTY handling in SwiftUI is a significant undertaking requiring `posix_openpt`, VT100 parsing. ANSI escape codes corrupt SwiftUI `Text` if not stripped. Far exceeds scope. | Pipe stdout/stderr, strip ANSI codes, display in styled `ScrollView`. Offer "Open in Terminal" button for power users who need real TTY. |
| Interactive input / stdin | "I want to respond to prompts" | GSD commands should run non-interactively via `--dangerously-skip-permissions`. Supporting interactive stdin requires PTY + keyboard capture inside the view — massive complexity. | Use `claude --dangerously-skip-permissions` to suppress all prompts. If a command needs input, that's a GSD configuration problem, not a UI problem. |
| Multiple simultaneous commands | "Run quick fix while plan-phase runs" | Process management complexity, output interleaving confusion, competing file system mutations from concurrent GSD agents | Queue commands. Run one at a time per project. Show queued state clearly. This is the correct pattern for GSD's agent model anyway. |
| Real-time syntax highlighting of output | "Color the output like a terminal" | Full ANSI rendering is complex; partial rendering with missed escape codes is worse than no coloring. Claude CLI output uses ANSI codes that must be stripped before display. | Strip all ANSI codes. Use semantic structure (task lines, error lines, headers) with Gruvbox color coding instead of raw ANSI passthrough. |
| Command scheduling / cron | "Run GSD check every night" | Out of scope for a monitoring app. Requires background agent, macOS launchd integration, credential management. | Not in v1.2. Note in backlog. |
| Output search | "Find this string in the 5000-line output" | Rare need for 10-minute GSD runs. Adds complexity for marginal value. | Use "Open in Terminal" escape hatch for power users with complex needs. |

---

## Feature Dependencies

```
CommandRunnerService (new @Observable service)
    └──required by──> All runner features below
                          ├──> OutputPanel (view, new)
                          ├──> CommandHistory (model, new)
                          └──> CommandAction (model, new)

Process + AsyncThrowingStream (live streaming)
    └──required by──> OutputPanel (live output)
                          └──required by──> StructuredOutputView (parsed view)
                                               └──requires──> OutputParser (new utility)
                          └──required by──> RawOutputView (terminal-style view)
                          └──required by──> AutoScrollBehavior

Environment variable resolution
    └──required by──> Process launch (claude CLI must find node, git, claude in PATH)
                          └──requires──> Shell environment capture at launch time

CommandAction enum
    └──required by──> PhaseCardView buttons (contextual triggers)
    └──required by──> PlanCard buttons (contextual triggers)
    └──required by──> CommandPaletteView (new GSD command section)
    └──required by──> CommandHistory (what was run)

CommandPalette extension
    └──enhances──> CommandRunnerService (command palette triggers runner)
    └──depends on──> CommandAction enum

CommandHistory
    └──enhances──> CommandRunnerService (records runs)
    └──optional for MVP──> Can defer to v1.2.x
```

### Dependency Notes

- **CommandRunnerService is the foundation** — Must exist before any UI features can be built. It wraps `Process`, manages state, and publishes output via `@Observable`.
- **Environment resolution is blocking** — Claude CLI will fail silently or with "command not found" if the PATH doesn't include Homebrew/nvm/etc. Must be solved before any command runs.
- **Structured output view depends on raw streaming** — Can only parse output after streaming is working. Build raw view first, add parsing layer on top.
- **Context buttons depend on CommandRunnerService and CommandAction** — Phase card UI cannot have run buttons until the service exists.
- **Command palette extension is independent** — Can add after core runner works. Doesn't block other features.
- **Command history is optional for MVP** — Core value is running commands; history is enhancement.

---

## MVP Definition

### Launch With (v1.2 core)

Minimum set to validate the concept: "Run GSD from the app."

- [ ] **CommandRunnerService** — `@Observable` service that launches a Process, streams stdout/stderr line-by-line, tracks running state, exit code, supports cancel. Foundation for everything else.
- [ ] **Environment variable resolution** — Correctly capture shell env (PATH, HOME, etc.) so claude CLI can find node, git, claude. Without this, nothing works.
- [ ] **OutputPanel view (raw mode)** — Scrollable log of output lines. Auto-scrolls. stderr lines in Gruvbox red. Running indicator in panel header. Cancel button. Clear button. Exit code shown on completion.
- [ ] **Context run button on PhaseCardView** — "Run `/gsd:quick`" button on phase cards in actionable states (in-progress). Triggers CommandRunnerService with correct working directory.
- [ ] **ANSI escape code stripping** — Strip `\x1b[...m` and other escape sequences before display. Required for readable output in non-TTY view.

### Add After Validation (v1.2.x)

- [ ] **Structured output view + toggle** — Parse GSD banners, task lines, and status markers. Toggle between structured and raw. Trigger: raw output is too noisy for users to read quickly.
- [ ] **Command palette integration** — Add GSD actions to existing Cmd+K palette. Trigger: users request keyboard-first workflow.
- [ ] **Command history** — Last N runs with status/timestamp. Trigger: users want to re-run previous commands or audit what ran.
- [ ] **Plan-level run buttons** — "Execute this plan" on PlanCard inside PhaseDetailView. Trigger: core runner validated.

### Future Consideration (v2+)

- [ ] **Multiple GSD command types in UI** — `/gsd:plan-phase`, `/gsd:verify-work`, `/gsd:complete-milestone` as selectable actions. Trigger: quick command validated and users want more.
- [ ] **Output export** — Save run log as text file. Trigger: user feedback.
- [ ] **Notification on completion** — Extend existing NotificationService to fire when long-running command finishes. Trigger: users leave app during 10-min runs.
- [ ] **Queued commands** — Line up multiple commands to run sequentially. Trigger: power user feedback.

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| CommandRunnerService (Process + stream) | HIGH | HIGH | P1 (blocking) |
| Environment variable resolution | HIGH | MEDIUM | P1 (blocking) |
| OutputPanel with raw streaming | HIGH | MEDIUM | P1 |
| ANSI escape code stripping | HIGH | LOW | P1 |
| Running state indicator + cancel | HIGH | LOW | P1 |
| Auto-scroll with pause-on-scroll-up | MEDIUM | MEDIUM | P1 |
| Context run buttons on PhaseCardView | HIGH | LOW | P1 |
| Structured output view | MEDIUM | HIGH | P2 |
| Structured/raw toggle | MEDIUM | LOW | P2 |
| Command palette GSD section | MEDIUM | MEDIUM | P2 |
| stderr visual distinction | MEDIUM | LOW | P1 |
| Exit code / success indicator | HIGH | LOW | P1 |
| Command history | LOW | MEDIUM | P2 |
| Plan-level run buttons | MEDIUM | LOW | P2 |
| Completion notifications | MEDIUM | LOW | P3 |
| Output export | LOW | LOW | P3 |
| Queued commands | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for v1.2 launch
- P2: Should have, add in v1.2.x iteration
- P3: Nice to have, future milestone

---

## UX Pattern Analysis

### Output Panel Placement (MEDIUM confidence — based on VS Code, IntelliJ patterns)

**Where to show output:**
- **Bottom panel (VS Code pattern):** Collapsible panel at bottom of main content area. Standard for IDE task runners. Familiar to developers.
- **Inline popover on phase card (option):** Output appears next to the card that triggered it. More contextual, less familiar.
- **Floating window (option):** Separate window for output. Good for multitasking but adds window management burden.

**Recommendation:** Bottom panel (or detachable sheet from the ContentView). Fits macOS three-column layout. Collapsible so it doesn't waste space when no command is running. This is what developers expect from tools like Xcode's build log panel and VS Code's terminal panel.

**Panel toolbar controls (from IntelliJ/VS Code analysis):**
1. Command name / description (what's running)
2. Running spinner or success/failure icon
3. Cancel button (while running) / Re-run button (after completion)
4. Clear button (only when not running)
5. Toggle: Structured / Raw
6. Elapsed time counter (while running)

### Live Output Streaming (HIGH confidence — Swift AsyncThrowingStream docs + community patterns)

**Correct pattern for macOS SwiftUI:**

```swift
// CommandRunnerService (conceptual)
@Observable
final class CommandRunnerService {
    var outputLines: [OutputLine] = []
    var isRunning = false
    var exitCode: Int32?
    private var process: Process?

    func run(command: String, in directory: URL) async throws {
        isRunning = true
        outputLines = []
        exitCode = nil

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-l", "-c", command]
        p.currentDirectoryURL = directory
        p.environment = ProcessInfo.processInfo.environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        p.standardOutput = stdoutPipe
        p.standardError = stderrPipe

        try p.run()
        process = p

        // Stream stdout
        Task {
            for try await line in stdoutPipe.fileHandleForReading.lines {
                await MainActor.run {
                    outputLines.append(OutputLine(text: stripANSI(line), stream: .stdout))
                }
            }
        }
        // Stream stderr similarly...

        p.waitUntilExit()
        exitCode = p.terminationStatus
        isRunning = false
    }

    func cancel() {
        process?.terminate()
    }
}
```

**Key decisions:**
- Use `/bin/zsh -l -c` (login shell) to load user's `.zshrc` / `.zprofile`, which ensures PATH includes Homebrew, nvm, claude.
- `ProcessInfo.processInfo.environment` as base environment. The login shell `-l` flag is the critical addition.
- `Pipe.fileHandleForReading.lines` (AsyncSequence) for streaming — available macOS 12+.
- Always call `@MainActor` when updating published state from background.

### ANSI Escape Code Stripping (HIGH confidence — standard approach)

GSD / Claude CLI output contains ANSI codes (`\x1b[0m`, `\x1b[32m`, etc.) for color in terminals. These appear as garbage in a plain `Text` view.

**Stripping regex:**
```swift
func stripANSI(_ string: String) -> String {
    let pattern = #"\x1b\[[0-9;]*[mGKHF]"#
    return string.replacingOccurrences(
        of: pattern,
        with: "",
        options: .regularExpression
    )
}
```

This must run on every line before appending to `outputLines`. Do not display raw ANSI codes. Do not attempt to render ANSI colors — use semantic coloring instead.

### Structured Output Parsing (MEDIUM confidence — based on GSD output patterns observed)

GSD banners follow predictable patterns that can be detected with string matching:

| Pattern | Meaning | Display |
|---------|---------|---------|
| `GSD ► QUICK TASK` | Command started | Section header |
| `━━━━━━━━━━` | Section divider | Visual separator |
| `◆ ` prefix | Phase/step announcement | Step header in yellow |
| `GSD > QUICK TASK COMPLETE` | Command finished | Success banner in green |
| `✓` or `[x]` markers | Task completion | Checkmark icon |
| `Plan created:` | Plan file created | File reference link |
| `Commit:` followed by hash | Git commit made | Monospace commit badge |
| `Error:` / `Failed` | Error condition | Red error block |

Parser approach: line-by-line classification with enum `OutputLineType { case banner, step, success, error, plain }`. Render each type with different styling in structured view.

**Toggle:** Store `showRawOutput: Bool` in `@AppStorage`. Default to structured view if parsing detects GSD format; raw if output is unrecognized.

### Command Cancellation UX (HIGH confidence — IntelliJ patterns + macOS HIG)

**Cancellation flow:**
1. User clicks "Cancel" button in output panel
2. If run < 30 seconds: cancel immediately, no confirmation
3. If run > 30 seconds: show inline confirmation ("Cancel this run? GSD agents may leave partial artifacts.") — not a modal alert, inline button confirmation in panel
4. Send SIGTERM to process group (`kill(-process.processIdentifier, SIGTERM)`)
5. If process still alive after 3 seconds: send SIGKILL
6. Show "Cancelled" status in panel header

**Do not** use a destructive modal dialog that interrupts workflow. Inline confirmation is less disruptive and still safe.

### Context Button Placement on Phase Cards (MEDIUM confidence — pattern from Linear, GitHub Projects)

Phase cards already show status, progress, goal, dependencies. Add a small action button:

- **When to show:** Only on phases where a GSD command makes sense. For `/gsd:quick`: always show on in-progress phases. For `/gsd:plan-phase`: show on not-started phases.
- **Where to show:** Trailing edge of phase card header (right of status badge), as a small icon button (play triangle icon). Hover reveals label "Run GSD Quick".
- **When disabled:** While any command is running for this project (one at a time constraint). Show disabled state (opacity 0.4) not hidden — users should understand the constraint.
- **On tap:** Opens output panel, starts command with phase context pre-filled.

**Do not** show run buttons on `done` phases — confusing and dangerous.

### Command Palette Integration (MEDIUM confidence — based on existing CommandPaletteView analysis)

Current Cmd+K palette searches projects, phases, requirements. Extend with GSD action commands:

**New section in palette results:**
```
[Run GSD] section
  ▶ Run Quick Task in "GSD Monitor"    ⌘↩
  ▶ Plan Phase 4 in "GSD Monitor"
  ▶ Verify Work in "GSD Monitor"
```

**UX rules:**
- GSD commands appear only when a project is selected in sidebar
- GSD commands appear as second section after navigation results
- Selecting a GSD command dismisses palette and opens output panel
- Keyboard shortcut `⌘↩` for the top GSD action (context-sensitive)

**Implementation:** Add `.gsdCommand(CommandAction, project: Project)` case to existing `CommandResult` enum. Handle in `selectResult(_:)` with call to `CommandRunnerService`.

---

## Dependencies on Existing Code

### Code to Modify

| Existing File | Change Required | Complexity |
|---------------|-----------------|------------|
| `ContentView.swift` | Add collapsible output panel at bottom; connect to CommandRunnerService | MEDIUM |
| `PhaseCardView.swift` | Add contextual run button (trailing of status badge); disable when running | LOW |
| `PhaseDetailView.swift` | Add run buttons on plans (PlanCard); open output panel | LOW |
| `CommandPaletteView.swift` | Add GSD command section to results; extend CommandResult enum | MEDIUM |
| `ContentView.swift` | Pass CommandRunnerService as environment object | LOW |

### New Files to Create

| New File | Purpose | Complexity |
|----------|---------|------------|
| `CommandRunnerService.swift` | `@Observable` service: Process management, streaming, state, cancel | HIGH |
| `OutputPanelView.swift` | Panel UI: raw/structured toggle, scroll view, toolbar controls | MEDIUM |
| `StructuredOutputView.swift` | Parsed GSD output with section headers, task rows, status icons | HIGH |
| `OutputParser.swift` | Line-by-line classifier that converts raw output to `ParsedOutputLine` | MEDIUM |
| `CommandAction.swift` | Enum of GSD commands with associated context (project, phase, plan) | LOW |
| `CommandRun.swift` | Model: command, project, timestamp, exit code, line count | LOW |
| `ANSIStripper.swift` | Utility: strip ANSI escape codes from strings | LOW |

### No Changes Required

- `ProjectService.swift` — project model unchanged
- `FileWatcherService.swift` — file watching unchanged; output panel refreshes independently
- `NotificationService.swift` — unchanged for MVP; extend in v1.2.x for completion notifications
- `EditorService.swift` — unchanged
- All models (Project, Phase, Plan, etc.) — data structures unchanged

---

## Competitor / Reference Product Analysis

| Product | Command Trigger | Output UX | Cancel UX | Structured vs Raw |
|---------|----------------|-----------|-----------|-------------------|
| VS Code Tasks | Task panel, Cmd+Shift+P | Bottom panel, auto-scroll, stderr mixed | Trash icon (no confirm for short runs) | Raw only; extensions add structure |
| IntelliJ Run | Run/Debug toolbar, Shift+F10 | Tool window, auto-scroll, stderr in red | Stop (SIGTERM) then Kill (SIGKILL) | Raw; no structured toggle |
| Xcode Build | Cmd+B / toolbar | Build log below; expandable issues pane | Stop button in toolbar | Structured by default (issue navigator) |
| GitHub Actions UI | Push / manual trigger | Log streaming per step, collapsible | Cancel run button (no confirm) | Structured (step sections) + raw log toggle |
| Linear | No embedded runner | N/A | N/A | N/A |

**Key takeaways:**
- Streaming output + auto-scroll is universal expectation
- Stop (soft) then Kill (hard) is the standard cancel pattern
- Structured view (like Xcode issues, GitHub step breakdown) is more valuable than raw for non-terminal users
- Raw toggle is needed for debugging when parsing fails or output is unexpected
- Confirmation on cancel is not standard — only add for long-running (>30s) to prevent accidental abort

---

## Sources

- [VS Code Panel UX Guidelines](https://code.visualstudio.com/api/ux-guidelines/panel) — Panel placement and toolbar patterns
- [IntelliJ Run Tool Window](https://www.jetbrains.com/help/idea/run-tool-window.html) — Stop/Kill, clear, pin tab patterns
- [SwiftToolkit: Running System Processes](https://www.swifttoolkit.dev/posts/command-package) — AsyncStream + Process wrapper pattern
- [TrozWare: Moving from Process to Subprocess](https://troz.net/post/2025/process-subprocess/) — Swift Subprocess vs Process, streaming limitations
- [Hacking with Swift Forums: Continuous update of long shell commands](https://www.hackingwithswift.com/forums/macos/continuous-update-of-long-shell-command-execution/14483) — macOS SwiftUI streaming patterns
- [Lucas F. Costa: UX Patterns for CLI Tools](https://lucasfcosta.com/2022/06/01/ux-patterns-cli-tools.html) — Progress indicators, error formatting, streaming expectations
- [GSD Workflow: quick.md](file://~/.claude/get-shit-done/workflows/quick.md) — GSD output format analysis: banner patterns, task markers, completion signatures
- [Designing Command Palettes — Sam Solomon](https://solomon.io/designing-command-palettes/) — Contextual commands, keyboard navigation, categories

---
*Feature research for: GSD Monitor v1.2 — Embedded GSD Command Runner*
*Researched: 2026-02-17*
