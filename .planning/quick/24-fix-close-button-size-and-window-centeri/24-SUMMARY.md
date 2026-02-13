---
phase: quick
plan: 24
subsystem: ui
tags: [phase-detail, overlay, close-button, usability]
dependency_graph:
  requires: []
  provides: [larger-close-button, full-window-overlay]
  affects: [GSDMonitor/Views/Dashboard/PhaseDetailView.swift, GSDMonitor/Views/DetailView.swift]
tech_stack:
  added: []
  patterns: [ZStack top-level overlay, ignoresSafeArea centering]
key_files:
  modified:
    - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
    - GSDMonitor/Views/DetailView.swift
decisions:
  - Use top-level ZStack in DetailView body to allow overlay to cover full window area including sidebar gap
  - Use ignoresSafeArea() on both Color.black backdrop and centering VStack for true full-coverage
metrics:
  duration: 69s
  completed: 2026-02-17
---

# Phase quick Plan 24: Fix Close Button Size and Window Centering Summary

**One-liner:** Enlarged close button to .title font with 28x28 frame and fg1 color; moved phase detail overlay to top-level ZStack with ignoresSafeArea for full-window coverage.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Fix close button size and visibility in PhaseDetailView | 4871ff4 | GSDMonitor/Views/Dashboard/PhaseDetailView.swift |
| 2 | Move phase detail overlay to top-level ZStack in DetailView | 803019f | GSDMonitor/Views/DetailView.swift |

## Changes Made

### Task 1: Close Button (PhaseDetailView.swift)

- `.font(.title2)` changed to `.font(.title)` — larger icon
- `.frame(width: 28, height: 28)` added after font modifier — explicit hit target
- `.foregroundStyle(Theme.textSecondary)` changed to `.foregroundStyle(Theme.fg1)` — higher contrast, clearly visible

### Task 2: Overlay Restructure (DetailView.swift)

- Wrapped entire `body` in a top-level `ZStack`
- Moved phase detail overlay block outside `if let project` scope
- Updated overlay condition to `if let phase = selectedPhase, let project = selectedProject` (needs both bindings at top level)
- Added `.ignoresSafeArea()` to the centering `VStack` — overlay now covers full window area
- Moved `.animation(.easeInOut(duration: 0.12), value: selectedPhase?.id)` to outer ZStack

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- App builds without errors (BUILD SUCCEEDED both tasks)
- Close button uses `.font(.title)`, `.frame(width: 28, height: 28)`, `Theme.fg1`
- Overlay ZStack is at top level of DetailView body, outside `if let project`
- Both `Color.black` overlay and centering VStack have `.ignoresSafeArea()`

## Self-Check: PASSED

Files exist:
- FOUND: GSDMonitor/Views/Dashboard/PhaseDetailView.swift
- FOUND: GSDMonitor/Views/DetailView.swift

Commits exist:
- FOUND: 4871ff4
- FOUND: 803019f
