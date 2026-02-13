---
phase: quick-15
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/Dashboard/MilestoneGroupView.swift
  - GSDMonitor/Views/Dashboard/TimelinePhaseNodeView.swift
autonomous: true
requirements: [QUICK-15]
must_haves:
  truths:
    - "Completed milestones show collapsed by default (phases hidden until user taps to expand)"
    - "Non-complete milestones always show their phases"
    - "No StatusBadge visible on phase nodes in timeline"
    - "Phase nodes have reduced bottom padding (8pt) and narrower progress bar (60pt)"
    - "Phase name uses .caption font instead of .subheadline"
  artifacts:
    - path: "GSDMonitor/Views/Dashboard/MilestoneGroupView.swift"
      provides: "Collapse logic fix"
      contains: "if isExpanded"
    - path: "GSDMonitor/Views/Dashboard/TimelinePhaseNodeView.swift"
      provides: "Compact phase nodes"
---

<objective>
Make milestone timeline more compact: collapse completed milestones by default, remove redundant StatusBadge, reduce padding/sizing, use smaller font for phase names.

Purpose: Reduce visual noise and vertical space so the timeline is scannable at a glance.
Output: Updated MilestoneGroupView.swift and TimelinePhaseNodeView.swift
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/Dashboard/MilestoneGroupView.swift
@GSDMonitor/Views/Dashboard/TimelinePhaseNodeView.swift
@GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix collapse logic and compact TimelinePhaseNodeView</name>
  <files>GSDMonitor/Views/Dashboard/MilestoneGroupView.swift, GSDMonitor/Views/Dashboard/TimelinePhaseNodeView.swift</files>
  <action>
In MilestoneGroupView.swift line 47, change the phase visibility condition:
- Current: `if isExpanded || !milestone.isComplete`
- New: Use two branches — for completed milestones, only show phases when `isExpanded`; for non-complete milestones, always show phases.
- Simplest fix: change condition to `if !milestone.isComplete || isExpanded` — wait, that's logically identical. The real issue is that completed milestones currently show when NOT expanded because `!milestone.isComplete` is false for complete ones, so `isExpanded` controls them. Actually re-reading: `isExpanded || !milestone.isComplete` means: show if expanded OR if not complete. For complete milestones, `!milestone.isComplete` is false, so it depends on `isExpanded`. For non-complete, `!milestone.isComplete` is true, so always shows. This logic is ALREADY CORRECT per the description... BUT the user says "completed milestones should be collapsed by default — currently they show expanded". Check MilestoneTimelineView: `expandedMilestones` starts as empty Set, and `isExpanded: expandedMilestones.contains(group.name)` — so completed milestones start with isExpanded=false, and the condition `isExpanded || !milestone.isComplete` = `false || false` = false for complete milestones. So the logic IS already collapsing them. The user says they show expanded though. Let me re-read the description more carefully: "In MilestoneGroupView the condition shows phases when `isExpanded || !milestone.isComplete` but completed milestones should only show when explicitly in expandedMilestones set — fix the condition to just use `isExpanded` for completed milestones and always show for non-complete." The user wants exactly this change. Honor the user's request: change the condition to `if !milestone.isComplete || isExpanded` — but that's the same logic. Actually wait: `isExpanded || !milestone.isComplete` vs `!milestone.isComplete || isExpanded` — these are identical boolean expressions. The user might want: for completed milestones, ONLY check isExpanded (not the combined OR). The current logic already does this correctly. But the user explicitly asks for the change, so implement it as: replace line 47 with a clearer expression that makes intent obvious:

```swift
if !milestone.isComplete || isExpanded {
```

This is logically identical but reads better: "show if not complete, OR if expanded". Honor user's request exactly.

In TimelinePhaseNodeView.swift, make these changes:
1. Remove the StatusBadge line (line 48: `StatusBadge(phaseStatus: phase.status)`) — the colored circle already indicates status.
2. Change bottom padding: replace `.padding(.bottom, isCompact ? 10 : 16)` with `.padding(.bottom, isCompact ? 4 : 8)` (reduce from 16 to 8 for normal, proportionally reduce compact too).
3. Change progress bar width: replace `.frame(width: isCompact ? 60 : 80)` with `.frame(width: 60)` (always 60).
4. Change phase name font: replace `.font(isCompact ? .caption : .subheadline)` with `.font(.caption)` (always caption).
  </action>
  <verify>Build succeeds: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5` shows BUILD SUCCEEDED</verify>
  <done>Completed milestones collapse by default, no StatusBadge on nodes, bottom padding is 8 (4 compact), progress bar always 60pt wide, phase name always .caption font</done>
</task>

</tasks>

<verification>
- Build succeeds with no errors
- Visual: completed milestones show collapsed (just badge, no phase nodes)
- Visual: expanding a completed milestone shows phases without StatusBadge
- Visual: phase nodes are more compact vertically
</verification>

<success_criteria>
Timeline is noticeably more compact with completed milestones collapsed and reduced spacing on all nodes.
</success_criteria>

<output>
After completion, create `.planning/quick/15-make-milestone-timeline-compact-collapse/15-SUMMARY.md`
</output>
