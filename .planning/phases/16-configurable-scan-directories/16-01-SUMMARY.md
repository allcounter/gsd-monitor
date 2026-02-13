---
phase: 16-configurable-scan-directories
plan: 01
subsystem: ui
tags: [swiftui, macos, nspanel, drag-and-drop, fsevents, userdefaults, popover]

# Dependency graph
requires: []
provides:
  - ScanSourceState struct in ProjectService (isScanning, lastScannedAt, isAccessible)
  - addScanDirectory() method with duplicate guard and targeted background scan
  - removeScanDirectory() method with ~/Developer protection
  - addScanDirectoryViaPanel() method using NSOpenPanel
  - ScanDirectoriesPopoverView with Default/Additional sections, drag-and-drop, + button
affects:
  - 16-02 (gear button integration in SidebarView, collapsible sections)

# Tech tracking
tech-stack:
  added: [UniformTypeIdentifiers (UTType.fileURL for drag-and-drop), RelativeDateTimeFormatter, TimelineView]
  patterns:
    - "_Concurrency.Task for async operations (avoids GSDMonitor.Task shadowing)"
    - "ScanSourceState dictionary keyed by URL.path on @Observable ProjectService"
    - "stopMonitoring() nils scanSourceMonitoringTask enabling startScanSourceMonitoring() restart"

key-files:
  created:
    - GSDMonitor/Views/Settings/ScanDirectoriesPopoverView.swift
  modified:
    - GSDMonitor/Services/ProjectService.swift
    - GSDMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "~/Developer protection is in removeScanDirectory() data layer guard (not UI-only) for safety"
  - "duplicateWarningPath is a transient @Observable property on ProjectService for cross-view reactivity"
  - "TimelineView(.periodic(from: .now, by: 60)) used for auto-refreshing relative timestamps without manual Timer management"
  - "loadProjects() updated to mark all scan sources as scanning and populate lastScannedAt after initial scan"

patterns-established:
  - "ScanDirectoryRow reads manualProjectPaths from UserDefaults directly to compute project counts"
  - "Drop handler loads URL from NSItemProvider.loadObject(ofClass: URL.self) and validates hasDirectoryPath"
  - "addScanDirectory background Task calls stopMonitoring()/startMonitoring()/startScanSourceMonitoring() after scan completes"

requirements-completed: [SCAN-01, SCAN-02, SCAN-03, SCAN-04]

# Metrics
duration: 3min
completed: 2026-02-21
---

# Phase 16 Plan 01: Scan State Tracking and ScanDirectoriesPopoverView Summary

**Per-source scan state tracking in ProjectService plus a self-contained ScanDirectoriesPopoverView with NSOpenPanel, drag-and-drop, duplicate detection, and live feedback (spinner, relative timestamps, error badges)**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-02-21T08:05:34Z
- **Completed:** 2026-02-21T08:08:26Z
- **Tasks:** 2
- **Files modified:** 3 (ProjectService.swift, ScanDirectoriesPopoverView.swift, project.pbxproj)

## Accomplishments
- ProjectService now tracks per-source scan state (isScanning, lastScannedAt, isAccessible) in a `[String: ScanSourceState]` dictionary observable by all views
- addScanDirectory() appends to UserDefaults-backed scanSources, marks scanning state, performs targeted background discovery, then restarts FSEvents monitoring
- removeScanDirectory() removes projects and scan state, protects ~/Developer as non-removable
- ScanDirectoriesPopoverView presents Default (~/Developer) and Additional (user-added) sections with abbreviated paths, project counts, relative scan times, scanning spinner, and error badge
- Drag-and-drop from Finder supported via `.onDrop(of: [.fileURL])` with visual drop highlight
- Duplicate add shows inline warning with directory path in brightYellow

## Task Commits

Each task was committed atomically:

1. **Task 1: Add scan state tracking and add/remove methods to ProjectService** - `eb7ba57` (feat)
2. **Task 2: Create ScanDirectoriesPopoverView** - `168b139` (feat)

## Files Created/Modified
- `GSDMonitor/Services/ProjectService.swift` - ScanSourceState struct, scanSourceStates/duplicateWarningPath properties, addScanDirectory/removeScanDirectory/addScanDirectoryViaPanel methods, loadProjects() updated with scan state initialization
- `GSDMonitor/Views/Settings/ScanDirectoriesPopoverView.swift` - New popover view with Default/Additional sections, ScanDirectoryRow subview, drag-and-drop, + button, duplicate warning
- `GSDMonitor.xcodeproj/project.pbxproj` - Registered ScanDirectoriesPopoverView.swift in Sources build phase and Settings group

## Decisions Made
- ~/Developer protection implemented in the data layer (removeScanDirectory guard), not UI-only — provides defense-in-depth even if popover UI changes
- `duplicateWarningPath` lives on ProjectService as a transient observable property so any view showing the popover gets automatic reactivity
- `TimelineView` chosen over `Timer.publish` for relative timestamp refresh — SwiftUI-native, no manual lifecycle management needed
- loadProjects() now marks all sources as scanning at start and sets lastScannedAt after completion — gives accurate initial state for the popover

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- ProjectService has complete add/remove/state-tracking API ready for wiring
- ScanDirectoriesPopoverView is self-contained — Plan 02 only needs to wire the gear button in SidebarView to present it
- Plan 02 also needs to add collapsible section headers to SidebarView's project list

---
*Phase: 16-configurable-scan-directories*
*Completed: 2026-02-21*
