# Phase 12: Milestone Timeline - Research

**Researched:** 2026-02-17
**Domain:** SwiftUI custom vertical timeline view, data model milestone grouping
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Milestone sections
- Completed milestones (e.g. v1.0) collapsed to a single summary node showing milestone name + phase count (e.g. "v1.0 MVP - 5/5 phases")
- Collapsed milestone node is expandable — click to reveal individual v1.0 phases as smaller nodes
- Milestone separator is an inline label badge with Gruvbox colors: "v1.0 MVP ✔" / "v1.1 Visual Overhaul"
- Timeline auto-scrolls to current milestone on load — completed milestones above the fold

### Claude's Discretion
- Node design: icon, text layout, progress indicator per node
- Timeline layout: vertical vs horizontal, connecting line style, spacing
- Interaction: hover states, click-to-scroll-to-phase-card behavior
- Animation: node appearance, expand/collapse transitions
- How expanded v1.0 phases differ visually from current milestone phases

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DASH-03 | Milestone-tidslinje viser faser som forbundne noder i vertikal visning med status-farver | Custom SwiftUI VStack with ZStack overlay for vertical connector line; status colors from Theme.* system |
| DASH-04 | Tidslinje-noder viser fase-navn, status og progress inline | Phase node view displays phase.name, phase.status (via Theme colors), and phaseProgress computed from plans |
</phase_requirements>

---

## Summary

Phase 12 requires a custom vertical timeline component placed in `DetailView` above the phase cards ScrollView. The timeline groups phases by milestone (v1.0, v1.1, etc.) with completed milestones collapsed to summary nodes and the current milestone expanded. SwiftUI has no built-in vertical timeline primitive — this is a fully custom view built from standard SwiftUI layout primitives (VStack, ZStack, HStack, overlay).

The critical finding is a **data model gap**: the current `Roadmap` model stores phases as a flat array with no milestone grouping. The `Phase.milestones` field exists but is misused as "success criteria" storage (see `PhaseDetailView.swift` line 92-108 which renders it as "Success Criteria"). Milestone membership must be derived from `RoadmapParser` by parsing the ROADMAP.md milestone sections. A new `Milestone` struct needs to be added to the `Roadmap` model, and `RoadmapParser` must be extended to populate it.

The timeline's expand/collapse for milestone groups uses `@State var expandedMilestones: Set<String>` — a simple `withAnimation(.easeInOut)` wrapping `if isExpanded` controls visibility of phase nodes under a milestone. Auto-scroll to current milestone uses SwiftUI `ScrollViewReader` with `scrollTo(_:anchor:)`.

**Primary recommendation:** Build a `MilestoneTimelineView` as a new component in `Views/Dashboard/`. Add a `Milestone` struct to `Models/Roadmap.swift` and extend `RoadmapParser` to populate `roadmap.milestones`. The timeline is self-contained SwiftUI; no third-party libraries needed.

---

## Standard Stack

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| SwiftUI VStack + ZStack | Native | Vertical layout with overlay connector line | Native, no deps, Swift 6 compatible |
| ScrollViewReader | Native | Auto-scroll to current milestone on load | Only way to programmatic scroll in SwiftUI |
| withAnimation + @State | Native | Expand/collapse transitions | Standard SwiftUI animation pattern |
| GeometryReader | Native | Measure node heights for connector line sizing | Required for precise line alignment |

### Supporting
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| Theme.* colors | Existing | Status colors for nodes and badges | All color decisions — never hardcode |
| AnimatedProgressBar | Existing | Phase progress indicator inline in node | Reuse existing component from Phase 7 |
| StatusBadge | Existing | Status display in phase nodes | Reuse existing component |
| ProjectColors.forName | Existing | Node accent color matching project | Consistent with PhaseCardView pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| VStack + ZStack overlay line | Canvas drawing | Canvas is overkill; VStack overlay is simpler and declarative |
| Custom Milestone model | Derived grouping from Phase.milestones | Phase.milestones is already used for success criteria; explicit model is cleaner |
| ScrollViewReader scrollTo | onAppear + Task | scrollTo is more reliable; onAppear fires before layout is complete |

---

## Architecture Patterns

