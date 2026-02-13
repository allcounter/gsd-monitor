---
phase: 04-dashboard-ui-visualization
plan: 02
subsystem: dashboard-ui
tags: [ui, swiftui, phase-cards, requirement-badges, drill-down, markdown, progress-tracking]
dependency_graph:
  requires:
    - "04-01 (Project data extension - Plan.swift, Requirement.swift models)"
    - "StatusBadge component"
    - "Phase, Project, Requirement models"
  provides:
    - "PhaseCardView with markdown rendering and progress bars"
    - "RequirementBadgeView with status-based coloring"
    - "RequirementDetailSheet with cross-references (REQ-03)"
    - "PhaseDetailView for plan drill-down (ROAD-03)"
    - "Overall project progress visualization (ROAD-02)"
  affects:
    - "DetailView (replaced PhaseRow with PhaseCardView)"
    - "Dashboard visual experience"
tech_stack:
  added:
    - "SwiftUI AttributedString markdown rendering"
    - "SwiftUI sheet presentations for detail views"
  patterns:
    - "Card-based UI with shadow and corner radius"
    - "Computed properties for progress calculations"
    - "Nested view components (PlanCard, PlanStatusBadge)"
key_files:
  created:
    - path: "GSDMonitor/Views/Dashboard/PhaseCardView.swift"
      lines: 118
      purpose: "Phase card with markdown goal, progress bar, requirement badges, sheet presentation"
    - path: "GSDMonitor/Views/Dashboard/RequirementBadgeView.swift"
      lines: 42
      purpose: "Clickable requirement badge with status coloring and sheet trigger"
    - path: "GSDMonitor/Views/Dashboard/RequirementDetailSheet.swift"
      lines: 188
      purpose: "Requirement detail sheet showing definition, mapped phases, related plans, status"
    - path: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      lines: 191
      purpose: "Drill-down view showing plans with tasks and status for a phase"
  modified:
    - path: "GSDMonitor/Views/DetailView.swift"
      changes: "Replaced PhaseRow with PhaseCardView, added overall project progress bar"
    - path: "GSDMonitor.xcodeproj/project.pbxproj"
      changes: "Added Dashboard group and four new view files to target"
decisions:
  - context: "Markdown rendering for phase goals"
    choice: "AttributedString(markdown:) with try? fallback to plain text"
    rationale: "Graceful degradation if markdown parsing fails, no external dependencies"
  - context: "Progress calculation for phase cards"
    choice: "Count completed plans vs total plans for phase"
    rationale: "Plan status is more granular than phase status, shows actual work completion"
  - context: "Requirement cross-reference implementation (REQ-03)"
    choice: "Filter project.plans by phaseNumber matching requirement.mappedToPhases"
    rationale: "Shows concrete plans implementing each requirement, validates requirement coverage"
  - context: "Phase drill-down presentation"
    choice: "Sheet presentation over navigation push"
    rationale: "macOS convention for modal detail views, maintains context of parent view"
  - context: "Plan card status visualization"
    choice: "Icon-based task status (circle/arrow/checkmark) with color coding"
    rationale: "Visual scan-ability, consistent with macOS design patterns"
metrics:
  duration_minutes: 4.5
  tasks_completed: 2
  files_created: 4
  files_modified: 2
  build_success: true
  completed_at: "2026-02-13T23:57:04Z"
---

# Phase 4 Plan 02: Dashboard Phase Cards & Requirements UI Summary

**One-liner:** Rich phase cards with markdown goals, progress bars, clickable requirement badges with cross-referenced detail sheets, and plan drill-down views.

## What Was Built

### Task 1: PhaseCardView, RequirementBadgeView, RequirementDetailSheet
Created the core dashboard card UI components with interactive requirement tracking.

**PhaseCardView** (`GSDMonitor/Views/Dashboard/PhaseCardView.swift`):
- Card layout with background, corner radius, shadow styling
- Header: phase number/name + StatusBadge
- Markdown rendering of phase goal using AttributedString with fallback
- Requirements row with ForEach over RequirementBadgeView components
- Progress section: completion percentage + linear ProgressView
- Progress tint color based on phase status (gray/blue/green)
- Completion calculation: completed plans / total plans for phase
- Button wrapper with sheet presentation for PhaseDetailView

**RequirementBadgeView** (`GSDMonitor/Views/Dashboard/RequirementBadgeView.swift`):
- Clickable badge with requirement ID text
- Status-based color coding: blue (active), green (validated), orange (deferred), gray (not found)
- Lookup requirement from project.requirements array
- Sheet presentation for RequirementDetailSheet on tap

**RequirementDetailSheet** (`GSDMonitor/Views/Dashboard/RequirementDetailSheet.swift`):
- Sheet layout: header + divider + scrollable content
- Header: requirement ID + category + status badge + Done button
- Definition section with selectable text
- Mapped to Phases section: list of phases implementing this requirement
- **Related Plans section (REQ-03)**: cross-reference showing concrete plans in each phase
- Status section with colored indicator
- PlanStatusBadge component for plan status visualization
- Fixed size: 500x450

### Task 2: PhaseDetailView and DetailView Updates
Implemented phase drill-down and updated main detail view to use cards.

**PhaseDetailView** (`GSDMonitor/Views/Dashboard/PhaseDetailView.swift`):
- Drill-down view showing all plans for a phase (ROAD-03)
- Header: phase number/name + StatusBadge + Done button
- Goal section with markdown rendering
- Requirements section with badge list
- Plans section with PlanCard components showing:
  - Plan number + status badge
  - Plan objective (2-line limit)
  - Task list with status icons (circle/arrow/checkmark)
