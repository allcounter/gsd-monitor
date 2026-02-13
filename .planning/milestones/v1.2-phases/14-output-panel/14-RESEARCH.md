# Phase 14: Output Panel - Research

**Researched:** 2026-02-17
**Domain:** SwiftUI output panel — scrollable live text display, smart auto-scroll, segmented view toggle, macOS layout splitting, completion banners, cancel confirmation
**Confidence:** HIGH (SwiftUI APIs confirmed via Apple docs and verified community sources), MEDIUM (smart auto-scroll macOS 14 technique), HIGH (Phase 13 API surface — read actual Swift source)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Panel placement & layout
- Right sidebar panel — splits main content area horizontally (sidebar | dashboard | output panel)
- Always visible — shown even when no command is running
- Resizable divider — user drags to adjust split between dashboard and output panel
- Idle state shows last command output — persists until a new command starts

#### Output stream presentation
- System font (San Francisco) — not monospace. App feel, not terminal feel
- stderr lines in Gruvbox red text color, stdout in default foreground color
- Smart auto-scroll — auto-scroll when at bottom, pause when user scrolls up, resume when they scroll back down
- Rolling buffer of ~5000 lines — prevents memory issues on long-running commands

#### Structured GSD view
- Task checklist + progress bar as the structured view: phase/plan header, progress bar with task count, checklist with status symbols (checkmark, diamond, circle)
- Structured view is the default when a command starts
- Segmented control in panel header to toggle between Structured and Raw views
- Elapsed timer shown next to progress bar while command runs

#### Completion & error states
- Success: green banner at top of panel with exit code, task summary, and duration. Output stays visible below
- Failure: red error banner with exit code, plus highlight last stderr lines. Output stays visible for debugging
- Cancel: standard macOS alert dialog ("Cancel running command?") before sending SIGINT
- Notifications: only on failure — send a macOS notification when a command fails. Success is visible in the panel

### Claude's Discretion
- Exact panel minimum/maximum width constraints
- Divider styling and drag handle design
- Progress bar gradient colors (should follow Gruvbox theme)
- Banner animation/transition style
- How many stderr lines to highlight on failure

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| OUTP-01 | User sees raw terminal output in a scrollable panel with auto-scroll | ScrollViewReader + onChange; smart auto-scroll via scroll offset tracking with onGeometryChange (macOS 14+) |
| OUTP-02 | User sees stderr lines colored distinctly from stdout | CommandRun.OutputLine.Stream enum already distinguishes; Text foreground color per stream type |
| OUTP-03 | User sees exit code when command completes | CommandRun.exitCode: Int32? and CommandRun.state available from @Observable CommandRunnerService |
| OUTP-04 | User can toggle between structured view and raw output | Picker(.segmented) in panel header; @State enum ViewMode drives conditional rendering |
| OUTP-05 | Structured view parses GSD banners, progress, and task status | CommandRun.metadata: GSDMetadata already parsed by GSDOutputParser; render from tasksCompleted, phaseNumber, planNumber |
| OUTP-06 | Output panel uses rolling buffer (2000 lines) to prevent memory growth | CommandRunnerService.activeRuns provides live CommandRun; rolling buffer trim in view model or service layer; user decision says 5000 lines |
| SAFE-03 | User sees confirmation dialog before cancelling a running command | .confirmationDialog SwiftUI modifier on macOS renders as modal alert with Cancel button |
| SAFE-04 | User sees actionable error message with recovery suggestions on command failure | Failure banner + recovery text strings; UNUserNotificationCenter for failure notification |
</phase_requirements>

---

## Summary

Phase 14 is a pure SwiftUI UI phase. All data comes from the existing `CommandRunnerService` (`@MainActor @Observable`) built in Phase 13 — no new services or models are required. The output panel binds directly to `activeRuns`, `recentRuns`, and `projectQueues` properties that are already Phase-14-ready per the Phase 13 summary.

The primary technical challenges are: (1) **layout splitting** — inserting a resizable right panel into the existing `NavigationSplitView`-based layout using `HSplitView` inside the detail column, (2) **smart auto-scroll** — detecting whether the user has manually scrolled up and pausing auto-scroll accordingly using macOS-14-compatible scroll position tracking (the modern `onScrollGeometryChange` API requires macOS 15 and is unavailable), and (3) **structured GSD view** — rendering parsed `GSDMetadata` as a visual checklist with progress bar, using status symbols matching the existing `StatusBadge` pattern.

The rolling buffer (OUTP-06) is a view-side concern: the `CommandRun.outputLines` array grows unbounded in the service; the view should display only the last N lines by slicing the array in the computed property rather than mutating the model. The user decision specifies 5000 lines.