### Recommended File Structure
```
GSDMonitor/
├── Models/
│   └── Roadmap.swift         # Add Milestone struct + roadmap.milestones: [Milestone]
├── Services/
│   └── RoadmapParser.swift   # Extend to parse milestone sections and populate milestones
└── Views/
    └── Dashboard/
        ├── MilestoneTimelineView.swift     # New: top-level timeline ScrollView
        ├── MilestoneGroupView.swift        # New: one group (separator badge + phase nodes)
        └── TimelinePhaseNodeView.swift     # New: individual phase node
```

### Pattern 1: Milestone Data Model
**What:** Add `Milestone` struct to the `Roadmap` model that groups phases under a named milestone with completion status.
**When to use:** Required — the current flat `roadmap.phases` has no grouping.

```swift
// In Roadmap.swift — add alongside existing Roadmap struct
struct Milestone: Identifiable, Sendable {
    let id: UUID
    let name: String           // "v1.0 MVP", "v1.1 Visual Overhaul"
    let phaseNumbers: [Int]    // Phase numbers belonging to this milestone
    var isComplete: Bool       // True if all phases in group are .done

    init(name: String, phaseNumbers: [Int], isComplete: Bool) {
        self.id = UUID()
        self.name = name
        self.phaseNumbers = phaseNumbers
        self.isComplete = isComplete
    }
}

// In Roadmap struct — add milestones field
struct Roadmap: Codable, Sendable {
    let projectName: String?
    let phases: [Phase]
    var milestones: [Milestone]   // NEW — not Codable, derived at parse time

    enum CodingKeys: String, CodingKey {
        case projectName = "project_name"
        case phases
        // milestones is intentionally excluded from CodingKeys
    }
}
```

Note: `Milestone` is NOT Codable — it's derived from parsing and not stored. The `Roadmap` struct excludes milestones from CodingKeys so JSON encode/decode is unaffected.

### Pattern 2: ROADMAP.md Milestone Parsing
**What:** Parse the `## Milestones` section and phase-milestone associations from the progress table or heading structure in ROADMAP.md.
**When to use:** Required for populating `roadmap.milestones`.

The ROADMAP.md format has two signals for milestone membership:
1. The `<details>` block summary: `✅ v1.0 MVP (Phases 1-5)` — maps phases 1-5 to v1.0
2. The heading `### 🚧 v1.1 Visual Overhaul` — phases following this heading belong to v1.1
3. The progress table: `| Phase | Milestone | ...` columns

The most reliable parsing strategy: use the `## Milestones` section bullet points (`- ✅ **v1.0 MVP** - Phases 1-5`) which explicitly list phase ranges. Extract: milestone name, phase range, completion status (✅ = done).

```swift
// In RoadmapParser — extend parse() to also derive milestones
private func parseMilestones(from content: String, phases: [Phase]) -> [Milestone] {
    // Pattern: "- ✅ **v1.0 MVP** - Phases 1-5" or "- 🚧 **v1.1 Visual Overhaul** - Phases 6-12"
    let pattern = #"- [✅🚧] \*\*(.+?)\*\* - Phases? (\d+)[-–](\d+)"#
    // ... parse name and phase range, derive isComplete from phases statuses
}
```

**Fallback:** If `## Milestones` section is absent, return empty `milestones` array — timeline degrades gracefully to show ungrouped phases.

### Pattern 3: Vertical Timeline Layout
**What:** A VStack of milestone groups, each with a separator badge and phase nodes. A connector line is drawn using ZStack overlay on the VStack.
**When to use:** For the timeline visual structure.

```swift
struct MilestoneTimelineView: View {
    let project: Project
    var projectName: String = ""
    var onPhaseSelected: ((Phase) -> Void)? = nil

    @State private var expandedMilestones: Set<String> = []
    private var scrollTargetID: String? { /* current milestone name */ }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(milestoneGroups) { group in
                        MilestoneGroupView(
                            milestone: group,
                            phases: phasesForMilestone(group),
                            project: project,
                            projectName: projectName,
                            isExpanded: expandedMilestones.contains(group.name),
                            onToggle: { toggleExpansion(group.name) },
                            onPhaseSelected: onPhaseSelected
                        )
                        .id(group.name)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                if let target = scrollTargetID {
                    // Scroll to current milestone — use DispatchQueue.main.async
                    // to ensure layout is complete before scrolling
                    DispatchQueue.main.async {
                        proxy.scrollTo(target, anchor: .top)
                    }
                }
            }
        }
    }
}
```

### Pattern 4: Connecting Line Implementation
**What:** A vertical line connecting timeline nodes, drawn with ZStack overlay on the node list.
**When to use:** Core visual element of the timeline.

