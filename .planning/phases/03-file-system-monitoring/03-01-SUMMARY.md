---
phase: 03-file-system-monitoring
plan: 01
subsystem: file-system-monitoring
tags: [fsevents, async-stream, concurrency, swift-6]
dependency_graph:
  requires: []
  provides:
    - FileWatcherService with FSEvents AsyncStream wrapper
    - swift-async-algorithms SPM dependency
  affects:
    - ProjectService (future integration point)
tech_stack:
  added:
    - swift-async-algorithms 1.1.2
    - CoreServices.FSEvents C API
  patterns:
    - AsyncStream wrapper for C callback API
    - nonisolated(unsafe) for FSEventStreamRef lifecycle
    - Dispatch queue scheduling over deprecated CFRunLoop
key_files:
  created:
    - GSDMonitor/Services/FileWatcherService.swift
  modified:
    - GSDMonitor.xcodeproj/project.pbxproj
decisions:
  - title: Use FSEventStreamSetDispatchQueue over FSEventStreamScheduleWithRunLoop
    rationale: Deprecated in macOS 13.0, modern API uses dispatch queues
    outcome: No deprecation warnings, cleaner integration with Swift concurrency
  - title: Mark stream as nonisolated(unsafe)
    rationale: FSEventStreamRef is an opaque pointer, safe to access in deinit for cleanup
    outcome: Allows deinit cleanup without async isolation issues
  - title: Filter .git/ paths in callback not in stream consumption
    rationale: Early filtering reduces event propagation to AsyncStream consumers
    outcome: Prevents event storms before they reach application logic
metrics:
  duration_minutes: 2
  tasks_completed: 1
  files_created: 1
  files_modified: 1
  completed: 2026-02-13
---

# Phase 3 Plan 01: FileWatcherService Foundation Summary

**One-liner:** FSEvents C API wrapped in Swift 6 AsyncStream with .git/ filtering and proper Stop-Invalidate-Release cleanup sequence

## What Was Built

Created FileWatcherService that bridges macOS FSEvents C API with Swift 6 strict concurrency using AsyncStream. The service provides a clean async interface for watching .planning/ directories while handling the complexity of C callbacks, memory management, and event filtering.

### Core Components

**FileWatcherService.swift (153 lines)**
- `watch(paths: [URL]) -> AsyncStream<[URL]>` - Creates FSEventStream with 1-second latency, yields changed URLs via AsyncStream
- `stopWatching()` - Executes three-step cleanup: FSEventStreamStop → FSEventStreamInvalidate → FSEventStreamRelease
- `updatePaths(_ paths: [URL])` - Stops current stream and creates new one with updated paths
- C callback `fsEventsCallback` - Filters .git/ paths before yielding to continuation

**SPM Integration**
- Added swift-async-algorithms 1.1.2 dependency to GSDMonitor.xcodeproj
- AsyncAlgorithms product linked to GSDMonitor target
- Available for future debouncing implementation

## Implementation Details

### FSEvents Configuration
- **Latency:** 1.0 second (Apple's recommended starting point)
- **Flags:** `kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer`
  - UseCFTypes: Callback receives NSArray instead of C array (easier Swift interop)
  - NoDefer: First event fires immediately, no waiting
- **Since When:** `FSEventsGetCurrentEventId()` (only future events, not historical)
- **Scheduling:** `FSEventStreamSetDispatchQueue(DispatchQueue.main)` (modern API, no deprecation warnings)

### Swift 6 Concurrency Safety

**Challenge:** FSEvents callback is a C function pointer that runs on internal FSEvents thread, cannot capture Swift values or access @MainActor state.

**Solution:**
1. Allocate `UnsafeMutablePointer<AsyncStream.Continuation>` to pass continuation to C callback
2. Pass pointer via `FSEventStreamContext.info` parameter
3. Callback retrieves continuation, filters paths, yields events
4. Mark `stream` as `nonisolated(unsafe)` for deinit cleanup access
5. Deallocate pointer in stopWatching() and deinit

**Result:** Zero Swift 6 concurrency warnings, compile-time safety for data races.

### .git/ Filtering

Implemented in callback before AsyncStream yield:
```swift
if path.contains("/.git/") {
    continue
}
```

**Rationale:** Git commits create 50-200 events in .git/objects/. Early filtering prevents these from propagating to AsyncStream consumers, reducing UI churn.

## Verification Results

✅ All verification steps passed:
1. `xcodebuild -resolvePackageDependencies` confirmed swift-async-algorithms @ 1.1.2 resolved
2. `xcodebuild build` succeeded with zero warnings under Swift 6 strict concurrency
3. 11 occurrences of FSEvents lifecycle methods (Create, Stop, Invalidate, Release in multiple locations)
4. 2 occurrences of .git/ filtering (comment + implementation)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] FSEventStreamScheduleWithRunLoop deprecation**
- **Found during:** Initial build after file creation
- **Issue:** `FSEventStreamScheduleWithRunLoop` deprecated in macOS 13.0, compiler warning
- **Fix:** Replaced with `FSEventStreamSetDispatchQueue(DispatchQueue.main)`
- **Files modified:** GSDMonitor/Services/FileWatcherService.swift
- **Commit:** f733a4d (included in main task commit)

**2. [Rule 1 - Bug] Swift 6 deinit isolation error**
- **Found during:** First build attempt
- **Issue:** `deinit` is nonisolated, cannot call @MainActor stopWatching() or access stream property
- **Fix:**
  - Marked `stream` as `nonisolated(unsafe)` (FSEventStreamRef is opaque pointer, safe for deinit access)
  - Duplicated cleanup code in deinit directly instead of calling stopWatching()
- **Files modified:** GSDMonitor/Services/FileWatcherService.swift
- **Commit:** f733a4d (included in main task commit)

**Rationale:** Both issues were blocking bugs preventing compilation. Rule 1 applies (auto-fix bugs). The deprecation fix uses the modern API Apple recommends. The deinit fix correctly handles Swift 6's stricter actor isolation while maintaining safe cleanup.

## What's Next

### Immediate Next Steps (Phase 03 Plan 02)
1. Integrate FileWatcherService into ProjectService
2. Start watching when projects are loaded/added
3. Implement debouncing with swift-async-algorithms (.debounce(for: .seconds(0.5)))
4. Re-parse and update project models when events fire
5. Verify UI updates automatically when .planning/ files change

### Future Enhancements (Out of Scope for v1)
- Performance tuning: adjust latency based on Instruments profiling
- File-level events: add `kFSEventStreamCreateFlagFileEvents` if directory-level insufficient
- Multi-stream optimization: benchmark single stream vs per-project streams

## Self-Check

Verifying created files and commits exist.

**Files:**
```
✅ FOUND: GSDMonitor/Services/FileWatcherService.swift (153 lines)
✅ FOUND: Modified GSDMonitor.xcodeproj/project.pbxproj (swift-async-algorithms package)
```

**Commits:**
```
✅ FOUND: f733a4d - feat(03-01): implement FileWatcherService with FSEvents and AsyncStream
```

**Build Verification:**
```
✅ BUILD SUCCEEDED with Swift 6 strict concurrency
✅ Zero warnings
✅ swift-async-algorithms package resolved
```

## Self-Check: PASSED

All files created, commit exists, build succeeds, verification criteria met.
