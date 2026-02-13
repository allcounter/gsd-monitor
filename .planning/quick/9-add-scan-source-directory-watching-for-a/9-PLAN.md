---
phase: quick-9
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Services/ProjectService.swift
autonomous: true
must_haves:
  truths:
    - "When a new project directory with .planning/ROADMAP.md is added to ~/Developer, it appears in the sidebar automatically"
    - "When a project directory is renamed in ~/Developer, the sidebar updates automatically"
    - "When a project directory is deleted from ~/Developer, it disappears from the sidebar automatically"
  artifacts:
    - path: "GSDMonitor/Services/ProjectService.swift"
      provides: "Scan source directory watcher using second FileWatcherService"
      contains: "scanSourceWatcher"
  key_links:
    - from: "scanSourceWatcher (FileWatcherService)"
      to: "loadProjects()"
      via: "FSEvents on scan source directories triggers full rescan"
      pattern: "scanSourceWatcher"
---

<objective>
Add a second FileWatcherService to ProjectService that watches scan source directories (e.g. ~/Developer) for top-level directory changes. When directories are created, deleted, or renamed inside scan sources, trigger a full loadProjects() rescan so new/removed/renamed projects appear automatically.

Purpose: Currently the app only watches .planning/ directories of already-known projects. If a user adds a new project to ~/Developer or renames one, the app doesn't notice until manually refreshed.
Output: ProjectService.swift with scanSourceWatcher that triggers automatic rescan on directory changes in scan sources.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Services/ProjectService.swift
@GSDMonitor/Services/FileWatcherService.swift
@GSDMonitor/Services/ProjectDiscoveryService.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add scan source directory watcher to ProjectService</name>
  <files>GSDMonitor/Services/ProjectService.swift</files>
  <action>
Add a second FileWatcherService and monitoring task to ProjectService for watching scan source directories:

1. Add new properties alongside existing ones:
   - `private let scanSourceWatcher = FileWatcherService()` (separate from `fileWatcher` which watches .planning/ dirs)
   - `private var scanSourceMonitoringTask: _Concurrency.Task<Void, Never>?`

2. Create `startScanSourceMonitoring()` method:
   - Watches `scanSources` URLs (the parent directories like ~/Developer)
   - Uses `scanSourceWatcher.watch(paths: scanSources)` to get an AsyncStream
   - Debounces events with `.debounce(for: .seconds(2))` — use a longer debounce than .planning/ watcher (2s vs 1s) since directory operations like git clone can create many events
   - On each event, call `await loadProjects()` to do a full rescan
   - Important: Do NOT filter events by path — any change in a scan source directory could mean a new/removed project

3. Update `loadProjects()`:
   - At the end, after `startMonitoring()` (which watches .planning/ dirs), also call `startScanSourceMonitoring()`
   - But only start scan source monitoring if it's not already running (check `scanSourceMonitoringTask != nil`), to avoid restarting it on every loadProjects() call which would cause an infinite loop since scan source watcher triggers loadProjects()

4. Update `stopMonitoring()`:
   - Also cancel `scanSourceMonitoringTask` and call `scanSourceWatcher.stopWatching()`