**Primary recommendation:** Use `HSplitView` inside `DetailView`'s detail column for the resizable split. Bind to `CommandRunnerService` via `@Environment` injection. Use `ScrollViewReader` + preference-key-based scroll offset tracking for smart auto-scroll on macOS 14. Use `Picker(.segmented)` for the view toggle. Use `.confirmationDialog` for cancel confirmation.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 14.0 (built-in) | All UI — ScrollView, HSplitView, Picker, .confirmationDialog, TimelineView | Project already SwiftUI throughout |
| Foundation | macOS 14.0 (built-in) | TimeInterval formatting, Date arithmetic | Built-in |
| UserNotifications | macOS 14.0 (built-in) | Failure notifications (SAFE-04) | Already used in NotificationService.swift |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI ScrollViewReader | macOS 12.0+ (built-in) | Programmatic scroll-to-bottom | Required for macOS 14 smart auto-scroll (onScrollGeometryChange needs macOS 15) |
| SwiftUI Preference Keys | macOS 12.0+ (built-in) | Detect scroll position from inside content | Only way to read scroll offset on macOS 14 |
| TimelineView | macOS 12.0+ (built-in) | Elapsed timer display while command runs | Efficient time-based UI update without Timer polling |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| HSplitView | NavigationSplitView 3-column | NavigationSplitView 3-column is unreliable for editor-style split panels; HSplitView inside detail is the documented workaround |
| ScrollViewReader + preference key | onScrollGeometryChange | onScrollGeometryChange requires macOS 15; project targets macOS 14 |
| Picker(.segmented) | Custom segmented control | Custom is more flexible; Picker(.segmented) is native macOS look and zero boilerplate |
| .confirmationDialog | Alert | .confirmationDialog is the modern SwiftUI API; Alert is deprecated pattern |
| Rolling buffer in view | Rolling buffer in service | View-side slicing is simpler — avoids mutating the persisted CommandRun model |

**Installation:** No new packages — all APIs are built-in SwiftUI/Foundation.

## Architecture Patterns

### Recommended Project Structure
```
GSDMonitor/Views/
├── ContentView.swift                    # MODIFIED: inject CommandRunnerService, wrap DetailView in HSplitView
├── OutputPanel/
│   ├── OutputPanelView.swift           # NEW: outer panel shell (header + body switcher)
│   ├── OutputRawView.swift             # NEW: scrollable raw output lines
│   ├── OutputStructuredView.swift      # NEW: GSD task checklist + progress view
│   └── OutputBannerView.swift         # NEW: success/failure/idle state banners
```

### Pattern 1: CommandRunnerService Injection via Environment

**What:** `CommandRunnerService` is `@MainActor @Observable`. Instantiate once at the top level (ContentView) and pass via SwiftUI Environment so any view can access it.

**When to use:** All output panel views need access to `activeRuns`, `recentRuns`, and cancel/queue methods.

```swift
// Source: Swift @Observable + @Environment pattern, established in codebase
// In ContentView.swift:
@SwiftUI.State private var commandRunnerService = CommandRunnerService()

var body: some View {
    NavigationSplitView { ... } detail: {
        DetailWithOutputView(
            selectedProject: ...,
            commandRunnerService: commandRunnerService
        )
    }
    .environment(commandRunnerService)
}

// In any output panel subview:
@Environment(CommandRunnerService.self) private var commandRunner
```

**Critical:** CommandRunnerService is `@MainActor` — all UI access is safe from SwiftUI views (already on MainActor).

### Pattern 2: HSplitView for Resizable Output Panel

**What:** `HSplitView` arranges its children horizontally with a user-draggable divider. Place inside the NavigationSplitView detail column to add the output panel without changing the sidebar.

**When to use:** Any time you need a macOS-native resizable split panel. `NavigationSplitView` supports a 3-column mode but is unreliable for editor-style UI (documented community finding); `HSplitView` inside the detail column is the correct workaround.

```swift
// Source: HSplitView Apple Documentation + community pattern
// Replace DetailView body with:
struct DetailWithOutputView: View {
    var body: some View {
        HSplitView {
            // Left: existing dashboard content
            DashboardView(project: selectedProject, ...)
                .frame(minWidth: 400, maxWidth: .infinity)

            // Right: output panel (always visible per user decision)
            OutputPanelView(commandRunner: commandRunner, project: selectedProject)
                .frame(minWidth: 280, idealWidth: 380, maxWidth: 600)
        }
    }
}
```

