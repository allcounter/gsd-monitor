# Phase 11: Dashboard Stats Cards - Research

**Researched:** 2026-02-17
**Domain:** SwiftUI layout, stat card components, STATE.md parsing extension
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Card content:**
- Show all four metrics: total phases, completion %, active phases, total time spent
- Velocity metric shows total execution time (e.g. "1.8 hrs"), not per-plan average
- Include milestone label (e.g. "v1.1 Visual Overhaul") as section title above the stats grid

**Layout & sizing:**
- Always visible, no collapsible toggle
- Spacious density — large numbers, generous whitespace, stats are a visual focal point

**Visual style:**
- Solid dark surface background (bg1/bg2) matching existing phase card style
- Subtle divider between stats section and scrollable phase cards below

**Placement:**
- Below header, pinned — stats don't scroll away with phase cards
- Milestone name as section title above the stats grid
- Subtle divider separates stats from scrollable phase card area

### Claude's Discretion
- Grid arrangement (single row of 4 vs 2x2 — pick based on available width)
- Card max width vs stretch-to-fill behavior
- Accent color scheme (unique per card or uniform — pick what looks best with Gruvbox)
- Whether to include SF Symbol icons per card
- Count-up animation on first appearance (decide based on complexity vs polish)
- Data scope: current milestone only vs all milestones combined

### Deferred Ideas (OUT OF SCOPE)
- VISL-05: Sparkline graphs in stats cards (velocity over time) — deferred
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DASH-01 | Projekt-header viser stats-kort grid med: total faser, completion %, aktive faser, velocity | All four metrics derivable from existing `Project` model data + STATE.md extension for time; `LazyVGrid` or `HStack` layout in SwiftUI; pinned in `VStack` before `ScrollView` in `DetailView` |
| DASH-02 | Stats-kort bruger Gruvbox-accentfarver og har konsistent layout (ikon + tal + label) | `Theme.*` color constants all available; `VStack(icon + number + label)` pattern; SF Symbols for icons; card background uses `Theme.bg1`/`Theme.bg2` per established pattern |
</phase_requirements>

---

## Summary

Phase 11 adds a stats grid to the pinned header area in `DetailView`, sitting between the existing project title/progress bar and the scrollable phase cards. The grid shows four metrics: total phases, completion %, active phases, and total execution time. Data for three of the four metrics is entirely derivable from the existing `Project` model (roadmap phases + plans). The fourth metric — total execution time — lives in STATE.md as free text ("Total execution time: ~1.8 hours") and is NOT currently parsed into the `State` model. Extending `StateParser` to capture this field is required.

The milestone label ("v1.1 Visual Overhaul") must come from ROADMAP.md content. The ROADMAP.md currently has milestone headers (e.g., `### 🚧 v1.1 Visual Overhaul (In Progress)`) but the `Roadmap` model does not store a milestone name — only `projectName` and `phases`. Either the `RoadmapParser` must be extended to extract the active milestone name, or the milestone label is derived heuristically (e.g., hard-coded lookup from phase range or read from MILESTONES.md). The simplest approach: parse it from STATE.md's "Current focus:" line which already contains the milestone name ("v1.1 Visual Overhaul").

The visual pattern is well-established: solid `bg1`/`bg2` backgrounds, Gruvbox accent colors, SF Symbols with `.hierarchical` rendering. The `hasAppeared` animation pattern from `AnimatedProgressBar` (Phase 7) provides the exact template for count-up or fade-in effects if chosen.

**Primary recommendation:** Build a `StatsCardView` component (ikon + tal + label) in a 4-column `LazyVGrid`, placed inside the pinned `VStack` in `DetailView`. Extend `StateParser` to extract `totalExecutionTime: String?`. Extract milestone name from `State.status` or a new `currentMilestone` field. Use unique Gruvbox accent colors per card (brightBlue, brightYellow, brightAqua, brightOrange) for visual differentiation.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 14+ (already required) | Grid layout, view composition | Already the UI framework for this project |
| Foundation | Already in project | String parsing in StateParser | Already used for all parsing |

### No New Dependencies

This phase requires zero new Swift package dependencies. All functionality is pure SwiftUI + Foundation.

**Installation:** No new packages needed.

---

## Architecture Patterns

### Recommended Project Structure

