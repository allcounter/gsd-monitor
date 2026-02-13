---
phase: quick-21
plan: 01
subsystem: ui
tags: [animation, gradient, progress-bar, sidebar, detail-view]
dependency_graph:
  requires: []
  provides: [faster-overlay-animation, gradient-overall-progress, gradient-sidebar-rows]
  affects: [DetailView, SidebarView]
tech_stack:
  added: []
  patterns: [AnimatedProgressBar reuse, LinearGradient fill]
key_files:
  created: []
  modified:
    - GSDMonitor/Views/DetailView.swift
    - GSDMonitor/Views/SidebarView.swift
decisions:
  - Use 0.15 opacity for sidebar gradient hint — subtle enough for unselected rows to stay clean
  - Height 6 for AnimatedProgressBar in DetailView — matches default and existing usage
metrics:
  duration: "53s"
  completed: "2026-02-17"
  tasks_completed: 2
  files_modified: 2
---

# Phase quick-21 Plan 01: Faster Animation, Gradient Sidebar, Overall Progress Bar Summary

**One-liner:** Snappier 0.12s overlay animation, gradient AnimatedProgressBar for overall progress, and per-project color gradient fill on selected sidebar rows.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Faster overlay animation and gradient overall progress bar in DetailView | 53d9b9f | GSDMonitor/Views/DetailView.swift |
| 2 | Add gradient background to sidebar project row elements | 8a935d8 | GSDMonitor/Views/SidebarView.swift |

## Changes Made

### Task 1 — DetailView.swift

**Faster overlay animation:**
- Line 151: `.animation(.easeInOut(duration: 0.2), ...)` changed to `.animation(.easeInOut(duration: 0.12), ...)`

**Gradient progress bar:**
- Replaced `ProgressView(value:).progressViewStyle(.linear).tint(...)` with `AnimatedProgressBar(progress:barColor:height:gradient:)` using a `LinearGradient` from the project's `.dark` to `.bright` color. This eliminates the last remaining system ProgressView from DetailView.

### Task 2 — SidebarView.swift

**Gradient sidebar row background:**
- Changed `.fill(isSelected ? Theme.bg2 : Theme.bg1)` to a `LinearGradient` fill on the `RoundedRectangle`.
- When selected: left edge is `Theme.bg2`, right edge is `colorPair.dark.opacity(0.15)` — a subtle hint of the project's assigned color.
- When unselected: plain `Theme.bg1` on both ends (no visible gradient), keeping the clean non-selected look.

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `xcodebuild` — BUILD SUCCEEDED (both tasks verified)
- PhaseDetailView overlay animation is now 0.12s (was 0.2s)
- Overall progress bar in DetailView uses AnimatedProgressBar with gradient fill
- Sidebar project rows show subtle gradient hint of project color when selected

## Self-Check: PASSED

- `./GSDMonitor/Views/DetailView.swift` — FOUND
- `./GSDMonitor/Views/SidebarView.swift` — FOUND
- Commit `53d9b9f` — FOUND
- Commit `8a935d8` — FOUND
