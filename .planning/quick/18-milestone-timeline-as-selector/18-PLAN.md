---
phase: quick-18
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
  - GSDMonitor/Views/Dashboard/MilestoneGroupView.swift
  - GSDMonitor/Views/DetailView.swift
autonomous: true
requirements: [QUICK-18]
must_haves:
  truths:
    - "Milestone pills render as a horizontal selector bar in the pinned header"
    - "Clicking a milestone pill filters the phase list below to that milestone's phases"
    - "No milestone selected shows all phases"
    - "Active milestone is selected by default on load"
    - "Completed milestones are clickable and show their phases when selected"
  artifacts:
    - path: "GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift"
      provides: "Horizontal milestone selector bar with selection binding"
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Selected milestone state, filtered phase list"
  key_links:
    - from: "MilestoneTimelineView"
      to: "DetailView"
      via: "Binding<Milestone?> for selected milestone"
    - from: "DetailView selected milestone"
      to: "ForEach phases"
      via: "filteredPhases computed property"
---

<objective>
Turn the milestone timeline from a vertical list with inline phases into a horizontal pill selector bar. Selecting a milestone filters the shared phase list below. Active milestone pre-selected. All milestones (including completed) are clickable.

Purpose: Replace the current split layout (completed milestones show no phases, active shows inline phases) with a cleaner pattern: selector bar + single filtered phase list.
Output: Updated MilestoneTimelineView (horizontal selector), updated DetailView (selection state + filtered phases), simplified MilestoneGroupView (no longer renders phases inline).
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
@GSDMonitor/Views/Dashboard/MilestoneGroupView.swift
@GSDMonitor/Views/Dashboard/TimelinePhaseNodeView.swift
@GSDMonitor/Models/Roadmap.swift
@GSDMonitor/Models/Phase.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Convert MilestoneTimelineView to horizontal selector bar</name>
  <files>
    GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
    GSDMonitor/Views/Dashboard/MilestoneGroupView.swift
  </files>
  <action>
Rewrite MilestoneTimelineView to be a horizontal pill selector bar:

1. Add a `@Binding var selectedMilestone: Milestone?` parameter.
2. Replace the VStack+ForEach layout with an HStack (or horizontal ScrollView for overflow) of milestone pill buttons.
3. Each pill: capsule background, milestone name text. Use Theme.bg2 for unselected, Theme.statusComplete for completed+selected, the project accent color (or Theme.statusActive) for active+selected. Unselected completed milestones get a subtle checkmark. Keep font(.caption) and .fontWeight(.semibold) styling consistent with current pills.
4. Tapping a pill: if already selected, deselect (set nil = show all). If not selected, set selectedMilestone to that milestone.
5. Remove the `phasesForMilestone` helper — phases are no longer rendered here.
6. Keep the `project` and `projectName` parameters.

Simplify MilestoneGroupView: This view is no longer needed since milestones are now rendered as simple pills in MilestoneTimelineView. Either delete the file or keep it as a minimal wrapper — simplest approach is to delete it since all its functionality moves into MilestoneTimelineView's pill rendering.

Update previews to reflect the new horizontal layout with a @State binding.
  </action>
  <verify>Project builds: `cd . && xcodebuild -project GSDMonitor.xcodeproj -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5`</verify>
  <done>MilestoneTimelineView renders a horizontal row of clickable milestone pills with selection binding. MilestoneGroupView removed or unused.</done>
</task>

<task type="auto">
  <name>Task 2: Wire milestone selection into DetailView to filter phases</name>
  <files>
    GSDMonitor/Views/DetailView.swift
  </files>
  <action>
In DetailView.swift:

1. Add `@SwiftUI.State private var selectedMilestone: Milestone?` state.
2. Pass `$selectedMilestone` binding to MilestoneTimelineView.
3. Add a computed property `filteredPhases` that:
   - If selectedMilestone is nil: returns ALL phases from roadmap (sorted by number).
   - If selectedMilestone is set: returns only phases whose number is in selectedMilestone.phaseNumbers (sorted by number).
4. Replace the scrollable phases section's `ForEach(roadmap.phases)` with `ForEach(filteredPhases)`.
5. Remove the "Phases" text header (the selected milestone pill already indicates context) — OR keep it but update to show "All Phases" vs the milestone name.
6. Add an `.onAppear` or `.onChange(of: project)` modifier that auto-selects the active milestone (first milestone where isComplete == false). If all are complete, leave nil (show all).
7. Also reset selectedMilestone when project changes (if user switches projects in sidebar).
8. Since Milestone uses UUID for id and is created with UUID() each time, selection comparison must use milestone.name (not id). Use `selectedMilestone?.name == milestone.name` for equality checks, or make Milestone conform to Equatable by name+phaseNumbers.

Update previews.
  </action>
  <verify>Project builds: `cd . && xcodebuild -project GSDMonitor.xcodeproj -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5`</verify>
  <done>Clicking a milestone pill in the header filters the phase list below. Active milestone is pre-selected on load. Deselecting shows all phases. Completed milestones are clickable.</done>
</task>

</tasks>

<verification>
- App builds without errors
- Milestone pills render horizontally in pinned header
- Clicking a pill filters phase list to that milestone's phases
- Clicking the already-selected pill deselects it (shows all phases)
- Active milestone is auto-selected on initial load
- Completed milestones can be selected to view their phases
- Switching projects resets selection to the new project's active milestone
</verification>

<success_criteria>
Milestone timeline acts as a selector: horizontal pill bar in header, single phase list below that filters based on selection. No more inline phase nodes in the milestone area. All milestones clickable regardless of completion status.
</success_criteria>

<output>
After completion, create `.planning/quick/18-milestone-timeline-as-selector/18-SUMMARY.md`
</output>
