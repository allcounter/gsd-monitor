---
phase: 15-command-triggering-integration
plan: "03"
subsystem: ui-history
tags: [command-history, fsevent-suppression, detail-view, swift-ui]
requirements-completed: [TRIG-04, SAFE-02]
dependency_graph:
  requires:
    - 15-01  # CommandRunnerService, activeRuns, recentRuns observable state
    - 15-02  # CommandRunnerService.rerun(), loadHistory()
  provides:
    - CommandHistoryView: dedicated history tab in DetailView
    - FSEvents suppression: prevents reload flicker during active commands
  affects:
    - DetailView.swift: added Dashboard/History tab picker
    - ProjectService.swift: FSEvents reload gate using activeRuns
    - ContentView.swift: wires commandRunner to projectService before load
tech_stack:
  added:
    - Views/History/CommandHistoryView.swift (new file)
  patterns:
    - .task + .onChange(of: recentRuns.count) for live history reload
    - commandRunner?.activeRuns[projectPath] != nil continue pattern for FSEvents gate
    - @ViewBuilder dashboardContent() to extract left-pane content without refactor
key_files:
  created:
    - GSDMonitor/Views/History/CommandHistoryView.swift
  modified:
    - GSDMonitor/Views/DetailView.swift
    - GSDMonitor/Services/CommandHistoryStore.swift
    - GSDMonitor/Services/ProjectService.swift
    - GSDMonitor/Views/ContentView.swift
    - GSDMonitor.xcodeproj/project.pbxproj
decisions:
  - dashboardContent() @ViewBuilder helper: avoids duplicating the large dashboard VStack inside a switch; keeps DetailView body legible while enabling tab switching
  - FSEvents gate as property not parameter: commandRunner stored as var on ProjectService avoids changing startMonitoring() signature and breaking addProjectManually/removeManualProject call sites
  - scenePhase handler also re-sets commandRunner: ensures SAFE-02 stays active if app was backgrounded and re-launched
metrics:
  duration: 3 minutes
  completed: "2026-02-18"
  tasks_completed: 2
  files_modified: 5
  files_created: 1
---

# Phase 15 Plan 03: Command History View and FSEvents Suppression Summary

CommandHistoryView with expandable rows, re-run button, and tab integration into DetailView, plus FSEvents reload suppression (SAFE-02) during active command execution via projectService.commandRunner gate.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Create CommandHistoryView and integrate into DetailView | db67074 | CommandHistoryView.swift, DetailView.swift, project.pbxproj |
| 2 | Trim history to 50 and add FSEvents suppression gate | 81e4723 | CommandHistoryStore.swift, ProjectService.swift, ContentView.swift |

## What Was Built

### CommandHistoryView

New file at `GSDMonitor/Views/History/CommandHistoryView.swift`:
- `CommandHistoryView`: loads history on `.task`, reloads on `recentRuns.count` changes, shows `ContentUnavailableView` when empty, otherwise `List(history)` with `.listStyle(.plain)`
- `CommandHistoryRow` (private): compact HStack showing command display name (slash command extracted from arguments), HH:mm timestamp, and success/fail/cancelled/running/queued badge
- Expandable section: full command string, duration formatted as "Xm Ys", exit code with color coding, output preview (first 20 lines, monospaced, scrollable), Re-run button with `.tint(Theme.accent)`
- Transition: `.opacity.combined(with: .move(edge: .top))`

### DetailView Tab Switcher

- `DetailTab` enum (Dashboard/History) at file scope
- `@SwiftUI.State private var detailTab: DetailTab = .dashboard` added
- Segmented `Picker` at top of left pane with `.padding(.horizontal).padding(.top, 8).padding(.bottom, 4)`
- `dashboardContent(for:)` @ViewBuilder extracts the existing dashboard VStack
- `CommandHistoryView(project: project)` for history tab

### FSEvents Suppression (SAFE-02)

`ProjectService.commandRunner: CommandRunnerService?` property added. In `startMonitoring()` loop:
```swift
if let runner = commandRunner, runner.activeRuns[projectPath] != nil {
    continue  // Skip — FSEvents will fire again after command completes
}
```
`ContentView` sets `projectService.commandRunner = commandRunnerService` before `await projectService.loadProjects()`.

### History Limit

`CommandHistoryStore.maxRunsPerProject` changed from 200 to 50.

## Verification

1. Build succeeds with no errors
2. DetailView shows Dashboard/History segmented picker
3. History tab loads command runs per project from disk
4. CommandHistoryRow shows command name, HH:mm timestamp, success/fail badge
5. Tapping row expands to show output preview and Re-run button
6. Re-run button calls `commandRunner.rerun(run)` which enqueues a new `CommandRequest`
7. History reloads on `.onChange(of: commandRunner.recentRuns.count)`
8. `CommandHistoryStore.maxRunsPerProject == 50`
9. `ProjectService.startMonitoring()` skips reload when `commandRunner.activeRuns[projectPath] != nil`
10. After command ends, `activeRuns` is cleared and next FSEvents event triggers reload normally

## Deviations from Plan

None — plan executed exactly as written. The `commandRunner` property approach (not a parameter to `startMonitoring()`) was chosen as specified in the plan's "Alternative (simpler)" option.

## Self-Check: PASSED

Files created:
- GSDMonitor/Views/History/CommandHistoryView.swift: present
- .planning/phases/15-command-triggering-integration/15-03-SUMMARY.md: present

Commits:
- db67074: Task 1 (CommandHistoryView + DetailView)
- 81e4723: Task 2 (history trim + FSEvents suppression)
