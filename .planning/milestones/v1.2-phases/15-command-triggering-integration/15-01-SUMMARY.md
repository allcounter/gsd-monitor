---
phase: 15-command-triggering-integration
plan: 01
subsystem: ui
tags: [swiftui, commandrunner, buttons, sidebar, phasecard, plandetail]

# Dependency graph
requires:
  - phase: 14-command-runner-ui
    provides: CommandRunnerService with enqueue/cancelRunningCommand/activeRuns, ElapsedTimerView, CommandRequest model
provides:
  - Smart default action button (Plan/Execute/Verify) on PhaseCardView based on phase state
  - Ellipsis overflow menu (Discuss/Plan/Execute/Verify) on PhaseCardView
  - Cancel + spinner + elapsed timer on PhaseCardView when command active
  - Execute button on PlanCard rows in PhaseDetailView
  - Running indicator (spinner + elapsed timer) on PlanCard when command active
  - Running indicator (spinner + elapsed timer) on SidebarView ProjectRow when command active
affects: [15-02, 15-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@Environment(CommandRunnerService.self) injected into leaf views for command triggering"
    - "isRunning pattern: commandRunner.activeRuns[project.path.path] != nil"
    - "SmartDefaultAction tuple: (label, command, args) computed from phase plan state"

key-files:
  created: []
  modified:
    - GSDMonitor/Views/Dashboard/PhaseCardView.swift
    - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
    - GSDMonitor/Views/SidebarView.swift

key-decisions:
  - "PhaseCardView smart default button label: Plan (no plans) / Execute (plans exist, not all done) / Verify (all done)"
  - "PlanCard receives project parameter to enable CommandRunnerService lookup by project path"
  - "SidebarView ProjectRow replaces status icon with spinner + ElapsedTimerView (brightYellow) when command active"
  - "_Concurrency.Task used in PhaseCardView cancel action (GSDMonitor.Task shadows Swift Task in views)"

patterns-established:
  - "isRunning check: commandRunner.activeRuns[project.path.path] != nil — consistent across all surfaces"
  - "Cancel button with .tint(Theme.brightRed) replaces action button during active command"
  - "Spinner scaleEffect pattern: 0.6 for card level, 0.55 for sidebar, 0.5 for plan row"

requirements-completed: [TRIG-01, TRIG-02]

# Metrics
duration: 4min
completed: 2026-02-18
---

# Phase 15 Plan 01: Context Buttons and Running Indicators Summary

**Command triggering buttons and animated running state indicators added to PhaseCardView, PhaseDetailView PlanCard rows, and SidebarView project rows via CommandRunnerService environment injection**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-18T02:59:00Z
- **Completed:** 2026-02-18T03:02:54Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- PhaseCardView now shows a smart default action button (Plan/Execute/Verify) adapting to phase state, plus a ··· overflow menu with all four GSD commands (Discuss/Plan/Execute/Verify). Both transform to Cancel + spinner + elapsed timer when a command is active.
- PlanCard in PhaseDetailView shows an Execute button that enqueues a plan-specific `/gsd:execute-phase --plan` command, and replaces with spinner + elapsed timer when a command is active for the project.
- SidebarView ProjectRow now shows an animated spinner + elapsed timer in brightYellow when a command is active, replacing the static folder/checkmark status icon.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add context buttons and running indicator to PhaseCardView and PhaseDetailView** - `5e009e7` (feat)
2. **Task 2: Add running state indicator to sidebar project rows** - `eb06150` (feat)

Note: PhaseCardView changes were partially committed ahead of time in `fb1fbfa` (feat 15-02 commit included PhaseCardView as a Rule 3 fix). The PhaseDetailView portion of Task 1 was committed in `5e009e7`.

## Files Created/Modified

- `GSDMonitor/Views/Dashboard/PhaseCardView.swift` - Smart default button + ··· menu + cancel/running state (committed in fb1fbfa as Rule 3 fix, completed in this plan)
- `GSDMonitor/Views/Dashboard/PhaseDetailView.swift` - Execute button on PlanCard + running indicator, project parameter added to PlanCard
- `GSDMonitor/Views/SidebarView.swift` - ProjectRow running state: spinner + brightYellow elapsed timer replaces status icon

## Decisions Made

- `PlanCard` receives `project: Project` parameter to enable `commandRunner.activeRuns[project.path.path]` lookup — Plan model does not have a project reference, so project is passed from `PhaseDetailView`.
- SidebarView uses `Theme.brightYellow` for the elapsed timer foreground in the running indicator, making it visually distinct and high-visibility against the dark sidebar background.
- `_Concurrency.Task` used in PhaseCardView cancel action because `GSDMonitor.Task` model shadows Swift concurrency Task module-wide.

## Deviations from Plan

### Auto-fixed Issues

None - plan executed exactly as written.

Note: PhaseCardView was already implemented in `fb1fbfa` (15-02 commit) as a Rule 3 fix during a prior execution session. The remaining two files (PhaseDetailView, SidebarView) were implemented in this execution.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All command triggering entry points are live on phase cards, plan rows, and sidebar rows
- CommandRunnerService.enqueue() is wired correctly with proper CommandRequest arguments
- Running state indicators are consistent across all three surfaces
- Ready for Phase 15-02 (CommandPaletteView — already committed separately) and 15-03

---
*Phase: 15-command-triggering-integration*
*Completed: 2026-02-18*
