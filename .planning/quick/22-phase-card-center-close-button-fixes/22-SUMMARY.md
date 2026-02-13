---
phase: quick-22
plan: 01
subsystem: UI / PhaseDetailView overlay
tags: [layout, overlay, button, swift, swiftui]
dependency_graph:
  requires: []
  provides: [centered-phase-card-overlay, prominent-close-button]
  affects: [GSDMonitor/Views/DetailView.swift, GSDMonitor/Views/Dashboard/PhaseDetailView.swift]
tech_stack:
  added: []
  patterns: [ZStack centering via bounded frame, controlSize(.large)]
key_files:
  created: []
  modified:
    - GSDMonitor/Views/DetailView.swift
    - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
decisions:
  - Remove .frame(maxWidth: .infinity, maxHeight: .infinity) from PhaseDetailView overlay — card's own bounded frame (.frame(minWidth:580, idealWidth:620, ...)) is sufficient; ZStack centers by default
  - Use .controlSize(.large) on the Close button to increase tap target and visual prominence without custom styling
metrics:
  duration: 3 minutes
  completed: 2026-02-17
---

# Phase quick-22 Plan 01: Phase Card Center + Close Button Fixes Summary

**One-liner:** Removed stretch frame from PhaseDetailView overlay so it floats centered, renamed Done to Close with `.controlSize(.large)` for prominence.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Center card overlay and fix Close button | 035c417 | DetailView.swift, PhaseDetailView.swift |

## What Was Done

### Task 1: Center card overlay and fix Close button

**DetailView.swift (line 154):** Removed `.frame(maxWidth: .infinity, maxHeight: .infinity)` from the PhaseDetailView instance inside the ZStack overlay. The PhaseDetailView already declares its own bounded frame (`.frame(minWidth: 580, idealWidth: 620, minHeight: 500, idealHeight: 700, maxHeight: 800)`). With the stretch frame removed, the ZStack centers the card naturally — it floats as a bounded floating card over the dimmed background rather than filling the entire window.

**PhaseDetailView.swift (lines 32-37):** Renamed `Button("Done")` to `Button("Close")` and added `.controlSize(.large)` after the `.tint(Theme.blue)` modifier. This makes the button larger and more visually prominent in the header without changing color, style, or position.

## Verification

- BUILD SUCCEEDED (xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build)
- PhaseDetailView.swift contains `Button("Close")` (not `Button("Done")`)
- PhaseDetailView.swift contains `.controlSize(.large)`
- DetailView.swift's PhaseDetailView overlay no longer has `.frame(maxWidth: .infinity, maxHeight: .infinity)` (the remaining occurrence on line 133 is on `ContentUnavailableView`, unrelated)

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- [x] GSDMonitor/Views/DetailView.swift modified correctly
- [x] GSDMonitor/Views/Dashboard/PhaseDetailView.swift modified correctly
- [x] Commit 035c417 exists
- [x] Build succeeded