```
GSDMonitor/Views/
├── Dashboard/
│   ├── PhaseCardView.swift       (existing)
│   ├── PhaseDetailView.swift     (existing)
│   ├── StatsGridView.swift       (NEW — the 4-card grid section)
│   └── StatCardView.swift        (NEW — individual card component)
GSDMonitor/Models/
│   └── State.swift               (extend with totalExecutionTime field)
GSDMonitor/Services/
│   └── StateParser.swift         (extend to parse "Total execution time:" line)
```

### Pattern 1: Stats Grid Layout in DetailView

**What:** A `VStack` section inserted into the pinned header block of `DetailView`, between the existing "Overall Progress" bar and the scrollable `ScrollView`. Uses `LazyVGrid` with 4 equal columns.

**When to use:** Single row of 4 cards when window is wide (typical macOS panel width). LazyVGrid automatically wraps if needed on narrow widths.

**Insertion point in DetailView — current pinned VStack:**
```swift
// DetailView.swift — pinned header VStack (lines 14-59)
VStack(alignment: .leading, spacing: 24) {
    // 1. Project header (existing)
    HStack(alignment: .top) { ... }

    // 2. Overall progress bar (existing)
    if let roadmap = project.roadmap, !roadmap.phases.isEmpty {
        VStack(alignment: .leading, spacing: 8) { ... }
    }

    // 3. NEW: Stats Grid Section (add here, before end of VStack)
    StatsGridView(project: project)
}
.padding()
.background(Theme.bg0)

// Divider (NEW — between pinned header and scroll area)
Divider()
    .background(Theme.bg2)

// Scrollable phases (existing ScrollView)
ScrollView { ... }
```

### Pattern 2: StatsGridView Component

**What:** A self-contained view that takes `Project` and computes all four metrics. Contains milestone label + `LazyVGrid` of 4 `StatCardView`s.

```swift
// GSDMonitor/Views/Dashboard/StatsGridView.swift
import SwiftUI

struct StatsGridView: View {
    let project: Project

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Milestone label
            if let milestoneName = milestoneName {
                Text(milestoneName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }

            // 4-card grid
            LazyVGrid(columns: columns, spacing: 12) {
                StatCardView(
                    icon: "chart.bar.fill",
                    value: "\(totalPhases)",
                    label: "Total Phases",
                    accentColor: Theme.brightBlue
                )
                StatCardView(
                    icon: "percent",
                    value: "\(completionPercent)%",
                    label: "Complete",
                    accentColor: Theme.brightGreen
                )
                StatCardView(
                    icon: "bolt.fill",
                    value: "\(activePhases)",
                    label: "Active",
                    accentColor: Theme.brightYellow
                )
                StatCardView(
                    icon: "clock.fill",
                    value: executionTime,
                    label: "Time Spent",
                    accentColor: Theme.brightOrange
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var totalPhases: Int {
        project.roadmap?.phases.count ?? 0
    }

    private var completionPercent: Int {
        guard let phases = project.roadmap?.phases, !phases.isEmpty else { return 0 }
        let plans = project.plans ?? []
        let contributions = phases.map { phase -> Double in
            if phase.status == .done { return 1.0 }
            let pp = plans.filter { $0.phaseNumber == phase.number }
            guard !pp.isEmpty else { return 0.0 }
            return Double(pp.filter { $0.status == .done }.count) / Double(pp.count)
        }
        return Int((contributions.reduce(0, +) / Double(phases.count)) * 100)
    }

    private var activePhases: Int {
        project.roadmap?.phases.filter { $0.status == .inProgress }.count ?? 0
    }

    private var executionTime: String {
        project.state?.totalExecutionTime ?? "—"
    }

    private var milestoneName: String? {
        // Extracted from State "Current focus:" field or a new parsed field
        project.state?.currentMilestone
    }
}
```

### Pattern 3: StatCardView Component

**What:** Single stat card with icon + large number + label. `bg1` background, rounded corners matching `PhaseCardView` style (cornerRadius 12). Uses `hasAppeared` state for fade-in (same pattern as `AnimatedProgressBar`).

```swift
// GSDMonitor/Views/Dashboard/StatCardView.swift
import SwiftUI

struct StatCardView: View {
    let icon: String
    let value: String
    let label: String
    let accentColor: Color

    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accentColor)
                .font(.system(size: 18))

            // Value (large)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.fg0)

            // Label
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg1)
        .cornerRadius(10)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: hasAppeared)
        .onAppear { hasAppeared = true }
    }
}
```

### Pattern 4: StateParser Extension for totalExecutionTime

**What:** Extend `StateParser` + `State` model to capture the "Total execution time:" line from STATE.md's Performance Metrics section.