5. The key design consideration: avoid infinite loops. When loadProjects() is called from the scan source watcher, it calls startMonitoring() which restarts the .planning/ watcher (that's fine), but it must NOT restart the scan source watcher. Guard with: `if scanSourceMonitoringTask == nil { startScanSourceMonitoring() }`.

6. Update `addProjectManually()` and `removeManualProject()` — their stopMonitoring()/startMonitoring() calls should also handle the scan source watcher. But since scan sources don't change when manually adding/removing projects, the scan source watcher can just keep running. The existing stopMonitoring() will stop both, and loadProjects() restart will handle both via the nil-check guard.

Wait — actually simpler approach: Don't restart scan source watcher from loadProjects() at all. Instead, start it once from loadProjects() on first call, and only restart it if scanSources actually change. Refactor:

- In `loadProjects()`: after `startMonitoring()`, add `startScanSourceMonitoringIfNeeded()`
- `startScanSourceMonitoringIfNeeded()` checks if `scanSourceMonitoringTask == nil`, and if so, starts it
- `stopMonitoring()` stops both watchers and sets both tasks to nil
- In `addProjectManually()` and `removeManualProject()`: change from stopMonitoring()/startMonitoring() to just stop+restart the .planning/ file watcher only (since scan sources haven't changed). Or simplify: let them continue calling stopMonitoring() which stops everything, and loadProjects() will restart everything. Actually the current code for addProjectManually doesn't call loadProjects() — it manually appends the project then calls stopMonitoring()/startMonitoring(). So it needs to also restart scan source monitoring. The simplest fix: make stopMonitoring() stop both, and add a separate method or just inline the restart.

Simplest correct approach:
- `stopMonitoring()` stops both watchers (existing behavior extended)
- `startMonitoring()` only starts .planning/ watcher (existing behavior unchanged)
- New `startScanSourceMonitoring()` starts scan source watcher
- `loadProjects()` calls both at the end, but guards scan source with nil-check
- `addProjectManually()` and `removeManualProject()` call stopMonitoring() (stops both), then startMonitoring() (restarts .planning/ only) + startScanSourceMonitoring() (restarts scan source)

Actually even simpler: just put the nil-check guard inside startScanSourceMonitoring() itself. Then loadProjects() always calls it, addProjectManually()/removeManualProject() always call it after stopMonitoring(), and it's idempotent.

Final approach:
```swift
private let scanSourceWatcher = FileWatcherService()
private var scanSourceMonitoringTask: _Concurrency.Task<Void, Never>?

func startScanSourceMonitoring() {
    // Already running — don't restart (prevents infinite loop from loadProjects -> watcher -> loadProjects)
    guard scanSourceMonitoringTask == nil else { return }

    let paths = scanSources
    guard !paths.isEmpty else { return }

    let eventStream = scanSourceWatcher.watch(paths: paths)

    scanSourceMonitoringTask = _Concurrency.Task {
        for await _ in eventStream.debounce(for: .seconds(2)) {
            await loadProjects()
        }
    }
}

func stopMonitoring() {
    monitoringTask?.cancel()
    monitoringTask = nil
    fileWatcher.stopWatching()

    scanSourceMonitoringTask?.cancel()
    scanSourceMonitoringTask = nil
    scanSourceWatcher.stopWatching()
}
```

In `loadProjects()`, after `startMonitoring()`, add:
```swift
startScanSourceMonitoring()
```

In `addProjectManually()` and `removeManualProject()`, after the existing `stopMonitoring()` / `startMonitoring()` pair, add:
```swift
startScanSourceMonitoring()
```
  </action>
  <verify>
Build the project from terminal:
```
cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5
```
Verify no compile errors. The build should succeed with zero errors.
  </verify>
  <done>
ProjectService has a second FileWatcherService (`scanSourceWatcher`) that watches scan source directories. When directories change in scan sources, loadProjects() is called automatically. The watcher uses a nil-check guard to prevent infinite restart loops. Build succeeds.
  </done>
</task>

<task type="auto">
  <name>Task 2: Build and run the app</name>
  <files></files>
  <action>
Build and run the app from terminal to verify it works:

```bash
cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -20
```

If build succeeds, open the app:
```bash
open ./.build/Build/Products/Debug/GSDMonitor.app 2>/dev/null || open "$(xcodebuild -scheme GSDMonitor -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')/GSDMonitor.app"
```

If the build product path isn't obvious, use:
```bash
xcodebuild -scheme GSDMonitor -destination 'platform=macOS' -configuration Debug build 2>&1 | grep -i "BUILD SUCCEEDED"
```
And then launch via `open` on the derived data build product.
  </action>
  <verify>App builds without errors and launches successfully.</verify>
  <done>GSDMonitor app builds and runs with the new scan source directory watching feature active.</done>
</task>

</tasks>

<verification>
- ProjectService.swift compiles with the new scanSourceWatcher
- No infinite loops: loadProjects() -> startScanSourceMonitoring() is guarded by nil-check
- Both watchers are properly cleaned up in stopMonitoring()
- App builds and runs
</verification>

<success_criteria>
- New FileWatcherService watches scan source directories (e.g. ~/Developer)
- Directory changes in scan sources trigger automatic loadProjects() rescan
- No infinite loop between watcher events and loadProjects()
- Existing .planning/ directory watching continues to work unchanged
- App builds and runs successfully
</success_criteria>

<output>
After completion, create `.planning/quick/9-add-scan-source-directory-watching-for-a/9-SUMMARY.md`
</output>
