# Phase 15: Command Triggering & Integration - Research

**Researched:** 2026-02-18
**Domain:** SwiftUI macOS — context buttons, command palette, command history view, FSEvents suppression
**Confidence:** HIGH (pure codebase analysis; no external libraries required)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Context buttons
- Appear on both phase cards AND individual plan rows
- Phase cards: smart default button (adapts: "Plan" if unplanned, "Execute" if planned, "Verify" if executed) PLUS a ··· menu for all applicable commands (discuss, plan, execute, verify)
- Plan rows: button executes that specific plan only (not the whole phase)
- Smart default button: filled accent button (Gruvbox-colored) with label — prominent, draws attention
- While a command is running: action button transforms into a red "Cancel" button

#### Command palette (Cmd+K)
- Contains both GSD commands (plan-phase, execute-phase, verify, discuss, etc.) and app actions (refresh, toggle theme, open settings)
- Flat searchable list — type to filter, no category grouping
- Includes a project picker step within the palette — user selects project before running command
- Step-by-step parameter prompting — after picking a command, palette prompts for required params (phase number, plan number, etc.)

#### Command history
- Dedicated history view (separate section/tab), not embedded in the output panel
- Minimal entry display: command name, timestamp, success/fail badge — compact list
- Tapping an entry expands to show full captured output, with a "Re-run" button available
- Retain last 50 command runs per project

#### Running state indicators
- Indicators appear everywhere relevant: sidebar project row, phase card, plan row, and output panel header
- Visual treatment: animated spinner icon + elapsed time counter ("2m 34s")
- Output panel auto-opens whenever any command starts
- FSEvents reloads suppressed during active command runs (existing decision from Phase 13)

### Claude's Discretion
- Exact spinner animation style
- Command palette keyboard navigation details
- History view placement (tab vs sidebar section)
- How parameter prompts flow in the palette UI
- Exact ··· menu items per phase state

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TRIG-01 | User can trigger GSD commands via context buttons on phases and plans | Context buttons added to PhaseCardView and PlanCard; smart default derived from phase state; ··· menu via SwiftUI Menu; CommandRunnerService.enqueue() is the call site |
| TRIG-02 | User sees running state indicator when a command is active | CommandRunnerService.activeRuns[projectPath] is observable; ElapsedTimerView already exists; ProgressView(.circular) for spinner; indicators wired into SidebarView, PhaseCardView, and OutputPanel header |
| TRIG-03 | User can trigger GSD commands via Cmd+K command palette | CommandPaletteView already exists but only searches — needs complete replacement with multi-step flow: command selection → project selection → param prompting → enqueue |
| TRIG-04 | User can view and re-run previous commands from command history | CommandHistoryStore already persists runs; CommandRunnerService.loadHistory() loads per-project; CommandRunnerService.rerun() already exists; need HistoryView UI + trim to 50 |
| SAFE-02 | FSEvents project reload suppressed during active command execution | ProjectService.startMonitoring() uses debounced for-await loop; suppression = check CommandRunnerService.activeRuns before calling reloadProject(); no new infrastructure needed |
</phase_requirements>

---

## Summary

Phase 15 is a pure UI + wiring phase. The backend is completely done (Phases 13 and 14). `CommandRunnerService` already exposes `activeRuns`, `projectQueues`, `recentRuns`, `enqueue()`, `rerun()`, `loadHistory()`, and `cancelRunningCommand()`. `CommandHistoryStore` already persists runs. `ElapsedTimerView` already exists. `ProcessActor`, `ShellEnvironmentService`, and the full execution pipeline are in place.

What Phase 15 adds is the **entry points** — every surface from which a user can start a command — and the **suppression gate** that prevents FSEvents from reloading project state while a command is writing to `.planning/`. None of the five requirements introduce new infrastructure; all five are wiring, new views, and one conditional check.