**STATE.md field location:**
```
## Performance Metrics

**Velocity:**
- Total plans completed: 26 (18 v1.0 + 8 v1.1)
- Average duration: 3.1 min
- Total execution time: ~1.8 hours
```

**State model extension:**
```swift
// State.swift — add new optional fields
struct State: Codable, Sendable {
    let currentPhase: Int?
    let currentPlan: Int?
    let status: String
    let lastActivity: String?
    let decisions: [String]
    let blockers: [String]
    let totalExecutionTime: String?  // NEW — e.g. "~1.8 hours"
    let currentMilestone: String?    // NEW — e.g. "v1.1 Visual Overhaul"

    enum CodingKeys: String, CodingKey {
        case currentPhase = "current_phase"
        case currentPlan = "current_plan"
        case status
        case lastActivity = "last_activity"
        case decisions
        case blockers
        case totalExecutionTime = "total_execution_time"
        case currentMilestone = "current_milestone"
    }
}
```

**StateParser extension — visitListItem and visitParagraph:**
```swift
// StateParser.swift — in StateWalker
var totalExecutionTime: String?
var currentMilestone: String?
private var inVelocitySection = false

// In visitParagraph:
if text.starts(with: "**Velocity:**") || text == "Velocity:" {
    inVelocitySection = true
}
if text.starts(with: "**Current focus:**") || text.starts(with: "Current focus:") {
    // e.g. "Phase 10 - Enhanced Empty States (v1.1 Visual Overhaul) — Complete"
    // Extract milestone name from parentheses or dash-delimited portion
    let focus = text.replacingOccurrences(of: "**Current focus:**", with: "")
                    .replacingOccurrences(of: "Current focus:", with: "")
                    .trimmingCharacters(in: .whitespaces)
    // Extract "(v1.1 Visual Overhaul)" pattern
    if let match = focus.range(of: #"\(([^)]+)\)"#, options: .regularExpression) {
        currentMilestone = String(focus[match])
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
    }
}

// In visitListItem (when inVelocitySection):
if text.contains("Total execution time:") {
    totalExecutionTime = text
        .components(separatedBy: "Total execution time:")
        .last?
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
```

**Return from StateParser.parse():**
```swift
return State(
    currentPhase: walker.currentPhase,
    currentPlan: walker.currentPlan,
    status: walker.status ?? "",
    lastActivity: walker.lastActivity,
    decisions: walker.decisions,
    blockers: walker.blockers,
    totalExecutionTime: walker.totalExecutionTime,
    currentMilestone: walker.currentMilestone
)
```

### Anti-Patterns to Avoid

- **Putting stats in ScrollView:** Stats must stay pinned in the header `VStack` above the `ScrollView`. Don't add them inside the existing `ForEach(roadmap.phases)` block.
- **Duplicating overallProgress logic:** The completion % calculation already exists in `DetailView.overallProgress(for:)` and `SidebarView.progressValue()`. Extract into a shared computed property or reuse the same logic pattern (not a new divergent calculation).
- **Forcing LazyVGrid to single row with minFlexible:** Use `.flexible()` GridItem without a min/max — let it fill naturally. 4 columns on typical macOS panel widths (~500px+) will produce a single row automatically.
- **Using .secondary or system colors:** All colors must use `Theme.*`. This is an established constraint from Phase 6.
- **Hard-coding milestone name as a string:** The milestone name must come from parsed data (STATE.md "Current focus:" line), not a hard-coded literal, so it updates with FSEvents.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Grid layout | Custom HStack with geometry math | `LazyVGrid` with `.flexible()` columns | Handles wrapping, spacing, and reflow automatically |
| Fade-in animation | Custom animation state machine | `hasAppeared` pattern (already in `AnimatedProgressBar`) | Single `@State private var hasAppeared = false` + `.onAppear { hasAppeared = true }` — copy-paste from CircularProgressRing.swift |
| Execution time parsing | Manual string scanning in view | Extend `StateParser` (already has the Markdown walker) | Parsing belongs in service layer; walker pattern is already established |

**Key insight:** All computation patterns for the four metrics already exist somewhere in the codebase. `completionPercent` in `DetailView.overallProgress(for:)`, `totalPhases` and `activePhases` trivially from `roadmap.phases`, `executionTime` needs one new parser field.

---

## Common Pitfalls