The standard SwiftUI approach: use an HStack where left side has node circle + vertical line, right side has content. The line is drawn as a `Rectangle().frame(width: 2)` extending between nodes.

```swift
struct TimelinePhaseNodeView: View {
    let phase: Phase
    let project: Project
    let isLast: Bool
    // ...

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left column: circle + connector line
            VStack(spacing: 0) {
                Circle()
                    .fill(nodeColor)
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)

                if !isLast {
                    Rectangle()
                        .fill(Theme.bg3)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            // Right column: phase info
            VStack(alignment: .leading, spacing: 4) {
                Text("Phase \(phase.number): \(phase.name)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.fg1)

                // Inline progress + status
                HStack(spacing: 8) {
                    AnimatedProgressBar(
                        progress: phaseProgress,
                        barColor: nodeColor,
                        height: 4
                    )
                    .frame(width: 80)

                    Text("\(Int(phaseProgress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.bottom, 16)
        }
        // Tap to scroll to phase card
        .contentShape(Rectangle())
        .onTapGesture { onPhaseSelected?(phase) }
    }
}
```

### Pattern 5: Collapsed Milestone Summary Node
**What:** Collapsed view of a completed milestone shows summary inline — name + phase count. Click expands.
**When to use:** For completed milestones in the timeline.

```swift
struct MilestoneGroupView: View {
    let milestone: Milestone
    let phases: [Phase]
    let isExpanded: Bool
    let onToggle: () -> Void

    private var completedCount: Int { phases.filter(\.isComplete).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Milestone separator badge row
            HStack {
                // Inline label badge
                Text(milestone.isComplete ? "\(milestone.name) ✔" : milestone.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(milestone.isComplete ? Theme.bg0 : Theme.fg1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(milestone.isComplete ? Theme.statusComplete : Theme.bg2)
                    .clipShape(Capsule())

                if milestone.isComplete {
                    // Summary count shown when collapsed
                    if !isExpanded {
                        Text("\(completedCount)/\(phases.count) phases")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer()

                // Expand/collapse chevron for completed milestones
                if milestone.isComplete {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { if milestone.isComplete { onToggle() } }
            .padding(.vertical, 8)

            // Phase nodes — collapsed by default for completed milestones
            if isExpanded || !milestone.isComplete {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(phases.enumerated()), id: \.element.id) { idx, phase in
                        TimelinePhaseNodeView(
                            phase: phase,
                            project: project,
                            isLast: idx == phases.count - 1
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }
}
```

### Anti-Patterns to Avoid
- **Using SwiftUI TimelineView:** `TimelineView` is for time-schedule-based animation updates, NOT for displaying a list of milestones. Wrong tool for this job.
- **Third-party timeline libraries:** No existing library matches the Gruvbox aesthetic or collapse behavior needed. All available libs are heavy or iOS-focused.
- **GeometryReader for line height:** Dynamic connector lines with GeometryReader + PreferenceKeys are complex. Use the simpler approach: `frame(maxHeight: .infinity)` on the connecting Rectangle within an HStack that expands naturally.
- **Blocking auto-scroll in onAppear:** SwiftUI layout isn't complete in `onAppear` synchronously. Always wrap `proxy.scrollTo()` in `DispatchQueue.main.async {}` (or `Task { @MainActor in }`).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Status colors for nodes | Custom color logic | `Theme.statusActive`, `Theme.statusComplete`, `Theme.statusNotStarted` | Already defined, Gruvbox-consistent |
| Phase progress calculation | Duplicate logic | Extract shared helper (same logic exists in DetailView and StatsGridView) | DRY — create `PhaseProgressHelper` or add extension |
| Progress bar in node | Custom mini bar | `AnimatedProgressBar` from Phase 7 | Already built, already animated |
| Expand/collapse animation | Custom transition | `withAnimation(.easeInOut) { }` + `if isExpanded` | Standard SwiftUI pattern, zero complexity |
| Phase status badge | Custom badge | `StatusBadge(phaseStatus:)` | Already parameterized |

**Key insight:** The progress calculation logic (`Double(completedPlans) / Double(totalPlans)`) exists in both `DetailView.overallProgress()` and `StatsGridView.completionPercent`. Phase 12 needs the same per-phase calculation. The planner should create a shared helper (extension on Phase or a free function) to avoid a third copy.