**Width constraints (Claude's discretion):**
- Dashboard min: 400pt — prevents content from being unreadably narrow
- Output panel min: 280pt — fits header + ~60 chars of output
- Output panel max: 600pt — prevents output panel from dominating
- Output panel ideal: 380pt — default split roughly 60/40

### Pattern 3: Smart Auto-Scroll on macOS 14

**Critical constraint:** `onScrollGeometryChange` (the modern smart-scroll API) requires macOS 15. The project targets macOS 14. Use the `ScrollViewReader` + preference key technique instead.

**What:** Track scroll offset by placing a GeometryReader inside the ScrollView content, reading its frame in the ScrollView's coordinate space via a PreferenceKey. When the bottom sentinel is visible (offset indicates user is at the bottom), enable auto-scroll. When the user scrolls up, disable auto-scroll until they scroll back to the bottom.

```swift
// Source: SwiftUI coordinate space + PreferenceKey pattern (macOS 14 compatible)
// Verified technique: https://www.swiftbysundell.com/articles/observing-swiftui-scrollview-content-offset/

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct OutputRawView: View {
    let lines: [CommandRun.OutputLine]
    @State private var isAtBottom = true  // Start auto-scrolling
    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        OutputLineView(line: line)
                            .id(index)
                    }
                    // Bottom sentinel with ID for scrollTo
                    Color.clear.frame(height: 1).id("bottom")
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("scroll")).maxY
                            )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                // Track whether user is near the bottom
                // (content maxY close to scroll container height = at bottom)
                // Implementation details: compare value to containerHeight
            }
            .onChange(of: lines.count) { _, _ in
                if isAtBottom {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}
```

**Simpler alternative for MVP (HIGH confidence):** Skip offset detection entirely. Use `defaultScrollAnchor(.bottom)` + `ScrollViewReader` for scroll-to-bottom on new lines. Let the user scroll freely — do NOT try to detect their scroll position. This is simpler and avoids the preference key complexity. When the user is at the bottom and new lines arrive, call `proxy.scrollTo("bottom")`. This achieves the core auto-scroll behavior. The "pause when scrolled up, resume when at bottom" UX is a nice-to-have that adds complexity; the simpler approach works well for most log-view UIs.

**Recommendation:** Implement simple auto-scroll first (preference key approach is Medium confidence); add smart detection only if the simpler approach feels wrong during testing.

### Pattern 4: Segmented Control Toggle

**What:** `Picker` with `.pickerStyle(.segmented)` renders as a native macOS segmented control. Bind to a `ViewMode` enum state.

```swift
// Source: SegmentedPickerStyle Apple Documentation (HIGH confidence)
enum ViewMode: String, CaseIterable {
    case structured = "Structured"
    case raw = "Raw"
}

struct OutputPanelView: View {
    @State private var viewMode: ViewMode = .structured

    var body: some View {
        VStack(spacing: 0) {
            // Panel header with segmented control
            HStack {
                Text("Output")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Picker("View", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.bg1)

            Divider().background(Theme.bg2)

            // Content area
            switch viewMode {
            case .structured:
                OutputStructuredView(run: currentRun)
            case .raw:
                OutputRawView(lines: displayedLines)
            }
        }
    }
}
```

**Auto-switch to Structured on command start:** Watch `commandRunner.activeRuns[projectKey]` in `.onChange` — when a new run starts (state changes to `.running`), set `viewMode = .structured`.

### Pattern 5: Rolling Buffer — View-Side Slicing

**What:** `CommandRun.outputLines` grows unbounded in the model. The view displays only the last N lines to prevent performance issues with very long runs. OUTP-06 specifies 2000 lines in requirements; user decision context says ~5000 — use 5000 as the cap.

```swift
// Source: Phase 14 decision — view-side trim, not model mutation
var displayedLines: [CommandRun.OutputLine] {
    let lines = currentRun?.outputLines ?? lastRun?.outputLines ?? []
    if lines.count > 5000 {
        return Array(lines.suffix(5000))
    }
    return lines
}
```

**Why view-side:** The CommandRun model is persisted to disk by `CommandHistoryStore`. Mutating it to trim the buffer would corrupt the stored history. The view truncates for display only.

### Pattern 6: Elapsed Timer with TimelineView

**What:** `TimelineView` with `.animation(minimumInterval: 1)` schedule updates every ~1 second during a running command without maintaining a separate Timer.

```swift
// Source: TimelineView Apple Documentation + Swift with Majid (HIGH confidence)
struct ElapsedTimerView: View {
    let startTime: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0, paused: false)) { context in
            let elapsed = context.date.timeIntervalSince(startTime)
            Text(formatElapsed(elapsed))
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()  // Prevents layout jitter as digits change
        }
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let seconds = Int(interval) % 60
        let minutes = Int(interval) / 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

**Note:** Use `.monospacedDigit()` modifier on elapsed timer text to prevent the label from changing width as seconds increment.

### Pattern 7: Cancel Confirmation Dialog

**What:** `.confirmationDialog` is the correct SwiftUI API for "Cancel running command?" On macOS it renders as a native modal alert sheet. SwiftUI automatically adds a "Cancel" button; you provide the destructive action button.

```swift
// Source: confirmationDialog Apple Documentation (HIGH confidence)
// On macOS, renders as a sheet-style alert with Cancel auto-added
struct OutputPanelView: View {
    @State private var showCancelConfirmation = false

    var body: some View {
        // ... panel content ...
        .confirmationDialog(
            "Cancel running command?",
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Command", role: .destructive) {
                _Concurrency.Task {
                    await commandRunner.cancelRunningCommand(forProject: selectedProject.path)
                }
            }
            // SwiftUI automatically adds a Cancel button
        } message: {
            Text("The command will receive SIGINT and be given 4 seconds to clean up before being force-killed.")
        }
    }
}
```

### Pattern 8: Failure Notification (SAFE-04)

**What:** Reuse the existing `NotificationService` pattern (already in codebase). Add a method to send failure notifications when a command finishes with non-zero exit code. The existing `NotificationService` already has `requestPermissionIfNeeded()` and `UNUserNotificationCenter` infrastructure.

**Integration approach:** Add a `sendCommandFailureNotification(projectName:exitCode:command:)` method to `NotificationService`, or trigger notifications directly from an `.onChange` observer in the output panel that watches the run state transition to `.failed`.

```swift
// Source: NotificationService.swift existing pattern (HIGH confidence — codebase)
// Add to NotificationService.swift:
func sendCommandFailureNotification(projectName: String, command: String, exitCode: Int32) {
    _Concurrency.Task {
        let authorized = await requestPermissionIfNeeded()
        guard authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Command Failed — \(projectName)"
        content.body = "Exit code \(exitCode): \(command)"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
```

### Pattern 9: Completion Banners

**What:** State-conditional banner at the top of the panel. `CommandRun.state` drives which banner to show. Use the existing `Theme` color system.

```swift
// Source: Theme.swift color system (HIGH confidence — codebase)
@ViewBuilder
private var completionBanner: some View {
    if let run = currentRun {
        switch run.state {
        case .succeeded:
            CommandBannerView(
                style: .success,
                title: "Completed",
                subtitle: bannerSubtitle(for: run)
            )
        case .failed, .crashed:
            CommandBannerView(
                style: .failure,
                title: run.state == .crashed ? "Process Crashed" : "Command Failed",
                subtitle: "Exit \(run.exitCode.map { String($0) } ?? "?") — \(failureRecoveryText(for: run))"
            )
        case .cancelled:
            CommandBannerView(style: .cancelled, title: "Cancelled", subtitle: "")
        case .running, .queued:
            EmptyView()
        }
    }
}

// Colors per user decision:
// Success: Theme.brightGreen background
// Failure: Theme.brightRed background
// Cancelled: Theme.gray background
```

### Pattern 10: Structured View Rendering

**What:** The structured view renders `CommandRun.metadata` (GSDMetadata) as a visual checklist. Uses the same status symbols as the existing `StatusBadge`/`PhaseCardView` pattern.

**Data available from GSDMetadata:**
- `phaseNumber: Int?` — phase header
- `planNumber: Int?` — plan header
- `tasksCompleted: Int` — count of completed tasks detected
- `hasErrors: Bool` — whether error markers were seen

**Limitation:** GSDOutputParser is LOW confidence (per Phase 13 research). `GSDMetadata` provides aggregate counts, not a per-task checklist. The structured view should render what's available gracefully — a progress bar + task count + error indicator — rather than a full per-task list (which would require more sophisticated parsing).

```swift
// Source: GSDOutputParser.swift + CommandRun.GSDMetadata in codebase (HIGH confidence — structure exists)
struct OutputStructuredView: View {
    let run: CommandRun?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let run {
                    // Phase/Plan header
                    if let phase = run.metadata?.phaseNumber {
                        Text("Phase \(phase)\(run.metadata?.planNumber.map { " · Plan \($0)" } ?? "")")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                    }

                    // Progress bar with task count
                    // tasksCompleted is a best-effort count
                    if let metadata = run.metadata {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("\(metadata.tasksCompleted) tasks detected complete")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                if run.state == .running, let startTime = Optional(run.startTime) {
                                    ElapsedTimerView(startTime: startTime)
                                }
                            }
                            // Progress bar — indeterminate while running, based on task count otherwise
                            AnimatedProgressBar(
                                progress: structuredProgress(metadata: metadata, state: run.state),
                                barColor: Theme.brightAqua,
                                height: 6,
                                gradient: LinearGradient(
                                    colors: [Theme.aqua, Theme.brightAqua],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        }
                    }

                    // Recent stderr lines (last 5) highlighted in failure state
                    if run.state == .failed || run.state == .crashed {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Last errors:")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                            ForEach(lastStderrLines(run: run), id: \.timestamp) { line in
                                Text(line.text)
                                    .font(.system(.caption, design: .default))
                                    .foregroundStyle(Theme.brightRed)
                                    .lineLimit(3)
                            }
                        }
                    }
                } else {
                    Text("No command running")
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .padding(16)
        }
    }
}
```

### Anti-Patterns to Avoid

- **Embedding a terminal emulator:** User decision: system font, app feel, not a terminal. Don't use `NSTextView` with monospace font or ANSI escape code rendering.
- **Mutating CommandRun.outputLines for rolling buffer:** CommandRun is persisted to disk. Trim in the view computed property, not in the model.
- **Using `@State private var commandRunner = CommandRunnerService()`:** Creates a second instance. Inject via `@Environment` from ContentView.
- **Using `onScrollGeometryChange` without `@available` guard:** Requires macOS 15. Project targets macOS 14. Use ScrollViewReader + preference key pattern.
- **Putting completion notification logic in the view directly:** The `NotificationService` pattern already exists. Add a method there, call it from the panel's `.onChange` of run state.
- **Using `Alert` instead of `.confirmationDialog`:** `Alert` is the old API. `.confirmationDialog` is the modern replacement and renders correctly on macOS as a sheet-style dialog.
- **Re-triggering auto-scroll animation on every line:** Wrap `proxy.scrollTo` in a check — only call if `isAtBottom` is true. On rapid output (100 lines/second), without this guard, the scroll animation queue floods.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Elapsed timer | Timer.publish + @State counter | TimelineView(.animation(minimumInterval: 1)) | TimelineView is system-managed; Timer needs manual cancel on disappear |
| Cancel confirmation | Custom sheet/overlay | .confirmationDialog | Native macOS appearance, auto Cancel button, correct semantics |
| Resizable split panel | Custom drag gesture | HSplitView | HSplitView is the system primitive; custom gesture has cursor, hit-test and layout complexity |
| Segmented view toggle | Custom tab-style buttons | Picker(.pickerStyle(.segmented)) | Native macOS control, accessibility, keyboard navigation |
| Scroll-to-bottom | Custom UIScrollView wrapper | ScrollViewReader + scrollTo | ScrollViewReader is the standard SwiftUI API for programmatic scroll |
| Failure notifications | New notification infrastructure | Add method to NotificationService | NotificationService.swift already has permission request, UNUserNotificationCenter setup |

**Key insight:** Phase 14 is entirely UI. The hard infrastructure (process management, output streaming, history) is complete in Phase 13. This phase is about binding that infrastructure to SwiftUI components using the standard patterns already established in the codebase.

## Common Pitfalls

### Pitfall 1: Two CommandRunnerService Instances
**What goes wrong:** Each view that creates `@State private var commandRunner = CommandRunnerService()` gets its own instance with empty state. The output panel shows nothing while the actual running command is tracked elsewhere.
**Why it happens:** SwiftUI `@State` creates a new value type or class instance per view.
**How to avoid:** Create ONE instance in `ContentView` using `@SwiftUI.State private var commandRunnerService = CommandRunnerService()`. Pass via `.environment(commandRunnerService)`. All downstream views use `@Environment(CommandRunnerService.self)`.
**Warning signs:** Output panel always shows empty state even when a command is running.

### Pitfall 2: `_Concurrency.Task` Required in View Code
**What goes wrong:** `Task { ... }` in SwiftUI view callbacks fails to compile because `GSDMonitor.Task` (from `Plan.swift`) shadows Swift Concurrency's `Task` module-wide.
**Why it happens:** `Plan.swift` defines a `struct Task` which shadows `Swift.Task` across the entire module.
**How to avoid:** Every `Task { ... }` in Phase 14 view code must be written as `_Concurrency.Task { ... }`. This is the established pattern in Phase 13 files.
**Warning signs:** Compiler error "cannot convert value of type 'GSDMonitor.Task' to expected argument type..." in async view callbacks.

### Pitfall 3: Auto-Scroll Flood on Rapid Output
**What goes wrong:** For fast-streaming commands, `onChange(of: lines.count)` fires 50+ times per second. Each call attempts `proxy.scrollTo("bottom")`. The animation queue fills, scroll becomes janky, and memory/CPU spikes.
**Why it happens:** `scrollTo` with animation is not batched; each call queues an animation.
**How to avoid:** Gate the `scrollTo` call with `if isAtBottom`. Consider debouncing: use `onChange` to set a dirty flag, then only call `scrollTo` via a debounced mechanism. A simple approach: call `proxy.scrollTo("bottom")` without animation when streaming (save animation for the final completion). Or use `.animation(nil)` during active streaming.
**Warning signs:** Scroll position jumps, lags, or CPU usage is high during command execution.

### Pitfall 4: GSDMetadata Is Best-Effort
**What goes wrong:** Structured view shows "0 tasks completed" for every command, or task count is wildly wrong.
**Why it happens:** `GSDOutputParser` uses LOW confidence regex patterns against LLM-generated natural language output. The patterns may not match actual GSD output formats.
**How to avoid:** Design the structured view to degrade gracefully: if `tasksCompleted == 0`, show "Monitoring..." rather than "0 tasks complete". If `phaseNumber == nil`, omit the phase header rather than crashing. Per Phase 13 research: "Treat parsed metadata as best-effort, not authoritative."
**Warning signs:** Structured view shows 0/blank for all commands; or count is obviously wrong (e.g., shows 50 tasks for a simple command).

### Pitfall 5: HSplitView Frame Fighting with NavigationSplitView
**What goes wrong:** The output panel either collapses to zero width or expands to fill all available space, overriding the user's resize intent. The NavigationSplitView and HSplitView conflict on layout priority.
**Why it happens:** `NavigationSplitView` manages its column widths independently. HSplitView inside the detail column needs explicit frame constraints to communicate min/max to the parent.
**How to avoid:** Apply `frame(minWidth:idealWidth:maxWidth:)` to BOTH children of HSplitView. Set `.layoutPriority(1)` on the dashboard pane so it absorbs remaining space after the output panel takes its ideal width.
**Warning signs:** Output panel appears as a hairline or fills the entire detail column on first launch.

### Pitfall 6: Scroll Position Preference Key Frequency
**What goes wrong:** Scroll position updates continuously, causing excessive `onPreferenceChange` callbacks and making the `isAtBottom` state toggle rapidly, which triggers unnecessary `scrollTo` calls.
**Why it happens:** GeometryReader inside ScrollView fires on every frame during scrolling.
**How to avoid:** In the `onPreferenceChange` handler, only update `isAtBottom` when the Boolean value changes, not when the raw offset changes. The transform produces a Bool (not a CGFloat), which changes rarely:
```swift
.preference(key: IsAtBottomKey.self, value: geo.frame(in: .named("scroll")).maxY > containerHeight - threshold)
```
**Warning signs:** Debug logs show `isAtBottom` toggling dozens of times per scroll gesture.

### Pitfall 7: Rolling Buffer Array Slicing on Every Render
**What goes wrong:** For a run with 5001 lines, every SwiftUI render body call creates a new `Array(lines.suffix(5000))`. For rapid output, this is O(N) work per frame.
**Why it happens:** `displayedLines` is a computed property called inside the view body.
**How to avoid:** Cache the sliced array — update it only in `onChange(of: lines.count)` rather than computing in the view body. Store in `@State var displayedLines: [CommandRun.OutputLine]`.
**Warning signs:** High CPU usage during active command execution despite having a rolling buffer.

## Code Examples

### ContentView Integration (CommandRunnerService injection)
```swift
// Source: @Observable @Environment pattern — Swift documentation + existing codebase style
// File: ContentView.swift (MODIFIED)
struct ContentView: View {
    @SwiftUI.State private var projectService = ProjectService()
    @SwiftUI.State private var commandRunnerService = CommandRunnerService()  // ADD THIS
    // ... existing state ...