### Pitfall 1: Execution Time Not in State Model
**What goes wrong:** Developer writes `project.state?.executionTime` and gets a compile error — the field doesn't exist yet.
**Why it happens:** `State` model currently only has 6 fields. STATE.md "Performance Metrics" section is never parsed.
**How to avoid:** Add `totalExecutionTime: String?` to `State` struct AND extend `StateWalker` in `StateParser` to parse it BEFORE building the UI. Do the model+parser change in the first plan.
**Warning signs:** If UI shows "—" for every project even on the gsd-monitor itself (which has the data), the parser extension is not wired correctly.

### Pitfall 2: Milestone Name is Static / Wrong
**What goes wrong:** Milestone label shows wrong text or nil because the parser isn't finding the "Current focus:" line.
**Why it happens:** The "Current focus:" paragraph in STATE.md is inside a bold paragraph node (`**Current focus:** Phase 10...`) — the Markdown parser sees `visitParagraph` not a heading. The text starts with `**Current focus:**` in raw form.
**How to avoid:** In `StateWalker.visitParagraph`, use `rawText.starts(with: "**Current focus:**")` (format() output) OR `plainText.starts(with: "Current focus:")` (plainText output). The existing pattern in `StateParser` uses both — see `visitParagraph` which already checks `rawText` vs `plainText` for "Goal:" handling in `RoadmapParser`.
**Warning signs:** `currentMilestone` is nil despite the STATE.md having the line.

### Pitfall 3: Stats Section Scrolls Away
**What goes wrong:** Stats grid is placed inside the `ScrollView` and disappears when user scrolls to lower phases.
**Why it happens:** Easy mistake to add to the `VStack` inside `ScrollView` rather than to the pinned outer `VStack`.
**How to avoid:** The pinned header `VStack` is at lines 14-59 in `DetailView.swift` with `.background(Theme.bg0)`. The `StatsGridView` must be the last item in THIS VStack (or separate section after it), not inside the `ScrollView`.
**Warning signs:** Stats disappear when scrolling past Phase 3.

### Pitfall 4: LazyVGrid Column Count on Narrow Windows
**What goes wrong:** On a narrow split view, 4 cards don't fit and wrap to 2x2 or 1x4 grid.
**Why it happens:** `LazyVGrid` with 4 `.flexible()` columns wraps when minimum width per column is too tight.
**How to avoid:** Either (a) use 4 `.flexible(minimum: 80)` columns so wrapping is predictable, or (b) use `GeometryReader` to pick 4 columns if width > 400, else 2. Given macOS split view minimum panel widths (~350px detail), 4 columns at ~80px each is achievable. Recommend starting with 4 flexible columns and testing.
**Warning signs:** Cards stack to 2x2 at normal window sizes.

### Pitfall 5: Completion % Diverges from Header Bar
**What goes wrong:** Stats card shows "67%" but the "Overall Progress" bar above it shows "63%". Two different calculation paths.
**Why it happens:** Duplicate implementation of the overallProgress formula.
**How to avoid:** Extract the calculation into a private computed var (e.g., `overallProgress(for: project) -> Double`) and call it from BOTH the progress bar AND the stats card. This already exists as `DetailView.overallProgress(for:)` — reuse it directly.
**Warning signs:** Stats % doesn't match the bar % when viewed side by side.

---

## Code Examples

Verified patterns from existing codebase:

### hasAppeared Animation (from AnimatedProgressBar)
```swift
// Source: GSDMonitor/Views/Components/CircularProgressRing.swift
@State private var hasAppeared = false

.animation(.easeOut(duration: 0.6), value: hasAppeared)
.onAppear {
    hasAppeared = true
}
```

### Gruvbox Color Usage in Cards (from PhaseCardView)
```swift
// Source: GSDMonitor/Views/Dashboard/PhaseCardView.swift
.background(Theme.cardBackground)  // = Theme.bg1
.cornerRadius(12)
.shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
```

### SF Symbol Sizing Pattern (from SidebarView)
```swift
// Source: GSDMonitor/Views/SidebarView.swift
Image(systemName: statusSymbol)
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(statusColor)
    .font(.system(size: 14))
```

### Existing overallProgress Computation (to REUSE not duplicate)
```swift
// Source: GSDMonitor/Views/DetailView.swift lines 132-145
private func overallProgress(for project: Project) -> Double {
    guard let roadmap = project.roadmap, !roadmap.phases.isEmpty else { return 0 }
    let plans = project.plans ?? []
    let phaseContributions = roadmap.phases.map { phase -> Double in
        if phase.status == .done { return 1.0 }
        let phasePlans = plans.filter { $0.phaseNumber == phase.number }
        guard !phasePlans.isEmpty else { return 0.0 }
        let done = phasePlans.filter { $0.status == .done }.count
        return Double(done) / Double(phasePlans.count)
    }
    return phaseContributions.reduce(0, +) / Double(roadmap.phases.count)
}
```