The highest-risk work is the **command palette redesign**. The existing `CommandPaletteView` is a project/phase/requirement search tool; it needs to become a multi-step GSD command launcher with a project picker step and parameter prompting. The step flow pattern (command → project → params) requires careful state management, but is entirely achievable with SwiftUI `@State` and no external dependencies.

**Primary recommendation:** Implement in three plans: (1) context buttons + running indicators everywhere, (2) command palette redesign, (3) history view + FSEvents suppression.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 14+ (project minimum) | All UI | Already the project stack |
| Observation (`@Observable`) | Swift 5.9+ | Reactive binding to CommandRunnerService | Already used by CommandRunnerService |
| AsyncAlgorithms | Already in project | debounce on FSEvents | Already imported in ProjectService.swift |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ProgressView(.circular)` | Built-in SwiftUI | Spinner for running state | Where spinner is needed in tight spaces (sidebar row, phase card header) |
| `TimelineView` | Built-in SwiftUI | Live elapsed time updates | ElapsedTimerView already uses this; reuse the component |
| `Menu` (SwiftUI) | Built-in SwiftUI | ··· overflow menu on phase cards | Provides native macOS popover menu |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftUI `Menu` | `NSMenu` via `NSPopUpButton` | NSMenu = more control but loses SwiftUI integration; SwiftUI Menu is sufficient for a small command list |
| Re-using existing `CommandPaletteView` shell | Writing a new view from scratch | Reuse the outer frame (600×400 sheet, search field) but replace inner logic entirely |

**Installation:** No new packages required.

---

## Architecture Patterns

### Recommended Project Structure

```
GSDMonitor/
├── Views/
│   ├── CommandPalette/
│   │   └── CommandPaletteView.swift        # Replace inner logic (multi-step flow)
│   ├── History/
│   │   └── CommandHistoryView.swift        # New: dedicated history tab/section
│   ├── Dashboard/
│   │   ├── PhaseCardView.swift             # Add context button + running indicator
│   │   └── PhaseDetailView.swift           # PlanCard gets execute button + running indicator
│   └── SidebarView.swift                   # ProjectRow gets running indicator
└── Services/
    └── ProjectService.swift                # Add SAFE-02 suppression gate
```

### Pattern 1: CommandRunnerService as @Environment Dependency

**What:** `CommandRunnerService` is already injected at `ContentView` level via `.environment(commandRunnerService)`. All downstream views access it via `@Environment(CommandRunnerService.self)`. Phase 15 views follow this pattern — no prop-drilling.

**When to use:** Every view that needs to call `enqueue()`, read `activeRuns`, or read `recentRuns`.

**Example:**
```swift
// Already established in ContentView.swift — no change needed
.environment(commandRunnerService)

// In any downstream view:
@Environment(CommandRunnerService.self) private var commandRunner

// Check if project has active run:
var isRunning: Bool {
    commandRunner.activeRuns[project.path.path] != nil
}