---

## Common Pitfalls

### Pitfall 1: Phase.milestones field confusion
**What goes wrong:** The `Phase.milestones: [String]` field looks like it stores milestone membership, but it actually stores **success criteria**. Using this field to derive milestone grouping produces wrong results.
**Why it happens:** Field name is misleading. `PhaseDetailView` (line 92-108) renders `phase.milestones` under a "Success Criteria" heading — the field is a list of success criteria strings, not milestone names.
**How to avoid:** Add a new `Roadmap.milestones: [Milestone]` field. Do NOT repurpose `Phase.milestones`.
**Warning signs:** If grouping comes out as "each phase is its own milestone" or all phases appear under wrong milestones.

### Pitfall 2: Roadmap.milestones breaking Codable
**What goes wrong:** Adding `milestones: [Milestone]` to `Roadmap` struct and making it Codable causes decode failures when loading existing cached project data that lacks `milestones` in JSON.
**Why it happens:** Codable structs fail if a required key is missing from JSON.
**How to avoid:** Exclude `milestones` from `Roadmap.CodingKeys` (already demonstrated in code examples above). The field is computed at parse time, not stored.
**Warning signs:** Crash on project load after adding the field.

### Pitfall 3: ScrollViewReader timing
**What goes wrong:** `proxy.scrollTo()` called in `onAppear` doesn't scroll — stays at top.
**Why it happens:** SwiftUI layout hasn't completed when `onAppear` fires synchronously.
**How to avoid:** Use `DispatchQueue.main.async { proxy.scrollTo(target, anchor: .top) }` or `Task { @MainActor in proxy.scrollTo(target, anchor: .top) }`.
**Warning signs:** Timeline loads but always shows first milestone at top, even when current milestone is v1.1.

### Pitfall 4: Timeline height in DetailView layout
**What goes wrong:** `MilestoneTimelineView` with an internal ScrollView conflicts with DetailView's outer ScrollView for phases — causes layout issues or double-scroll behavior.
**Why it happens:** Nested ScrollViews in macOS SwiftUI don't compose well.
**How to avoid:** Do NOT put MilestoneTimelineView in a ScrollView. Instead, place it as a non-scrollable `VStack` section in the DetailView pinned header (above the phase cards ScrollView divider). It should have a fixed max height (e.g., `.frame(maxHeight: 200)`) with its own internal ScrollView if needed, OR be fully inline with no internal scroll — relying on DetailView's phase ScrollView for scrollability.
**Warning signs:** Two scroll indicators appear, or scrolling one area scrolls the other.

### Pitfall 5: Swift 6 concurrency — @State in view
**What goes wrong:** Expand/collapse state causes sendability warnings if stored in wrong place.
**Why it happens:** Swift 6 strict concurrency.
**How to avoid:** `expandedMilestones: Set<String>` as `@State` in the view is correct — `@State` is always on `@MainActor`. No async access needed.

---

## Code Examples

Verified patterns from existing codebase (HIGH confidence):

### Status Color for Phase Node
```swift
// Pattern from PhaseCardView.swift headerGradient and Theme.swift
var nodeColor: Color {
    switch phase.status {
    case .notStarted: return Theme.statusNotStarted  // Theme.fg4 gray
    case .inProgress: return Theme.statusActive      // Theme.yellow
    case .done:       return Theme.statusComplete    // Theme.green
    }
}
```

### Phase Progress Calculation (existing pattern)
```swift
// Same logic as DetailView.overallProgress() — extract as shared helper
func phaseProgress(for phase: Phase, plans: [Plan]) -> Double {
    if phase.status == .done { return 1.0 }
    let phasePlans = plans.filter { $0.phaseNumber == phase.number }
    guard !phasePlans.isEmpty else { return 0.0 }
    let done = phasePlans.filter { $0.status == .done }.count
    return Double(done) / Double(phasePlans.count)
}
```

### Integration Point in DetailView
```swift
// DetailView.swift — add MilestoneTimelineView BEFORE the Divider and ScrollView
// In the pinned header VStack (after StatsGridView, before Divider):

if let roadmap = project.roadmap, !roadmap.milestones.isEmpty {
    MilestoneTimelineView(
        project: project,
        projectName: projectName
    )
    .frame(maxHeight: 200)   // Constrain height in header
}
```