### Divider Styling (to use between stats and phases)
```swift
// Pattern: use Divider() with .background() for Gruvbox tint
Divider()
    .background(Theme.bg2)
    .padding(.horizontal, 0)
```

### LazyVGrid with 4 Flexible Columns
```swift
// Standard SwiftUI 4-column grid
let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

LazyVGrid(columns: columns, spacing: 12) {
    // 4 StatCardView items
}
```

### StateWalker Pattern (from StateParser for context)
```swift
// Source: GSDMonitor/Services/StateParser.swift
// Walker accumulates fields during AST traversal, then builds State at end
return State(
    currentPhase: walker.currentPhase,
    currentPlan: walker.currentPlan,
    status: walker.status ?? "",
    lastActivity: walker.lastActivity,
    decisions: walker.decisions,
    blockers: walker.blockers
    // Add: totalExecutionTime and currentMilestone
)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| System progress bars (`ProgressView`) | `AnimatedProgressBar` with `hasAppeared` | Phase 7 | Pattern available for stats animation |
| System colors (.blue, .green) | Theme.brightBlue, Theme.brightGreen etc. | Phase 6 | All cards must use Theme.* |
| ObservableObject | @Observable | Phase 1 | `ProjectService` is already `@Observable` — stats auto-update via FSEvents |

**No deprecated approaches relevant to this phase.**

---

## Open Questions

1. **Milestone name extraction reliability**
   - What we know: STATE.md line "**Current focus:** Phase 10 - Enhanced Empty States (v1.1 Visual Overhaul) — Complete" contains the milestone name in parentheses
   - What's unclear: Is the parenthetical format consistent across all STATE.md files in monitored projects (non-gsd-monitor projects won't have this field at all)
   - Recommendation: Parse defensively — `currentMilestone` is `String?`, show the section title only when non-nil. For projects without GSD workflow STATE.md, the milestone title simply won't appear, which is correct behavior.

2. **Count-up animation complexity**
   - What we know: The `hasAppeared` boolean pattern handles a simple fade-in. A count-up from 0 to N for integer values requires `withAnimation` + interpolation or a custom `AnimatableData` implementation.
   - What's unclear: Is the additional complexity worth the polish for integer values like "11 phases" or "67%"?
   - Recommendation: Use simple opacity fade-in (already proven pattern) rather than count-up. Count-up only makes sense for large numbers; "11" or "84%" doesn't benefit much. Keep it simple.

3. **Grid wrapping on narrow windows**
   - What we know: macOS NavigationSplitView `.balanced` style gives the detail panel roughly half the window width. On a 1440px display that's ~700px. 4 cards at 700/4 = 175px each — plenty.
   - What's unclear: What's the minimum window size the app supports? On a 1024px display, detail panel ~500px, 4 cards ~125px each — still workable.
   - Recommendation: Use 4 `.flexible(minimum: 80)` columns. Test at 1024px window width.

---

## Sources

### Primary (HIGH confidence)
- Direct source code inspection of `/GSDMonitor/Views/DetailView.swift` — identified pinned header `VStack` insertion point, existing `overallProgress` function
- Direct source code inspection of `/GSDMonitor/Models/State.swift` — confirmed `totalExecutionTime` and `currentMilestone` fields do NOT exist yet
- Direct source code inspection of `/GSDMonitor/Services/StateParser.swift` — confirmed `StateWalker` pattern and extension approach
- Direct source code inspection of `/GSDMonitor/Theme/Theme.swift` — confirmed all Gruvbox color constants available
- Direct source code inspection of `/GSDMonitor/Views/Components/CircularProgressRing.swift` — confirmed `hasAppeared` animation pattern
- Direct source code inspection of `/.planning/STATE.md` — confirmed "Total execution time: ~1.8 hours" field format and "Current focus:" milestone field

### Secondary (MEDIUM confidence)
- SwiftUI `LazyVGrid` with `.flexible()` columns — standard documented behavior, no external verification needed (built-in SwiftUI)

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure SwiftUI + Foundation, no new dependencies, all patterns in existing codebase
- Architecture: HIGH — insertion point clearly identified in DetailView, component split is clean
- Pitfalls: HIGH — all identified from direct code inspection, not speculation
- StateParser extension: HIGH — pattern is straightforward, existing walker structure supports it

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (stable codebase, no fast-moving dependencies)
