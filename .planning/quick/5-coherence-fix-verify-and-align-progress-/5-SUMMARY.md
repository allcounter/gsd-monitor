---
phase: quick-5
plan: 01
subsystem: ui-coherence
tags: [progress-calculation, ui-polish, data-alignment]
dependencies:
  requires: [quick-4]
  provides: [weighted-progress-calculation]
  affects: [DetailView, SidebarView]
tech-stack:
  added: []
  patterns: [plan-weighted-progress, immutable-data-flow]
key-files:
  created: []
  modified:
    - GSDMonitor/Views/DetailView.swift
    - GSDMonitor/Views/SidebarView.swift
decisions:
  - Use plan completion data for weighted phase contributions (0.0-1.0 per phase)
  - Done phases contribute 1.0, in-progress phases contribute (donePlans/totalPlans)
  - Phases with no plan data contribute 0.0 (unless marked .done)
  - Identical calculation logic in both DetailView and SidebarView for consistency
metrics:
  duration: 77s
  completed: 2026-02-16T01:46:18Z
---

# Quick Task 5: Coherence - Fix, Verify, and Align Progress Summary

**One-liner:** Weighted overall progress using plan-level completion data for smooth, accurate reporting across DetailView and SidebarView

## Objective

Make overall project progress calculations use plan-level completion data instead of phase-only counting, providing smooth and accurate progress reporting. Previously, a project at phase 8/12 with the current phase 80% complete showed 58% (7/12 phases done) instead of ~65%. Now progress reflects partial phase completion.

## Tasks Completed

### Task 1: Implement weighted overall progress in DetailView and SidebarView ✓

**Files modified:**
- `GSDMonitor/Views/DetailView.swift`
- `GSDMonitor/Views/SidebarView.swift`

**Changes:**

**DetailView.swift:**
- Replaced `completedPhases(in:)` and `overallCompletionPercentage(for:)` with single `overallProgress(for:) -> Double` method
- New method uses plan-weighted calculation: done phases contribute 1.0, in-progress phases contribute (donePlans/totalPlans)
- Updated ProgressView to use `overallProgress(for: project)` instead of `Double(completedPhases) / Double(totalPhases)`
- Updated percentage text to use `Int(overallProgress(for: project) * 100)`

**SidebarView.swift:**
- Updated `progressValue()` and `progressPercentage()` in ProjectRow to use identical weighted calculation
- Changed methods to access `project.plans` directly instead of just counting done phases
- Removed unused `roadmap` parameter (now accesses via `project.roadmap`)
- Fixed compiler warning about unused `roadmap` binding by changing to nil check

**Weighted calculation logic:**
```swift
let phaseContributions = roadmap.phases.map { phase -> Double in
    if phase.status == .done { return 1.0 }
    let phasePlans = plans.filter { $0.phaseNumber == phase.number }
    guard !phasePlans.isEmpty else { return 0.0 }
    let done = phasePlans.filter { $0.status == .done }.count
    return Double(done) / Double(phasePlans.count)
}
return phaseContributions.reduce(0, +) / Double(roadmap.phases.count)
```

**Verification:**
- Build succeeded without errors
- Both views use identical calculation logic
- PhaseCardView remains unchanged (its plan-level progress within a single phase is already correct)
- Progress values are now continuous (not jumping in full-phase increments)

**Commit:** `aa87a30`

## Deviations from Plan

None - plan executed exactly as written.

## Outcomes

**Before:**
- Overall progress counted only fully-done phases
- A project with 7 done phases and 1 phase at 50% plan completion (out of 12 total) showed 58% (7/12)
- Progress jumped in phase-sized increments (8.33% per phase for a 12-phase project)

**After:**
- Overall progress reflects partial phase completion via plan data
- Same project now shows ~62% ((7 × 1.0 + 0.5) / 12 = 62.5%)
- Progress increases smoothly as individual plans complete
- Sidebar and DetailView show identical values for the same project

**Impact:**
- More accurate representation of actual project progress
- Better user feedback during long phases with multiple plans
- Consistent progress display across all UI components
- Users see continuous progress instead of phase-sized jumps

## Verification

✓ Build succeeds without errors
✓ DetailView and SidebarView use identical progress calculation logic
✓ PhaseCardView unchanged (plan-level progress within phase already correct)
✓ Progress values are continuous and weighted by plan completion
✓ Compiler warnings resolved (unused roadmap binding)

## Self-Check: PASSED

**Created files:**
```
FOUND: .planning/quick/5-coherence-fix-verify-and-align-progress-/5-SUMMARY.md
```

**Modified files:**
```
FOUND: GSDMonitor/Views/DetailView.swift
FOUND: GSDMonitor/Views/SidebarView.swift
```

**Commits:**
```
FOUND: aa87a30
```

**Unchanged files (as required):**
```
VERIFIED: GSDMonitor/Views/Dashboard/PhaseCardView.swift - not in git status
```

All verification checks passed.