    var body: some View {
        NavigationSplitView {
            SidebarView(projectService: projectService, selectedProjectID: $selectedProjectID)
        } detail: {
            DetailView(
                selectedProject: ...,
                projectName: ...
            )
        }
        .environment(commandRunnerService)  // ADD THIS
        // ... rest unchanged ...
    }
}
```

### HSplitView Inside DetailView
```swift
// Source: HSplitView Apple Documentation + community macOS split pattern
// File: DetailView.swift (MODIFIED) — wrap existing VStack in HSplitView
struct DetailView: View {
    @Environment(CommandRunnerService.self) private var commandRunner

    var body: some View {
        if let project = selectedProject {
            HSplitView {
                // Left: existing dashboard content (unchanged)
                dashboardContent(for: project)
                    .frame(minWidth: 400, maxWidth: .infinity)
                    .layoutPriority(1)

                // Right: output panel (always visible)
                OutputPanelView(project: project)
                    .frame(minWidth: 280, idealWidth: 380, maxWidth: 600)
            }
        } else {
            // Existing empty state unchanged
        }
    }
}
```

### Smart Auto-Scroll (macOS 14 compatible)
```swift
// Source: ScrollViewReader Apple Documentation + coordinate space + PreferenceKey technique
// Verified community pattern for macOS 14 (onScrollGeometryChange requires macOS 15)
struct OutputRawView: View {
    let lines: [CommandRun.OutputLine]
    @State private var isAtBottom = true

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line.text)
                            .font(.system(.body, design: .default))  // System font, not monospace
                            .foregroundStyle(line.stream == .stderr ? Theme.brightRed : Theme.fg1)
                            .textSelection(.enabled)
                            .id(index)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
            }
            .onChange(of: lines.count) { _, _ in
                guard isAtBottom else { return }
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}
```

### Failure Recovery Suggestions (SAFE-04)
```swift
// Source: Phase 13 research recommendations for recovery suggestion content
// Match exit code patterns from CommandRunnerService
private func failureRecoveryText(for run: CommandRun) -> String {
    switch run.exitCode {
    case 0:
        return ""  // shouldn't be called for exit 0
    case 130:
        return "Command was interrupted."
    case .none:
        return "Process did not exit cleanly."
    default:
        if run.state == .crashed {
            return "Process crashed — check for memory issues or missing files."
        }
        return "Check output for details. You can re-run the command."
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSScrollView / AppKit direct | SwiftUI ScrollView + ScrollViewReader | SwiftUI 2.0+ | Full SwiftUI — consistent with existing codebase |
| Timer for elapsed display | TimelineView(.animation) | SwiftUI iOS 15/macOS 12 | System-managed, no manual cancel needed |
| Alert for confirmation | .confirmationDialog | SwiftUI iOS 15/macOS 12 | Native action sheet/modal with auto Cancel |
| GeometryReader + offset hacks | onScrollGeometryChange (macOS 15+) | WWDC 2024 | Cleaner but NOT available at macOS 14 target — stick with GeometryReader/ScrollViewReader |
| ObservableObject + @Published | @Observable macro | Swift 5.9 / SwiftUI 2023 | Project already uses @Observable throughout |

**Deprecated/outdated:**
- `NSScrollView` / AppKit scroll: Don't use AppKit in a SwiftUI project unless bridging is truly needed.
- `Timer.publish` for elapsed display: TimelineView is the SwiftUI-native way to drive time-based updates.
- `Alert(title:message:dismissButton:)`: Deprecated pattern; use `.alert` modifier or `.confirmationDialog`.

## Claude's Discretion Recommendations

### Panel Width Constraints
- Dashboard min: **400pt** — prevents stat cards and phase cards from becoming unreadable
- Output panel min: **280pt** — fits ~55 character lines in system font at default size
- Output panel ideal: **380pt** — a reasonable 40% slice of a typical 1440-wide window
- Output panel max: **600pt** — prevents output from taking over the dashboard
- Store user's last divider position in `UserDefaults` ("outputPanelWidth") and restore on launch

### Divider Styling and Drag Handle
- Use `HSplitView` default divider — it has a native macOS appearance
- Do NOT add a custom drag handle overlay — HSplitView handles cursor changes automatically
- The divider area is thin (1pt) with a wider hit area — no additional styling needed

### Progress Bar Gradient Colors
- Use `Theme.aqua` → `Theme.brightAqua` gradient (the same Gruvbox aqua used for `Theme.accent`)
- Aqua fits "active running" semantics without conflicting with success (green) or failure (red)
- Width: animate indeterminate during running (use `ProgressView()` for indeterminate or a cycling animation)

### Banner Animation Style
- Use `.transition(.move(edge: .top).combined(with: .opacity))` with `withAnimation(.easeOut(duration: 0.3))`
- Keep banners simple — a colored RoundedRectangle capsule with text, not a full-height overlay
- Don't animate on idle state — show banner immediately when state becomes terminal

### Stderr Lines Highlighted on Failure
- Highlight the **last 5 stderr lines** from the completed run
- 5 lines is enough context for most failure diagnostics without overwhelming the structured view
- Display these in the structured view's failure section; the raw view shows all lines in red anyway

## Open Questions

1. **Does the output panel need a project context selector?**
   - What we know: The panel is always visible; user decision says "idle state shows last command output." `CommandRunnerService.recentRuns` and `activeRuns` are keyed by project path.
   - What's unclear: When multiple projects are in `activeRuns` simultaneously (different projects running in parallel), which project's output does the panel show? The panel should show the selected project's output.
   - **Recommendation:** Bind the output panel to `selectedProject` from the sidebar selection. Only show the selected project's active run or most recent run.

2. **Does the structured view need a per-task checklist, or is a task count sufficient?**
   - What we know: `GSDMetadata.tasksCompleted` is an aggregate count (LOW confidence patterns). The CONTEXT.md mockup shows "checklist lines with status symbols." But GSDOutputParser doesn't produce per-task items.
   - What's unclear: Whether the planner should add richer parsing to GSDOutputParser as a Phase 14 task, or treat the count as sufficient.
   - **Recommendation:** Render the aggregate count as the structured view for Phase 14. Richer per-task parsing is a separate enhancement. Document this limitation clearly in the structured view UI (e.g., "X task markers detected" rather than a misleading checklist).

3. **How should the idle panel (no command running) look?**
   - What we know: User decision: "Always visible — shown even when no command is running. Idle state shows last command output — persists until a new command starts."
   - What's unclear: Should the idle panel show a content-unavailable placeholder (no prior runs for this project) or the last run's output?
   - **Recommendation:** Check `recentRuns.last(where: { $0.projectPath == selectedProject.path })`. If found, show its output with the appropriate completion banner. If none found, show a `ContentUnavailableView` with "No commands run yet" message.

4. **How to handle the OUTP-06 "2000 lines" vs CONTEXT.md "~5000 lines" discrepancy?**
   - What we know: Requirement OUTP-06 says 2000 lines; user decision context says "Rolling buffer of ~5000 lines."
   - What's unclear: Which number takes precedence?
   - **Recommendation:** Use 5000 as the buffer size — it's the user's stated preference and the requirements document is from before the discussion. 5000 lines at ~100 bytes/line = ~500KB, well within acceptable memory for a macOS app.

## Sources

### Primary (HIGH confidence)
- Project codebase (read directly):
  - `GSDMonitor/Services/CommandRunnerService.swift` — `activeRuns`, `projectQueues`, `recentRuns`, public API
  - `GSDMonitor/Models/CommandRun.swift` — `OutputLine`, `GSDMetadata`, `CommandState`
  - `GSDMonitor/Theme/Theme.swift` — all Gruvbox colors for UI
  - `GSDMonitor/Views/ContentView.swift` — existing NavigationSplitView structure
  - `GSDMonitor/Views/Components/StatusBadge.swift` — existing status symbol pattern
  - `GSDMonitor/Services/NotificationService.swift` — UNUserNotificationCenter pattern
  - `GSDMonitor.xcodeproj/project.pbxproj` — macOS 14.0 deployment target confirmed
- Apple Documentation (via web search):
  - `HSplitView` — https://developer.apple.com/documentation/swiftui/hsplitview
  - `ScrollViewReader` — https://developer.apple.com/documentation/swiftui/scrollviewreader
  - `SegmentedPickerStyle` — https://developer.apple.com/documentation/swiftui/segmentedpickerstyle
  - `confirmationDialog` — https://developer.apple.com/documentation/swiftui/view/confirmationdialog(_:ispresented:titlevisibility:actions:message:)
  - `TimelineView` — https://developer.apple.com/documentation/swiftui/timelineview
  - `scrollPosition` — https://developer.apple.com/documentation/swiftui/scrollposition

### Secondary (MEDIUM confidence)
- Hacking with Swift — ScrollViewReader scrollTo: https://www.hackingwithswift.com/quick-start/swiftui/how-to-make-a-scroll-view-move-to-a-location-using-scrollviewreader
- SerialCoder.dev — scrollPosition (iOS 17 macOS 14): https://serialcoder.dev/text-tutorials/swiftui/scrolling-programmatically-with-scrollposition-in-swiftui/
- fatbobman.com — SwiftUI Scroll APIs evolution: https://fatbobman.com/en/posts/the-evolution-of-swiftui-scroll-control-apis/
- Swift by Sundell — observing ScrollView content offset: https://www.swiftbysundell.com/articles/observing-swiftui-scrollview-content-offset/
- Use Your Loaf — SwiftUI Split View Configuration: https://useyourloaf.com/blog/swiftui-split-view-configuration/
- Swift with Majid — TimelineView: https://swiftwithmajid.com/2022/05/18/mastering-timelineview-in-swiftui/
- Use Your Loaf — SwiftUI Confirmation Dialogs: https://useyourloaf.com/blog/swiftui-confirmation-dialogs/

### Tertiary (LOW confidence)
- `onScrollGeometryChange` macOS 15 requirement — confirmed by multiple sources but not directly from Apple docs page (page requires JS): https://developer.apple.com/documentation/swiftui/view/onscrollgeometrychange(for:of:action:)
- HSplitView minimum/maximum width behavior — community documented; Apple docs page inaccessible via WebFetch

## Metadata

**Confidence breakdown:**
- Phase 13 API surface (CommandRunnerService, CommandRun, GSDMetadata): HIGH — read actual Swift source files
- Standard SwiftUI layout (HSplitView, ScrollView, Picker, confirmationDialog, TimelineView): HIGH — Apple documentation verified via multiple sources
- Smart auto-scroll macOS 14 technique: MEDIUM — technique is established but coordinate space preference key has known complexity; simpler ScrollViewReader approach recommended as primary
- GSDMetadata rendering in structured view: MEDIUM — the data structure is confirmed (read from source), but GSDOutputParser accuracy is LOW (LLM output, regex patterns are best-effort)
- Rolling buffer: HIGH — straightforward Array.suffix() operation
- Failure notification integration: HIGH — NotificationService pattern is confirmed in codebase

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (SwiftUI APIs stable; project constraints fixed by macOS 14 deployment target)