### Roadmap Model Update (non-breaking)
```swift
// Roadmap.swift
struct Roadmap: Codable, Sendable {
    let projectName: String?
    let phases: [Phase]
    var milestones: [Milestone] = []   // NOT in CodingKeys — computed, not stored

    enum CodingKeys: String, CodingKey {
        case projectName = "project_name"
        case phases
        // milestones intentionally excluded
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| TimelineView (animation schedule) | Custom VStack + ZStack layout | N/A (different use case) | No SwiftUI built-in for visual step timelines |
| Nested ScrollViews | Single ScrollView with inline sections | macOS 13+ | Avoids nested scroll conflicts |
| GeometryReader for line height | maxHeight: .infinity in HStack | SwiftUI best practices | Simpler, no PreferenceKeys needed |

**Not deprecated/outdated:** `ScrollViewReader` + `scrollTo()` is the correct and current API for programmatic scroll. Introduced SwiftUI 2.0, still primary approach as of 2025.

---

## Open Questions

1. **Current milestone detection for auto-scroll**
   - What we know: `project.state?.currentMilestone` returns a string like "v1.1 Visual Overhaul" — same format as milestone names in ROADMAP.md
   - What's unclear: Will the string match exactly with parsed `Milestone.name`? The ROADMAP.md has "v1.1 Visual Overhaul" in the heading but `State.currentMilestone` also returns "v1.1 Visual Overhaul" (from StateParser). Should match.
   - Recommendation: Use `milestone.name.contains(project.state?.currentMilestone ?? "")` as fuzzy match fallback.

2. **Phase-to-milestone mapping when Milestones section absent**
   - What we know: Some projects may not have a `## Milestones` section in ROADMAP.md
   - What's unclear: Should the timeline show at all if no milestones are parsed?
   - Recommendation: If `roadmap.milestones.isEmpty`, render all phases under a single synthetic milestone "All Phases" — or simply don't render `MilestoneTimelineView` at all (existing DetailView already handles the no-roadmap case gracefully).

3. **MilestoneTimelineView height budget in DetailView header**
   - What we know: DetailView header currently has: project title + progress bar + StatsGridView. Adding a full timeline above phase cards may push the scrollable phase list too far down.
   - What's unclear: How many phases will typically show in the current (non-collapsed) milestone?
   - Recommendation: Cap at `.frame(maxHeight: 220)` with the timeline having its own internal ScrollView for overflow. Test with 7-phase v1.1 milestone in Xcode preview.

---

## Sources

### Primary (HIGH confidence)
- Existing codebase — verified by direct file reading:
  - `GSDMonitor/Models/Phase.swift` — `Phase.milestones` is `[String]`, success criteria field
  - `GSDMonitor/Models/Roadmap.swift` — flat `phases: [Phase]`, no milestone grouping
  - `GSDMonitor/Models/State.swift` — `currentMilestone: String?` available for auto-scroll target
  - `GSDMonitor/Views/DetailView.swift` — integration point: after StatsGridView, before Divider
  - `GSDMonitor/Views/Dashboard/PhaseDetailView.swift` — confirms Phase.milestones = success criteria
  - `GSDMonitor/Theme/Theme.swift` — all available status colors (statusActive, statusComplete, statusNotStarted)
  - `GSDMonitor/Views/Components/CircularProgressRing.swift` — AnimatedProgressBar reusable
  - `.planning/ROADMAP.md` — actual ROADMAP.md format with milestone sections verified

### Secondary (MEDIUM confidence)
- Apple Developer Documentation: `ScrollViewReader` + `scrollTo(_:anchor:)` — standard API for programmatic scrolling (verified via existing SwiftUI knowledge, confirmed current API)
- SwiftUI `withAnimation` + conditional view pattern — established pattern, used throughout existing codebase

### Tertiary (LOW confidence)
- WebSearch results confirmed no standard third-party SwiftUI milestone timeline library exists — custom implementation required (consistent with absence of relevant libraries in project dependencies)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all components are native SwiftUI or already in codebase
- Architecture: HIGH — derived from direct codebase inspection and established SwiftUI patterns
- Pitfalls: HIGH — pitfalls 1, 2, 3 verified from direct codebase analysis; pitfalls 4, 5 from established SwiftUI patterns
- Data model gap: HIGH — confirmed by reading Phase.swift, Roadmap.swift, RoadmapParser.swift

**Research date:** 2026-02-17
**Valid until:** 2026-03-17 (stable SwiftUI APIs, stable codebase)