// Trigger a command:
commandRunner.enqueue(CommandRequest(
    command: "claude",
    arguments: ["/gsd:execute-phase", "\(phase.number)"],
    projectPath: project.path,
    projectName: project.name
))
```

### Pattern 2: Smart Default Button Logic (Phase Card)

**What:** The context button label adapts based on phase state — "Plan" if the phase has no plans, "Execute" if plans exist but are not all done, "Verify" if all plans are done. While a command is running for this project, it becomes a red Cancel button.

**When to use:** PhaseCardView primary action button.

**Example:**
```swift
private var smartDefaultAction: (label: String, command: String, args: [String]) {
    let hasPlans = !phasePlans.isEmpty
    let allDone = phasePlans.allSatisfy { $0.status == .done }

    if isRunning {
        // Running state — button becomes Cancel (handled separately)
        return ("Cancel", "", [])
    } else if !hasPlans {
        return ("Plan", "claude", ["/gsd:plan-phase", "\(phase.number)"])
    } else if !allDone {
        return ("Execute", "claude", ["/gsd:execute-phase", "\(phase.number)"])
    } else {
        return ("Verify", "claude", ["/gsd:verify-work", "\(phase.number)"])
    }
}
```

### Pattern 3: Running State Indicator (Spinner + Timer)

**What:** When `commandRunner.activeRuns[project.path.path] != nil`, show `ProgressView(.circular)` + `ElapsedTimerView(startTime: run.startTime)` inline. `ElapsedTimerView` already exists and uses `TimelineView(.animation(minimumInterval: 1.0))`.

**When to use:** SidebarView ProjectRow, PhaseCardView header, PlanCard row, OutputPanel header.

**Example:**
```swift
// Reuse ElapsedTimerView — already in Views/OutputPanel/ElapsedTimerView.swift
if let run = commandRunner.activeRuns[project.path.path] {
    HStack(spacing: 4) {
        ProgressView()
            .scaleEffect(0.6)
            .frame(width: 14, height: 14)
        ElapsedTimerView(startTime: run.startTime)
    }
}
```

### Pattern 4: Output Panel Auto-Open on Command Start

**What:** The output panel (right pane of HSplitView) is already always visible when a project is selected. "Auto-opens" means if the HSplitView pane was collapsed (narrow), it should expand. In practice, the output panel is not collapsible — it always renders. The auto-open behavior translates to: ensure the project is selected and the output panel's `ContentUnavailableView` is replaced by live output, which already happens automatically via `commandRunner.activeRuns` observation.

**Important:** No new mechanism is needed for auto-open since the panel is permanently rendered. The "auto-open" UX is already satisfied by the panel always being visible.

### Pattern 5: Multi-Step Command Palette

**What:** The existing `CommandPaletteView` (a search-for-project tool) needs to become a multi-step GSD command launcher. Use a `@State var step: PaletteStep` enum to track which step the palette is on: `.selectCommand` → `.selectProject` → `.promptParams` → `.confirm`.

**When to use:** When replacing `CommandPaletteView` inner logic.

**Example:**
```swift
enum PaletteStep {
    case selectCommand
    case selectProject(GSDCommand)
    case promptParams(GSDCommand, Project, params: [String: String])
}

@SwiftUI.State private var step: PaletteStep = .selectCommand

// Navigation:
// User picks command → step = .selectProject(command)
// User picks project → step = .promptParams(command, project, [:])
// User fills params → enqueue() + dismiss
```

### Pattern 6: FSEvents Suppression Gate (SAFE-02)

**What:** In `ProjectService.startMonitoring()`, the debounced for-await loop calls `reloadProject(at:)` for every changed path. Suppression = skip the reload if `commandRunner.activeRuns[projectPath] != nil`.

**When to use:** Inside the debounce handler in `ProjectService.startMonitoring()`.

**Implementation:** `ProjectService` needs access to `CommandRunnerService`. Since both are `@MainActor @Observable`, pass `CommandRunnerService` as a dependency to `ProjectService` (via init or stored property) or access it at the call site in `ContentView`. The cleanest approach is to pass `CommandRunnerService` into `ProjectService.startMonitoring()` as a parameter so `ProjectService` doesn't hold a permanent reference.

**Example:**
```swift
// In ProjectService.startMonitoring():
func startMonitoring(commandRunner: CommandRunnerService) {
    let planningPaths = projects.map { $0.path.appendingPathComponent(".planning") }
    guard !planningPaths.isEmpty else { return }

    let eventStream = fileWatcher.watch(paths: planningPaths)
    monitoringTask = _Concurrency.Task {
        for await changedURLs in eventStream.debounce(for: .seconds(1)) {
            var affectedProjects: Set<String> = []
            for url in changedURLs {
                let path = url.path
                if let range = path.range(of: "/.planning") {
                    let projectRoot = String(path[path.startIndex..<range.lowerBound])
                    affectedProjects.insert(projectRoot)
                }
            }

            for projectPath in affectedProjects {
                // SAFE-02: Skip reload if a command is writing to .planning/
                let key = projectPath
                if commandRunner.activeRuns[key] != nil {
                    continue  // Suppressed — will reload after command completes
                }
                await reloadProject(at: URL(fileURLWithPath: projectPath))
            }
        }
    }
}
```

**Reload after suppression:** When a command finishes, the CLI writes final files to `.planning/`, which triggers an FSEvents event. Since `activeRuns` is cleared when the command ends, the next FSEvents event (which the CLI write causes) will pass the suppression gate and trigger a reload. No explicit "reload on completion" hook is needed — FSEvents handles it.

### Pattern 7: Command History View

**What:** A dedicated view showing the last 50 runs for the selected project. Each row shows command name (derived from arguments), timestamp, and success/fail badge. Tapping a row expands to show full output. "Re-run" button calls `commandRunner.rerun(run)`.

**When to use:** As a new tab or separate section in `DetailView` or as a sheet.

**Data source:** `commandRunner.loadHistory(forProject: project.path)` — async, returns `[CommandRun]`.

**Trim to 50:** `CommandHistoryStore` currently retains 200 runs per project. The user decision is 50. The trim constant (`maxRunsPerProject`) needs to change to 50. This is a 1-line change in `CommandHistoryStore.swift`.

**Example:**
```swift
struct CommandHistoryView: View {
    let project: Project
    @Environment(CommandRunnerService.self) private var commandRunner
    @SwiftUI.State private var history: [CommandRun] = []
    @SwiftUI.State private var expandedRunID: UUID?

