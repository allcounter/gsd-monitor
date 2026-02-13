---
phase: quick-17
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
  - GSDMonitor/Views/Dashboard/MilestoneGroupView.swift
autonomous: true
requirements: [QUICK-17]
must_haves:
  truths:
    - "Completed milestones show only badge pill + 'X/Y phases' summary text"
    - "Completed milestones have NO expand/collapse chevron and NO tap interaction"
    - "Completed milestones NEVER show their phase list"
    - "Active/incomplete milestones show their full phase list (always visible, no toggle)"
  artifacts:
    - path: "GSDMonitor/Views/Dashboard/MilestoneGroupView.swift"
      provides: "Simplified milestone group with no expand/collapse"
    - path: "GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift"
      provides: "Timeline without expandedMilestones state"
  key_links:
    - from: "MilestoneGroupView"
      to: "MilestoneTimelineView"
      via: "Simplified initializer (no isExpanded/onToggle)"
---

<objective>
Redesign MilestoneTimelineView so completed milestones show only the badge pill and "X/Y phases" summary (no phase list, no expand/collapse). Only active/incomplete milestones display their phases. This saves significant vertical space.

Purpose: Reduce visual clutter by hiding phase details for already-completed milestones.
Output: Updated MilestoneGroupView and MilestoneTimelineView.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
@GSDMonitor/Views/Dashboard/MilestoneGroupView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Remove expand/collapse from MilestoneGroupView, simplify MilestoneTimelineView</name>
  <files>
    GSDMonitor/Views/Dashboard/MilestoneGroupView.swift
    GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
  </files>
  <action>
**MilestoneGroupView.swift:**

1. Remove `isExpanded` and `onToggle` properties from the struct entirely.

2. Rewrite the body logic:
   - For the badge row (HStack): Keep the milestone name pill (with checkmark for complete). For completed milestones, ALWAYS show "X/Y phases" summary text next to the pill. Remove the chevron icon entirely. Remove `onTapGesture` entirely. Remove `contentShape(Rectangle())`.
   - For the phase nodes section: Replace the condition `if !milestone.isComplete || isExpanded` with simply `if !milestone.isComplete`. This means completed milestones NEVER show phases.
   - Remove `.animation(.easeInOut(...), value: isExpanded)` modifier since there's no expand/collapse state.
   - Remove the `.transition(...)` on the ForEach since there's no animation.

3. Update the Preview to remove `isExpanded` and `onToggle` parameters.

**MilestoneTimelineView.swift:**

1. Remove the `@SwiftUI.State private var expandedMilestones` property entirely.
2. Remove the `toggleExpansion` method entirely.
3. Update the `MilestoneGroupView` initializer call in the ForEach to remove `isExpanded` and `onToggle` parameters.
4. Keep everything else (milestoneGroups, phasesForMilestone) as-is.
  </action>
  <verify>Build succeeds: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5`</verify>
  <done>Completed milestones show only badge pill + "X/Y phases" with no chevron, no tap, no phase list. Active milestones show their phases always. App builds without errors.</done>
</task>

</tasks>

<verification>
- Build the project and confirm no compile errors
- Visually: completed milestones are compact (badge + summary only), active milestone shows phases
</verification>

<success_criteria>
- Completed milestones render as a single row: pill badge + "X/Y phases"
- No chevron icons on completed milestones
- No tap/expand interaction on completed milestones
- Active/incomplete milestones show full phase list without any toggle
- Project compiles cleanly
</success_criteria>

<output>
After completion, create `.planning/quick/17-compact-milestone-timeline-no-collapse/17-SUMMARY.md`
</output>
