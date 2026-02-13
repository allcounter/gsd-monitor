---
phase: 12-milestone-timeline
plan: 02
subsystem: ui
tags: [swift, swiftui, timeline, milestone, scroll, animation, gruvbox]

# Dependency graph
requires:
  - phase: 12-01
    provides: Milestone struct and Roadmap.milestones populated by RoadmapParser
  - phase: 11-stats-grid
    provides: Dashboard/ group pattern, AnimatedProgressBar, StatusBadge components
  - phase: 01-foundation
    provides: Phase struct, PhaseStatus enum
  - phase: 06-gruvbox-theme
    provides: Theme color constants (statusNotStarted, statusActive, statusComplete, bg2, bg3, fg1, textSecondary)
provides:
  - TimelinePhaseNodeView (individual phase node with status circle, connector line, progress bar)
  - MilestoneGroupView (milestone separator badge with expand/collapse for completed milestones)
  - MilestoneTimelineView (top-level timeline with ScrollViewReader auto-scroll to current milestone)
  - DetailView integration: MilestoneTimelineView placed between StatsGridView and phase cards section
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ScrollViewReader + DispatchQueue.main.async for auto-scroll on appear
    - Set<String> + formSymmetricDifference for toggle expansion state
    - isCompact param for visual hierarchy (compact nodes in expanded completed milestones)
    - Conditional rendering: show phases if isExpanded || !milestone.isComplete (current milestone always expanded)

key-files:
  created:
    - GSDMonitor/Views/Dashboard/TimelinePhaseNodeView.swift
    - GSDMonitor/Views/Dashboard/MilestoneGroupView.swift
    - GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
  modified:
    - GSDMonitor/Views/DetailView.swift
    - GSDMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "MilestoneTimelineView contains internal ScrollView enabling ScrollViewReader auto-scroll without conflicting with outer phase-cards ScrollView"
  - "isCompact=true for phases inside expanded completed milestones — 8px circle vs 12px, caption font vs subheadline, gives visual hierarchy"
  - "Completed milestone badge uses Unicode checkmark (u2713) instead of SF Symbol for inline text rendering"
  - "formSymmetricDifference toggles Set membership with withAnimation for smooth expand/collapse"

patterns-established:
  - "Timeline node pattern: left column (circle + connector Rectangle) + right column (text + progress), HStack spacing 12"
  - "Milestone group pattern: badge row (tap target for toggle) + conditional phase list with transition animation"

requirements-completed: [DASH-04]

# Metrics
duration: ~2min
completed: 2026-02-17
---

# Phase 12 Plan 02: Milestone Timeline Views Summary

**Vertical connected-node timeline grouped by milestone with expand/collapse for completed milestones, status-colored circles, inline progress bars, and auto-scroll to current milestone — integrated as pinned header in DetailView**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-17T10:48:06Z
- **Completed:** 2026-02-17T10:49:48Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Created `TimelinePhaseNodeView`: status-colored circle (12px/8px), vertical connector line, phase name, inline AnimatedProgressBar with percentage, StatusBadge — supports compact mode for visual hierarchy
- Created `MilestoneGroupView`: milestone Capsule badge (green filled for complete, bg2 for current), chevron expand/collapse for completed milestones, phase count summary when collapsed, smooth opacity+move transition
- Created `MilestoneTimelineView`: ScrollViewReader with auto-scroll to first non-complete milestone on appear, toggle expansion via Set<String>, gracefully renders EmptyView if no milestones
- Integrated `MilestoneTimelineView` in DetailView pinned header after StatsGridView, before Divider, with `.frame(maxHeight: 220)`
- Registered all 3 new view files in pbxproj (PBXBuildFile + PBXFileReference + Dashboard group children + Sources build phase)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create TimelinePhaseNodeView** - `617f8c3` (feat)
2. **Task 2: Create MilestoneGroupView, MilestoneTimelineView, integrate into DetailView** - `4e5d0f3` (feat)

## Files Created/Modified

- `GSDMonitor/Views/Dashboard/TimelinePhaseNodeView.swift` - Individual phase node with circle, connector line, progress bar, status badge; isCompact param for visual hierarchy
- `GSDMonitor/Views/Dashboard/MilestoneGroupView.swift` - Milestone group with badge, phase count summary when collapsed, expand/collapse animation
- `GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift` - Top-level timeline with ScrollViewReader auto-scroll and expandedMilestones state
- `GSDMonitor/Views/DetailView.swift` - Added MilestoneTimelineView after StatsGridView in pinned header
- `GSDMonitor.xcodeproj/project.pbxproj` - Registered all 3 new Dashboard view files with DASH1202 prefix

## Decisions Made

- MilestoneTimelineView uses its own internal ScrollView so ScrollViewReader.proxy.scrollTo() works correctly, while remaining contained within the `.frame(maxHeight: 220)` in DetailView's pinned header — no conflict with outer phase-cards ScrollView.
- `isCompact: milestone.isComplete` gives visual hierarchy between current-milestone phases (full size) and expanded completed-milestone phases (reduced size).
- Unicode `\u{2019}` checkmark used in badge text instead of SF Symbol for reliable inline rendering in Text().
- `formSymmetricDifference([name])` is the idiomatic Set toggle — adds if absent, removes if present.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 12 complete: Milestone struct (Plan 01) + Timeline views (Plan 02) fully delivered
- v1.1 Visual Overhaul milestone is now complete — all 12 phases of GSD Monitor implemented
- Timeline is visible in DetailView for projects with a ## Milestones section in ROADMAP.md
- Projects without milestone structure gracefully show no timeline (empty milestones array)

## Self-Check: PASSED

All created files found on disk. Both task commits verified in git log.

- TimelinePhaseNodeView.swift: FOUND
- MilestoneGroupView.swift: FOUND
- MilestoneTimelineView.swift: FOUND
- Task 1 commit 617f8c3: FOUND
- Task 2 commit 4e5d0f3: FOUND