    var body: some View {
        List(history) { run in
            CommandHistoryRow(
                run: run,
                isExpanded: expandedRunID == run.id,
                onToggle: { expandedRunID = expandedRunID == run.id ? nil : run.id },
                onRerun: { commandRunner.rerun(run) }
            )
        }
        .task {
            history = await commandRunner.loadHistory(forProject: project.path)
        }
    }
}
```

### Anti-Patterns to Avoid

- **Calling `commandRunner.enqueue()` without `@MainActor` context:** `CommandRunnerService` is `@MainActor`. All `enqueue()` calls from SwiftUI views are fine (SwiftUI body is MainActor). Calls from background contexts need `await MainActor.run { }`.
- **Accessing `commandRunner.activeRuns` off-MainActor:** Same — `activeRuns` is MainActor state. Always access from SwiftUI views or `MainActor`-annotated code.
- **Rebuilding command argument strings from phase/plan numbers:** GSD CLI slash commands take the phase slug or number directly. Use `["/gsd:execute-phase", "\(phase.number)"]` — no quotes, no shell escaping needed (Process arguments don't go through a shell).
- **Using `_Concurrency.Task` in views:** Not needed in views — only in Services that are already in a `GSDMonitor.Task`-shadowing context. In view `Button` actions, use `Task { }` directly.
- **Overcomplicating SAFE-02:** Do not add a new mechanism (notification, callback, Combine). A simple `if commandRunner.activeRuns[key] != nil { continue }` check inside the debounce handler is sufficient and correct.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Elapsed timer that updates every second | Custom Timer publisher | `TimelineView(.animation(minimumInterval: 1.0))` via existing `ElapsedTimerView` | Already exists in `Views/OutputPanel/ElapsedTimerView.swift`; reuse it |
| Overflow action menu | Custom popover | SwiftUI `Menu { }` with `Button` items | Native macOS behavior, keyboard accessible, zero boilerplate |
| Spinner animation | Custom ProgressView | `ProgressView()` with `.scaleEffect(0.6)` | Matches macOS spinner exactly |
| Process management | Custom signal sending | `CommandRunnerService.cancelRunningCommand()` | Already implemented with SIGINT + 4s timeout + SIGKILL |
| History persistence | Custom JSON file | `CommandHistoryStore` (already exists) | Already atomic, already trimming, already actor-isolated |
| Command re-running | Build new CommandRequest | `CommandRunnerService.rerun(run)` | Already implemented |

**Key insight:** Phase 15 has zero new infrastructure requirements. Every backend need is already built. The entire phase is UI surfaces + one conditional check.

---

## Common Pitfalls

### Pitfall 1: GSDMonitor.Task Shadowing

**What goes wrong:** Writing `Task { commandRunner.enqueue(...) }` inside a Service file causes a Swift compiler error because `GSDMonitor.Task` (the plan model) shadows `_Concurrency.Task` at module scope.

**Why it happens:** `Plan.swift` defines `struct Task` without namespacing, creating a module-wide name collision.

**How to avoid:** In view files this is NOT an issue — SwiftUI views don't have the same shadowing problem (the model type is accessed as `GSDMonitor.Task` explicitly when needed). The shadowing only affects Services. In views, `Task { }` works as expected.

**Warning signs:** Build error "cannot convert value of type 'GSDMonitor.Task' to..." when using `Task { }` in a Service.

### Pitfall 2: CommandHistoryStore.loadForProject is an Actor Method

**What goes wrong:** Calling `historyStore.loadForProject(projectPath)` without `await` from `CommandRunnerService` fails with Swift 6 actor isolation error.

**Why it happens:** `CommandHistoryStore` is `actor`-isolated. All cross-actor calls require `await`.

**How to avoid:** Always use `try? await historyStore.loadForProject(projectPath)`. This pattern is already established in `CommandRunnerService.swift`.

**Warning signs:** "Actor-isolated instance method cannot be called from outside the actor" compiler error.

### Pitfall 3: Multi-Step Palette State Reset on Dismiss

**What goes wrong:** If the palette sheet is dismissed mid-flow and re-opened, it starts at the last step rather than the initial step.

**Why it happens:** `@SwiftUI.State` in a sheet view persists across presentation if the sheet is not fully deinitialized (SwiftUI reuses view instances).

**How to avoid:** Reset `step = .selectCommand` on `.onAppear { }` in `CommandPaletteView`.

**Warning signs:** Palette opens at `.promptParams` step when user re-opens it.

### Pitfall 4: FSEvents Already Debounced — Don't Double-Debounce

**What goes wrong:** Adding extra debounce in the suppression check path causes missed reloads after command completion.

**Why it happens:** `ProjectService.startMonitoring()` already applies a 1-second debounce via `debounce(for: .seconds(1))`. The CLI final writes will trigger FSEvents after the command ends — the existing debounce covers this.

**How to avoid:** The suppression is a simple `continue` inside the existing debounce handler. Do not add additional delays or buffering.

### Pitfall 5: History View Loads Stale Data

**What goes wrong:** History view loads once on `.task` and does not reflect new runs that complete while the view is open.

**Why it happens:** `commandRunner.loadHistory(forProject:)` loads from disk once. `recentRuns` (the in-memory array) is observable but only holds 20 runs.

**How to avoid:** Either (a) also observe `commandRunner.recentRuns` to detect new completions and trigger a re-load, or (b) reload history on `.onChange(of: commandRunner.recentRuns.count)`. Option (b) is simpler: when `recentRuns` count changes, reload from disk.

### Pitfall 6: CommandHistoryStore maxRunsPerProject = 200, User Decision = 50

**What goes wrong:** History view shows up to 200 entries per project even though the user specified 50.

**Why it happens:** `CommandHistoryStore` was implemented with `maxRunsPerProject = 200` in Phase 13. The user decision in Phase 15 context says "retain last 50 command runs per project".

**How to avoid:** Change `private let maxRunsPerProject: Int = 200` to `50` in `CommandHistoryStore.swift`.

---

## Code Examples

### Context Button on PhaseCardView

```swift
// In PhaseCardView — smart default + cancel toggle
@Environment(CommandRunnerService.self) private var commandRunner

