---
phase: quick-25
plan: 25
subsystem: UI/Dashboard
tags: [close-button, layout, PhaseDetailView, offset]
dependency_graph:
  requires: []
  provides: [non-overlapping close button in PhaseDetailView]
  affects: [PhaseDetailView]
tech_stack:
  added: []
  patterns: [SwiftUI .offset modifier for floating button placement]
key_files:
  modified:
    - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
decisions:
  - Use .offset(x: 12, y: -12) to push button outside the ZStack's card boundary at top-right corner
metrics:
  duration: ~2 minutes
  completed: 2026-02-17
---

# Phase quick-25: Fix Close Button Overlap Offset Summary

**One-liner:** Offset the xmark.circle.fill button 12pt right and 12pt up with .offset(x: 12, y: -12) so it floats at the card's top-right corner edge instead of overlapping StatusBadge and Open in Editor button.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Offset close button outside card and increase padding | 245c13e | GSDMonitor/Views/Dashboard/PhaseDetailView.swift |

## Changes Made

In `PhaseDetailView.swift`, the floating close button modifier chain was updated:

**Before:**
```swift
.buttonStyle(.plain)
.padding(12)
.keyboardShortcut(.defaultAction)
```

**After:**
```swift
.buttonStyle(.plain)
.padding(16)
.offset(x: 12, y: -12)
.keyboardShortcut(.defaultAction)
```

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- File modified: GSDMonitor/Views/Dashboard/PhaseDetailView.swift — FOUND
- Commit 245c13e — FOUND
- Build: SUCCEEDED