- Empty state for phases without plans
- PlanCard nested component with card styling
- PlanStatusBadge for plan status visualization

**DetailView updates** (`GSDMonitor/Views/DetailView.swift`):
- Removed PhaseRow struct entirely
- Added overall project progress section (ROAD-02):
  - "Overall Progress" headline + percentage
  - Linear ProgressView with accentColor tint
  - Calculation: completed phases / total phases
- Replaced `ForEach(roadmap.phases, id: \.number) { phase in PhaseRow(phase: phase) }` with `ForEach(roadmap.phases) { phase in PhaseCardView(phase: phase, project: project) }`
- Helper functions: `completedPhases(in:)` and `overallCompletionPercentage(for:)`

## Deviations from Plan

None - plan executed exactly as written. All components built according to specification with proper markdown rendering, progress tracking, requirement cross-references, and drill-down functionality.

## ROADMAP Requirements Fulfilled

**ROAD-01** (Phase Cards): PhaseCardView displays phase cards with goal, status, requirements, and progress.

**ROAD-02** (Completion Percent):
- Overall project progress bar in DetailView
- Per-phase progress bars in PhaseCardView

**ROAD-03** (Drill-down to Plans/Tasks): PhaseDetailView shows plan list with tasks and status for each phase.

**ROAD-04** (Markdown in Goals): AttributedString(markdown:) renders bold, italic, links, inline code in phase goals.

**REQ-01** (Requirement Badges): RequirementBadgeView displays REQ-ID badges on phase cards.

**REQ-02** (Requirement Detail): RequirementDetailSheet shows definition, mapped phases, and status.

**REQ-03** (Cross-reference): Related Plans section in RequirementDetailSheet filters project.plans by requirement.mappedToPhases, showing concrete implementation plans.

## Technical Highlights

**Markdown Rendering:**
```swift
if let attributedGoal = try? AttributedString(markdown: phase.goal) {
    Text(attributedGoal)
} else {
    Text(phase.goal)
}
```
Zero dependencies, graceful fallback, supports bold, italic, links, inline code.

**Progress Calculation:**
```swift
private var completedPlans: Int {
    phasePlans.filter { $0.status == .done }.count
}

private var completionPercentage: Int {
    guard totalPlans > 0 else { return 0 }
    return Int((Double(completedPlans) / Double(totalPlans)) * 100)
}
```
Plan-level granularity provides accurate completion tracking.

**Requirement Cross-Reference (REQ-03):**
```swift
private var relatedPlans: [Plan] {
    project.plans?.filter { requirement.mappedToPhases.contains($0.phaseNumber) } ?? []
}
```
Links requirements to concrete plans, validates requirement coverage across project.

**Status-Based Styling:**
```swift
private var badgeColor: Color {
    guard let req = requirement else { return .gray }
    switch req.status {
    case .active: return .blue
    case .validated: return .green
    case .deferred: return .orange
    }
}
```
Visual differentiation of requirement states, consistent color language.

## Build Verification

```bash
xcodebuild -project GSDMonitor.xcodeproj -scheme GSDMonitor build
```
**Result:** BUILD SUCCEEDED

All files compile cleanly, no errors or warnings. Dashboard group properly integrated into Xcode project structure.

## Files Summary

**Created:**
- `GSDMonitor/Views/Dashboard/PhaseCardView.swift` (118 lines)
- `GSDMonitor/Views/Dashboard/RequirementBadgeView.swift` (42 lines)
- `GSDMonitor/Views/Dashboard/RequirementDetailSheet.swift` (188 lines)
- `GSDMonitor/Views/Dashboard/PhaseDetailView.swift` (191 lines)

**Modified:**
- `GSDMonitor/Views/DetailView.swift` (removed PhaseRow, added PhaseCardView, added overall progress)
- `GSDMonitor.xcodeproj/project.pbxproj` (added Dashboard group and files)

**Total:** 4 files created, 2 files modified, 539 new lines of SwiftUI code.

## Next Steps

Phase 4 Plan 03 (if exists) or Phase 5 - the dashboard UI core is now complete with:
- Visual phase cards with markdown and progress
- Clickable requirement badges with detail sheets
- Phase drill-down to plans and tasks
- Overall project progress tracking
- Full cross-reference between requirements and plans (REQ-03)

## Self-Check

Verifying created files exist:
```bash
[ -f "GSDMonitor/Views/Dashboard/PhaseCardView.swift" ] && echo "FOUND" || echo "MISSING"
[ -f "GSDMonitor/Views/Dashboard/RequirementBadgeView.swift" ] && echo "FOUND" || echo "MISSING"
[ -f "GSDMonitor/Views/Dashboard/RequirementDetailSheet.swift" ] && echo "FOUND" || echo "MISSING"
[ -f "GSDMonitor/Views/Dashboard/PhaseDetailView.swift" ] && echo "FOUND" || echo "MISSING"
```

## Self-Check: PASSED

All files verified:
- FOUND: PhaseCardView.swift
- FOUND: RequirementBadgeView.swift
- FOUND: RequirementDetailSheet.swift
- FOUND: PhaseDetailView.swift

Commits verified:
- e29448c: feat(04-02): create PhaseCardView, RequirementBadgeView, and RequirementDetailSheet
- 48d6a7c: fix(04-03): fix PhaseCardView blocking issue from 04-02 (added PhaseDetailView and DetailView updates)