private var isRunning: Bool {
    commandRunner.activeRuns[project.path.path] != nil
}

private var actionButton: some View {
    if isRunning {
        Button("Cancel") {
            _Concurrency.Task {
                await commandRunner.cancelRunningCommand(forProject: project.path)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.brightRed)
    } else {
        let action = smartDefault
        Button(action.label) {
            commandRunner.enqueue(CommandRequest(
                command: "claude",
                arguments: action.args,
                projectPath: project.path,
                projectName: project.name
            ))
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
    }
}
```

### ··· Menu on PhaseCardView

```swift
Menu {
    Button("Discuss") {
        commandRunner.enqueue(CommandRequest(
            command: "claude",
            arguments: ["/gsd:discuss-phase", "\(phase.number)"],
            projectPath: project.path,
            projectName: project.name
        ))
    }
    Button("Plan") {
        commandRunner.enqueue(CommandRequest(
            command: "claude",
            arguments: ["/gsd:plan-phase", "\(phase.number)"],
            projectPath: project.path,
            projectName: project.name
        ))
    }
    // ... execute, verify
} label: {
    Image(systemName: "ellipsis")
        .foregroundStyle(Theme.textSecondary)
}
.menuStyle(.borderlessButton)
.fixedSize()
```

### Plan Row Execute Button (in PlanCard / PhaseDetailView)

```swift
// Execute a specific plan (not the whole phase)
Button("Execute") {
    commandRunner.enqueue(CommandRequest(
        command: "claude",
        arguments: ["/gsd:execute-plan", "\(plan.phaseNumber)", "\(plan.planNumber)"],
        projectPath: project.path,
        projectName: project.name
    ))
}
.buttonStyle(.bordered)
.tint(Theme.accent)
.disabled(commandRunner.activeRuns[project.path.path] != nil)
```

### Running Indicator in Sidebar ProjectRow

```swift
// Add to ProjectRow.body alongside statusSymbol
if let run = commandRunner.activeRuns[project.path.path] {
    HStack(spacing: 4) {
        ProgressView()
            .scaleEffect(0.55)
            .frame(width: 12, height: 12)
        ElapsedTimerView(startTime: run.startTime)
    }
} else {
    Image(systemName: statusSymbol)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(statusColor)
        .font(.system(size: 14))
}
```

### FSEvents Suppression in ProjectService

```swift
// Modified startMonitoring — accept commandRunner parameter
func startMonitoring(commandRunner: CommandRunnerService) {
    let planningPaths = projects.map { $0.path.appendingPathComponent(".planning") }
    guard !planningPaths.isEmpty else { return }

    let eventStream = fileWatcher.watch(paths: planningPaths)
    monitoringTask = _Concurrency.Task {
        for await changedURLs in eventStream.debounce(for: .seconds(1)) {
            var affectedProjects: Set<String> = []
            for url in changedURLs {
                let path = url.path
                if let range = path.range(of: "/.planning") {
                    let projectRoot = String(path[path.startIndex..<range.lowerBound])
                    affectedProjects.insert(projectRoot)
                }
            }
            for projectPath in affectedProjects {
                // SAFE-02: suppress reload while command is actively writing .planning/
                if commandRunner.activeRuns[projectPath] != nil { continue }
                await reloadProject(at: URL(fileURLWithPath: projectPath))
            }
        }
    }
}
```

**Note:** All callers of `startMonitoring()` in `ProjectService` (called from `loadProjects()`, `addProjectManually()`, `removeManualProject()`) need to pass `commandRunner`. Since `ContentView` owns both services, it can pass `commandRunnerService` when calling these — or `ProjectService` can store a weak reference set at init time.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CommandPaletteView as search tool | CommandPaletteView as multi-step command launcher | Phase 15 | Existing view gets gutted and rebuilt internally; outer sheet presentation unchanged |
| No context buttons on phase/plan cards | Smart default button + ··· menu on phase cards; execute button on plan rows | Phase 15 | First user-accessible command trigger surface |
| FSEvents always triggers reload | FSEvents reload skipped while command is active | Phase 15 | Prevents flicker / partial state reads during Claude writes |
| CommandHistoryStore retains 200 runs | 50 runs per project | Phase 15 | Aligns with user decision; one-line change |

**Deprecated/outdated:**
- `CommandPaletteView.CommandResult` enum: The existing `.project`, `.phase`, `.requirement` cases are for the search tool. They become irrelevant if the palette is fully replaced. However, the project/phase search may be preserved as a separate section if the palette needs a "find project" command — keep this enum if reusing project search.

---

## Open Questions

1. **How does `ProjectService` get access to `CommandRunnerService` for SAFE-02?**
   - What we know: Both are created in `ContentView`. `ProjectService.startMonitoring()` is called from `loadProjects()`, which is called inside `.task { }` in `ContentView` — so `commandRunnerService` is in scope.
   - What's unclear: Whether to pass `commandRunnerService` into `startMonitoring()` on each call, or store it once in `ProjectService` via a property.
   - Recommendation: Add `func startMonitoring(commandRunner: CommandRunnerService)` — pass at each call site in `ContentView.task`. This avoids making `ProjectService` hold a permanent reference and keeps the dependency explicit.

2. **History view placement: tab in DetailView or separate sheet?**
   - What we know: User said "dedicated history view (separate section/tab)" — not embedded in output panel.
   - What's unclear: Whether this is a tab in `DetailView` or a sheet triggered by a button.
   - Recommendation: Add a "History" tab to `DetailView` using a `TabView` or `Picker`-based switcher between Dashboard and History. This is the most natural macOS pattern for a sibling view.

3. **GSD CLI argument format for `/gsd:execute-plan`**
   - What we know: The preview in `OutputStructuredView.swift` uses `arguments: ["/gsd:execute-phase", "14-output-panel"]` — showing slug format.
   - What's unclear: Whether `/gsd:execute-plan` takes `"phase-number plan-number"` or just a plan slug.
   - Recommendation: Use phase number and plan number as separate arguments: `["/gsd:execute-plan", "\(plan.phaseNumber)", "\(plan.planNumber)"]`. If the CLI wants a slug, adjust — but number format is safe for now.

4. **Should the ··· menu be disabled while a command is running?**
   - What we know: User said "action button transforms into red Cancel button while running."
   - What's unclear: Whether the ··· overflow menu should also be disabled while a command runs.
   - Recommendation: Yes — disable the ··· menu while `isRunning`, since queuing a second command while one runs is allowed by the queue model, but it's better UX to prevent accidental re-runs. The smart default already transforms to Cancel; the ··· menu should be hidden or disabled.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase reading — all source files in `GSDMonitor/` read in full:
  - `CommandRunnerService.swift` — public API, observable state
  - `CommandHistoryStore.swift` — persistence, `maxRunsPerProject`
  - `CommandRun.swift`, `CommandState.swift` — model types
  - `ProjectService.swift` — `startMonitoring()` implementation
  - `FileWatcherService.swift` — FSEvents setup
  - `CommandPaletteView.swift` — existing palette structure
  - `PhaseCardView.swift`, `PhaseDetailView.swift` — card layouts
  - `DetailView.swift`, `ContentView.swift`, `SidebarView.swift` — navigation hierarchy
  - `OutputPanelView.swift`, `ElapsedTimerView.swift` — existing running state UI
  - `Theme.swift` — Gruvbox color palette
  - `Plan.swift`, `Phase.swift` — model types for smart default logic
- Phase 13 SUMMARY (13-03-SUMMARY.md) — canonical API surface established
- Phase 14 VERIFICATION (14-VERIFICATION.md) — confirmed what is/isn't implemented
- REQUIREMENTS.md — official requirement IDs and status

### Secondary (MEDIUM confidence)
- Phase 15 CONTEXT.md — user decisions (locked constraints)

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, pure SwiftUI patterns already in use
- Architecture: HIGH — all patterns derived from existing codebase; no speculation
- Pitfalls: HIGH — all identified from actual code artifacts (GSDMonitor.Task shadowing documented in Phase 13, loadForProject await documented in Phase 13 SUMMARY)

**Research date:** 2026-02-18
**Valid until:** 2026-03-18 (stable — no external dependencies; valid as long as codebase doesn't change)
