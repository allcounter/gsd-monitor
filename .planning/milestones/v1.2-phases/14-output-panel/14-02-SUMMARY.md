---
phase: 14-output-panel
plan: "02"
subsystem: ui
tags: [swiftui, output-panel, notifications, user-notifications, gruvbox, timeline-view]

# Dependency graph
requires:
  - phase: 14-01
    provides: OutputPanelView + OutputRawView + HSplitView integration + CommandRunnerService environment

provides:
  - OutputStructuredView with phase/plan header, task count, progress bar, elapsed timer, stderr lines
  - OutputBannerView with success/failure/cancelled styles using Gruvbox colors
  - ElapsedTimerView using TimelineView for 1-second M:SS elapsed time updates
  - ViewMode segmented toggle (Structured/Raw) in OutputPanelView header
  - Cancel confirmation dialog before SIGINT with 4-second cleanup timeout message
  - Completion banners with exit code, duration, and actionable recovery suggestions
  - macOS failure notification via UNUserNotificationCenter (.timeSensitive, passes Focus mode)
  - sendCommandFailureNotification method added to NotificationService

affects: [phase-15, command-runner-ui, output-display]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - TimelineView(.animation(minimumInterval:)) for efficient 1-second timer updates without Timer
    - BannerStyle enum on OutputBannerView — keeps color/style logic colocated with the view
    - sendFailureNotification directly in OutputPanelView — avoids multi-layer injection complexity for UNUserNotificationCenter singleton
    - ViewMode enum with CaseIterable + Picker(.segmented) for tab-style view switching

key-files:
  created:
    - GSDMonitor/Views/OutputPanel/ElapsedTimerView.swift
    - GSDMonitor/Views/OutputPanel/OutputBannerView.swift
    - GSDMonitor/Views/OutputPanel/OutputStructuredView.swift
  modified:
    - GSDMonitor/Views/OutputPanel/OutputPanelView.swift
    - GSDMonitor/Services/NotificationService.swift
    - GSDMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "sendFailureNotification implemented directly in OutputPanelView using UNUserNotificationCenter singleton — avoids multi-layer injection of NotificationService through DetailView; NotificationService.sendCommandFailureNotification also added as reusable public method"
  - "BannerStyle enum defined in OutputBannerView.swift (not inside struct) — allows use from OutputPanelView without nesting"
  - "ViewMode enum defined at file scope in OutputPanelView.swift — CaseIterable enables Picker ForEach without manual list"

patterns-established:
  - "Failure notification: .onChange(of: currentRun?.state) in view — no separate service wiring needed for self-contained notification"
  - "Completion banners: @ViewBuilder bannerView(for:) helper method — keeps body clean while supporting multi-case switch"
  - "Auto-reset to structured view: .onChange(of: currentRun?.id) — triggers on new command start, not on state changes"

requirements-completed: [OUTP-03, OUTP-04, OUTP-05, SAFE-03, SAFE-04]

# Metrics
duration: 3min
completed: 2026-02-18
---

# Phase 14 Plan 02: Output Panel Completion Summary

**Segmented Structured/Raw toggle, Gruvbox completion banners, cancel confirmation dialog, and failure notifications complete the GSD output panel feature set**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-18T01:21:14Z
- **Completed:** 2026-02-18T01:23:59Z
- **Tasks:** 3
- **Files modified:** 5

## Accomplishments
- ElapsedTimerView renders live M:SS elapsed time during command execution using TimelineView (1-second updates, no manual Timer management)
- OutputBannerView provides green success / red failure / gray cancelled banners with Gruvbox Bright palette and slide-in animation
- OutputStructuredView shows phase/plan header, task count, progress bar with aqua gradient, and last 5 stderr lines on failure
- OutputPanelView updated with segmented Structured/Raw picker, auto-switch on new command, cancel button + confirmationDialog, and completion banners with exit code + recovery text
- macOS failure notification fires on .failed or .crashed state via UNUserNotificationCenter with .timeSensitive interruption level

## Task Commits

Each task was committed atomically:

1. **Task 1: Create OutputStructuredView, OutputBannerView, and ElapsedTimerView** - `b9ff68a` (feat)
2. **Task 2: Update OutputPanelView with segmented toggle, banners, and cancel dialog** - `35ef59f` (feat)
3. **Task 3: Add failure notification to NotificationService** - `c695ddd` (feat)

## Files Created/Modified
- `GSDMonitor/Views/OutputPanel/ElapsedTimerView.swift` - TimelineView-based 1-second M:SS elapsed timer
- `GSDMonitor/Views/OutputPanel/OutputBannerView.swift` - BannerStyle enum + Gruvbox-colored completion banners
- `GSDMonitor/Views/OutputPanel/OutputStructuredView.swift` - Phase header, task count, AnimatedProgressBar, stderr error lines
- `GSDMonitor/Views/OutputPanel/OutputPanelView.swift` - Segmented toggle, cancel button + dialog, completion banners, failure notification wiring
- `GSDMonitor/Services/NotificationService.swift` - Added sendCommandFailureNotification public method
- `GSDMonitor.xcodeproj/project.pbxproj` - Registered 3 new files with OUTP1402 prefix IDs

## Decisions Made
- `sendFailureNotification` implemented directly in OutputPanelView via UNUserNotificationCenter singleton, avoiding multi-layer NotificationService injection through DetailView. NotificationService also received `sendCommandFailureNotification` as a reusable public method per plan spec.
- `BannerStyle` enum defined at file scope in OutputBannerView.swift (not nested inside struct) so OutputPanelView can reference it without extra qualification.
- `ViewMode` defined at file scope in OutputPanelView.swift to keep the enum accessible for future use.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 14 (Output Panel) is complete — all 8 requirements covered across Plans 01 and 02
- Phase 15 (final phase) can begin whenever ready
- No blockers; build succeeds with zero errors

## Self-Check: PASSED

All created files verified present:
- FOUND: GSDMonitor/Views/OutputPanel/ElapsedTimerView.swift
- FOUND: GSDMonitor/Views/OutputPanel/OutputBannerView.swift
- FOUND: GSDMonitor/Views/OutputPanel/OutputStructuredView.swift
- FOUND: .planning/phases/14-output-panel/14-02-SUMMARY.md

All commits verified in git log:
- FOUND: b9ff68a (feat(14-02): add OutputStructuredView, OutputBannerView, and ElapsedTimerView)
- FOUND: 35ef59f (feat(14-02): update OutputPanelView with segmented toggle, banners, and cancel dialog)
- FOUND: c695ddd (feat(14-02): add sendCommandFailureNotification to NotificationService)

Build: SUCCEEDED (zero errors)

---
*Phase: 14-output-panel*
*Completed: 2026-02-18*
