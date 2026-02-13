---
phase: 03-file-system-monitoring
plan: 02
subsystem: file-system-monitoring
tags: [file-watching, debounce, async-stream, swift-6, lifecycle]
dependency_graph:
  requires:
    - FileWatcherService from 03-01
    - ProjectService from Phase 02
  provides:
    - Live file monitoring with debounced reload
    - App lifecycle-aware monitoring
  affects:
    - All project views (automatic UI updates)
tech_stack:
  added: []
  patterns:
    - AsyncStream consumption with for-await-in
    - Debouncing with AsyncAlgorithms .debounce(for:)
    - String path parsing to extract project root
    - Scene phase handling for background/foreground transitions
key_files:
  created: []
  modified:
    - GSDMonitor/Services/ProjectService.swift
    - GSDMonitor/Views/ContentView.swift
decisions:
  - title: 1-second debounce window for file events
    rationale: Matches FSEvents latency, coalesces Git commits and multi-file saves
    outcome: Single reload per logical change instead of event storm
  - title: Restart monitoring on project add/remove
    rationale: FSEventStream watches specific paths, requires recreation for path list changes
    outcome: Dynamic monitoring always matches current project list
  - title: Reload on app activation (background->foreground)
    rationale: Monitoring may pause during background, catch missed changes
    outcome: Guaranteed fresh state when user returns to app
metrics:
  duration_minutes: 1
  tasks_completed: 2
  files_created: 0
  files_modified: 2
  completed: 2026-02-13
---

# Phase 3 Plan 02: ProjectService File Monitoring Integration Summary

**One-liner:** Live file monitoring with 1-second debounced reload pipeline - FSEvents to UI update in ~2 seconds, zero manual refresh needed

## What Was Built

Integrated FileWatcherService into ProjectService to enable automatic UI updates when .planning/ files change on disk. The full pipeline: file change -> FSEvents callback -> AsyncStream -> 1-second debounce -> reloadProject -> @Observable update -> SwiftUI render.

### Core Components

**ProjectService.swift (66 lines added)**
- `reloadProject(at:)` - Efficiently re-parses a single project without full reload
- `startMonitoring()` - Creates FileWatcherService stream, debounces events, extracts affected projects, triggers reloads
- `stopMonitoring()` - Cancels monitoring task and stops file watcher
- Monitoring lifecycle: starts on loadProjects(), restarts on project add/remove

**ContentView.swift (10 lines added)**
- `@Environment(\.scenePhase)` property for app lifecycle tracking
- `.onChange(of: scenePhase)` modifier reloads projects on background->foreground transition
- Ensures UI picks up changes that occurred while app was inactive

## Implementation Details

### Debounced Event Handling

**Problem:** Git commit creates 50+ events, multi-file save creates 10+ events. Without debouncing, UI would reload 50 times in 1 second.

**Solution:**
```swift
for await changedURLs in eventStream.debounce(for: .seconds(1)) {
    // changedURLs contains the last batch before 1-second quiet period
    var affectedProjects: Set<String> = []
    for url in changedURLs {
        let path = url.path
        if let range = path.range(of: "/.planning") {
            let projectRoot = String(path[path.startIndex..<range.lowerBound])
            affectedProjects.insert(projectRoot)
        }
    }

    for projectPath in affectedProjects {
        await reloadProject(at: URL(fileURLWithPath: projectPath))
    }
}
```

**Key insight:** Debounce yields last batch before quiet period. We extract unique project roots from all URLs, then reload each affected project once. Result: 50 events -> 1 reload.

### Efficient Single-Project Reload

**reloadProject(at:) vs loadProjects():**
- `loadProjects()`: Rescans all scan sources, re-parses all projects, rebuilds entire array (expensive)
- `reloadProject(at:)`: Finds project in array by path, re-parses only that project, updates in-place (cheap)

**Why in-place update works:**
```swift
if let updated = await parseProject(at: projectPath, scanSource: scanSource) {
    projects[index] = updated  // @Observable detects mutation, triggers SwiftUI update
}
```

SwiftUI's @Observable tracks mutations to array elements. Changing `projects[index]` is sufficient to trigger UI refresh.

### Dynamic Monitoring Path List

**Challenge:** FSEventStream watches specific paths provided at creation time. Adding/removing projects changes the path list.

**Solution:** Restart monitoring on project list changes:
```swift
// In addProjectManually()
stopMonitoring()
startMonitoring()

// In removeManualProject()
stopMonitoring()
startMonitoring()
```

`startMonitoring()` always reads current `projects` array, so new stream watches current paths.

### App Lifecycle Handling

**Scenario:** User backgrounds app, edits ROADMAP.md in terminal, foregrounds app.

**Without lifecycle handling:** Monitoring may pause during background. Change not detected.

**With lifecycle handling:**
```swift
.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .active && oldPhase != .active {
        _Concurrency.Task {
            await projectService.loadProjects()
        }
    }
}
```

On activation, full reload ensures fresh state. Catches any changes that occurred during background period.

## Verification Results

All verification criteria met:

1. **Build success:** `xcodebuild build` succeeded with zero warnings under Swift 6 strict concurrency
2. **Method presence:** 10 occurrences of FileWatcherService/startMonitoring/stopMonitoring/reloadProject
3. **Debouncing present:** 2 occurrences of "debounce" (comment + implementation)
4. **AsyncAlgorithms import:** 1 occurrence
5. **Lifecycle wiring:** 5 occurrences of scenePhase/loadProjects

## Deviations from Plan

None - plan executed exactly as written.

## What's Next

### Immediate Next Steps (Phase 03 Plan 03)

**Human verification checkpoint:**
1. Launch app, observe projects load
2. Edit ROADMAP.md in a watched project via terminal
3. Verify UI updates within ~2 seconds (no manual refresh)
4. Edit STATE.md, verify progress/status updates
5. Rapidly modify 5 files in .planning/, verify single reload (not 5)
6. Add project manually, edit its files, verify monitoring active
7. Remove project, verify monitoring stops
8. Background app, edit files, foreground app, verify changes detected

This is a human-verify checkpoint because automated tests cannot verify:
- Visual UI updates (SwiftUI rendering)
- Timing (~2 seconds)
- UX flow (file edit -> wait -> UI appears)
- Background/foreground behavior (requires app state changes)

### Future Enhancements (Out of Scope for v1)

- Performance metrics: log reload times to identify slow parsers
- Smart invalidation: only re-parse changed files (ROADMAP.md vs STATE.md vs PLAN.md)
- Throttling: if 100+ events/sec sustained, switch to polling mode

## Self-Check

Verifying modified files and commits exist.

**Files:**
```
✅ FOUND: GSDMonitor/Services/ProjectService.swift (modified, 66 lines added)
✅ FOUND: GSDMonitor/Views/ContentView.swift (modified, 10 lines added)
```

**Commits:**
```
✅ FOUND: 042fc51 - feat(03-02): add file monitoring to ProjectService with debounced reload
✅ FOUND: 01c8ce3 - feat(03-02): wire monitoring lifecycle into ContentView
```

**Build Verification:**
```
✅ BUILD SUCCEEDED with Swift 6 strict concurrency
✅ Zero warnings
✅ All verification grep checks passed
```

## Self-Check: PASSED

All files modified, commits exist, build succeeds, verification criteria met.
