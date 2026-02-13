---
phase: quick-9
plan: 01
subsystem: file-monitoring
tags: [fsevents, directory-watching, auto-discovery, quick-task]
dependency_graph:
  requires: [FileWatcherService, ProjectService, ProjectDiscoveryService]
  provides: [scan-source-monitoring, automatic-project-discovery]
  affects: [project-loading, sidebar-updates]
tech_stack:
  added: []
  patterns: [dual-watcher-pattern, nil-check-guard, async-stream-debounce]
key_files:
  created: []
  modified:
    - GSDMonitor/Services/ProjectService.swift
decisions:
  - summary: "Use separate FileWatcherService for scan sources vs .planning/ directories"
    rationale: "Allows independent lifecycle management and different debounce timings (2s vs 1s)"
    alternatives: ["Single watcher with path filtering"]
  - summary: "Nil-check guard in startScanSourceMonitoring() prevents infinite loop"
    rationale: "loadProjects() calls startScanSourceMonitoring(), which triggers loadProjects() on events — guard ensures watcher starts once and stays running"
    alternatives: ["Reference counting", "State machine"]
  - summary: "2-second debounce for scan source events (vs 1s for .planning/)"
    rationale: "Directory operations like git clone generate many rapid events — longer debounce reduces unnecessary rescans"
    alternatives: ["Same 1s debounce", "3s debounce"]
metrics:
  duration_minutes: 1.25
  tasks_completed: 2
  files_modified: 1
  commits: 1
  completed_at: 2026-02-16T19:52:56Z
---

# Quick Task 9: Scan Source Directory Watching

**One-liner:** Automatic project discovery via second FileWatcherService monitoring scan source directories (e.g. ~/Developer) for top-level directory changes with 2s debounce and infinite-loop prevention.

## Overview

Added a second FileWatcherService to ProjectService that watches scan source directories (configured locations like ~/Developer) for structural changes. When directories are created, deleted, or renamed inside scan sources, the app automatically triggers a full project rescan, making new/removed/renamed projects appear in the sidebar without manual refresh.

**Problem solved:** Previously, the app only watched `.planning/` directories of already-known projects. Adding a new project to ~/Developer or renaming an existing one required manual app restart or refresh.

**Solution:** Dual-watcher pattern — one FileWatcherService for `.planning/` directories (fine-grained updates), another for scan source directories (structural discovery).

## Implementation

### Core Changes

**ProjectService.swift:**
- Added `scanSourceWatcher: FileWatcherService` (separate from existing `fileWatcher`)
- Added `scanSourceMonitoringTask: Task<Void, Never>?` to track background monitoring
- Created `startScanSourceMonitoring()` with nil-check guard to prevent infinite restart loop
- Extended `stopMonitoring()` to also cancel and cleanup scan source watcher
- Updated `loadProjects()`, `addProjectManually()`, `removeManualProject()` to call `startScanSourceMonitoring()` after file system changes

### Key Design Decisions

**1. Dual Watcher Pattern**

Use two separate FileWatcherService instances instead of single watcher with path filtering:
- `.planning/` watcher: watches individual project directories, 1-second debounce
- Scan source watcher: watches parent directories (~/Developer), 2-second debounce

Benefits: independent lifecycle management, different debounce tuning, clearer separation of concerns.

**2. Infinite Loop Prevention**

Challenge: loadProjects() -> startScanSourceMonitoring() -> watcher event -> loadProjects() -> infinite loop

Solution: Nil-check guard in `startScanSourceMonitoring()`:
```swift
guard scanSourceMonitoringTask == nil else { return }
```

This ensures the watcher starts once and keeps running across loadProjects() calls triggered by its own events.

**3. Longer Debounce for Scan Sources**

Scan source events use 2-second debounce (vs 1s for .planning/ watcher) because directory operations like `git clone` create many rapid filesystem events. The longer debounce coalesces these into a single rescan.

## Tasks Completed

### Task 1: Add scan source directory watcher to ProjectService
**Status:** Complete
**Commit:** f20760a
**Duration:** ~1 min

Added dual-watcher infrastructure:
- New properties: `scanSourceWatcher`, `scanSourceMonitoringTask`
- New method: `startScanSourceMonitoring()` with infinite-loop guard
- Updated methods: `stopMonitoring()`, `loadProjects()`, `addProjectManually()`, `removeManualProject()`
- 2-second debounce for directory change events
- Full `loadProjects()` rescan on scan source changes

**Files modified:**
- GSDMonitor/Services/ProjectService.swift (+27 lines)

### Task 2: Build and run the app
**Status:** Complete
**Duration:** <1 min

Verified app builds without errors and launches successfully with scan source monitoring active.

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- [x] ProjectService.swift compiles with new scanSourceWatcher
- [x] No infinite loops: loadProjects() -> startScanSourceMonitoring() guarded by nil-check
- [x] Both watchers properly cleaned up in stopMonitoring()
- [x] App builds without errors
- [x] App launches successfully

## Self-Check: PASSED

**Created files:**
```
FOUND: ./.planning/quick/9-add-scan-source-directory-watching-for-a/9-SUMMARY.md
```

**Modified files:**
```
FOUND: ./GSDMonitor/Services/ProjectService.swift
```

**Commits:**
```
FOUND: f20760a (git log --oneline | grep f20760a)
```

All artifacts verified successfully.

## Impact

**User Experience:**
- Projects added to ~/Developer appear automatically in sidebar (no restart needed)
- Renamed projects update automatically
- Deleted projects disappear automatically
- Seamless discovery flow matches user expectations from file managers

**Technical:**
- Two independent FileWatcherService instances running concurrently
- Scan source watcher stays alive across loadProjects() calls (singleton behavior)
- 2-second debounce reduces rescan frequency during bulk operations
- No performance impact: FSEvents are efficient, loadProjects() already handles incremental updates

**Future Work:**
- Consider user-configurable debounce timing in preferences
- Add logging/telemetry for scan source events (debugging)
- Potential optimization: diff scan results instead of full reload

## Commits

| Hash | Message | Files |
|------|---------|-------|
| f20760a | feat(quick-9): add scan source directory watcher | ProjectService.swift |

**Total duration:** 1.25 minutes
**Completed at:** 2026-02-16T19:52:56Z
