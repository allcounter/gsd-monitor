---
phase: quick-26
plan: 01
subsystem: UI/Dashboard
tags: [close-button, header, borderedProminent, PhaseDetailView]
dependency_graph:
  requires: []
  provides: [phase-detail-close-button-in-header]
  affects: [PhaseDetailView, DetailView]
tech_stack:
  added: []
  patterns: [borderedProminent button style, background modifier for hidden keyboard shortcut]
key_files:
  created: []
  modified:
    - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
decisions:
  - Moved Close button into header HStack (after StatusBadge) to eliminate floating overlay offset hacks
  - Used .background modifier for hidden Cancel/Escape button to keep it out of layout flow
metrics:
  duration: "56s"
  completed: "2026-02-17"
  tasks_completed: 2
  files_modified: 1
---

# Phase Quick-26 Plan 01: Revert Close Button to Header borderedProminent Summary

**One-liner:** Replaced floating xmark.circle.fill overlay close button with an inline borderedProminent "Close" button in the PhaseDetailView header HStack, eliminating all offset hacks.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Replace floating close button with header borderedProminent Close button | 8eca060 | GSDMonitor/Views/Dashboard/PhaseDetailView.swift |
| 2 | Verify DetailView overlay centering is correct | (no change) | GSDMonitor/Views/DetailView.swift (verified, no edits needed) |

## Changes Made

### Task 1: Replace floating close button

**PhaseDetailView.swift:**
- Removed outer `ZStack(alignment: .topTrailing)` wrapper — VStack is now the top-level container in `body`
- Removed floating close button block: `Button { xmark.circle.fill }` with `.buttonStyle(.plain)`, `.padding(16)`, `.offset(x: 12, y: -12)`
- Added `Button("Close") { onDismiss() }` with `.buttonStyle(.borderedProminent)` and `.controlSize(.regular)` and `.keyboardShortcut(.defaultAction)` after `StatusBadge` in the header HStack
- Moved hidden Cancel button (Escape key) to `.background { Button("Cancel") ... .keyboardShortcut(.cancelAction).hidden() }` on the outermost VStack

### Task 2: Verify DetailView overlay centering

Confirmed all three conditions correct — no changes needed:
1. `Color.black.opacity(0.3).ignoresSafeArea()` at line 162 — backdrop covers full window
2. Centering VStack + HStack with `.frame(maxWidth: .infinity, maxHeight: .infinity).ignoresSafeArea()` at line 179
3. Overlay block is outside `if let project` — in the outermost ZStack

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] PhaseDetailView.swift modified and committed (8eca060)
- [x] Build succeeded: `BUILD SUCCEEDED`
- [x] No `xmark.circle.fill` in PhaseDetailView.swift
- [x] No `ZStack(alignment: .topTrailing)` in PhaseDetailView.swift
- [x] Contains `.buttonStyle(.borderedProminent)`
- [x] Contains `.controlSize(.regular)`
- [x] Contains `.keyboardShortcut(.cancelAction)` (Escape key preserved)
- [x] DetailView.swift overlay structure confirmed correct (2x ignoresSafeArea)
