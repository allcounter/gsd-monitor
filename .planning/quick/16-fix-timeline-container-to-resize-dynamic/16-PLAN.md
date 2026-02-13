---
phase: quick-16
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
  - GSDMonitor/Views/DetailView.swift
autonomous: true
requirements: [QUICK-16]
must_haves:
  truths:
    - "Timeline container grows and shrinks naturally when milestones are expanded/collapsed"
    - "No internal scroll — timeline content flows with outer ScrollView"
    - "No fixed maxHeight constraint on timeline"
  artifacts:
    - path: "GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift"
      provides: "VStack-based timeline without ScrollView wrapper"
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "MilestoneTimelineView without .frame(maxHeight:) constraint"
  key_links:
    - from: "MilestoneTimelineView.swift"
      to: "DetailView.swift"
      via: "natural sizing — no ScrollView or maxHeight capping height"
---

<objective>
Fix MilestoneTimelineView to resize dynamically with expand/collapse instead of being trapped in a fixed-height ScrollView.

Purpose: Currently the timeline has an internal ScrollView capped at 220pt maxHeight, so expanding a milestone scrolls internally instead of growing the view. Removing the ScrollView and height cap lets it flow naturally with the outer detail scroll.
Output: Timeline that grows/shrinks with content.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
@GSDMonitor/Views/DetailView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace ScrollView with plain VStack in MilestoneTimelineView and remove maxHeight in DetailView</name>
  <files>GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift, GSDMonitor/Views/DetailView.swift</files>
  <action>
In MilestoneTimelineView.swift:
- Remove the `ScrollViewReader { proxy in` wrapper and its closing brace
- Remove the `ScrollView(.vertical, showsIndicators: false) {` wrapper and its closing brace
- Keep the inner `VStack(alignment: .leading, spacing: 0)` with ForEach as the direct body content (inside the if/else)
- Remove the `.onAppear { ... proxy.scrollTo ... }` block entirely (no ScrollViewReader = no proxy)
- Remove the `scrollTargetID` computed property (no longer used)
- Keep: `expandedMilestones` state, `milestoneGroups`, `phasesForMilestone`, `toggleExpansion`
- Keep the `.padding(.horizontal, 4)` on the VStack

In DetailView.swift:
- Remove `.frame(maxHeight: 220)` from the MilestoneTimelineView call (line ~64). Let it size naturally.

In the #Preview at bottom of MilestoneTimelineView.swift:
- Remove `.frame(height: 220)` from preview since no longer relevant (or keep if desired for preview convenience — either is fine).
  </action>
  <verify>Build succeeds: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5` shows BUILD SUCCEEDED</verify>
  <done>MilestoneTimelineView uses plain VStack (no ScrollView/ScrollViewReader), DetailView has no maxHeight on timeline, app builds successfully</done>
</task>

</tasks>

<verification>
- Build succeeds without errors
- MilestoneTimelineView.swift contains no ScrollView or ScrollViewReader
- DetailView.swift has no .frame(maxHeight:) on MilestoneTimelineView
</verification>

<success_criteria>
Timeline container resizes dynamically — no internal scroll, no height cap. Expanding a milestone grows the view; collapsing shrinks it.
</success_criteria>

<output>
After completion, create `.planning/quick/16-fix-timeline-container-to-resize-dynamic/16-SUMMARY.md`
</output>
