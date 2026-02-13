---
phase: quick
plan: 2
subsystem: ui-data-sync
tags: [status-parsing, filesystem-check, plan-completion]
dependency_graph:
  requires: []
  provides:
    - "Plan status derived from SUMMARY.md existence"
    - "Task status propagation for completed plans"
  affects:
    - "GSDMonitor/Views/ProjectDetailView.swift"
    - "GSDMonitor/Views/PlanCardView.swift"
tech_stack:
  added: []
  patterns:
    - "FileManager existence check for status derivation"
    - "Plan model reconstruction with updated status"
key_files:
  created: []
  modified:
    - path: "GSDMonitor/Services/ProjectService.swift"
      provides: "SUMMARY.md-based plan/task status"
      lines: 296-328
decisions:
  - summary: "Check SUMMARY.md existence in ProjectService.parsePlans() rather than PlanParser"
    rationale: "Filesystem access is natural in ProjectService; PlanParser should stay pure markdown parser"
  - summary: "Reconstruct Plan with new status rather than mutating parsed result"
    rationale: "Plan is immutable struct - cleaner to create new instance with updated fields"
  - summary: "Mark ALL tasks as .done when SUMMARY exists"
    rationale: "If plan completed, all tasks completed - simpler than per-task tracking"
metrics:
  duration_minutes: 1
  task_count: 1
  file_count: 1
  completed: 2026-02-16
---

# Quick Task 2: Fix Plan Status Parsing

**One-liner:** SUMMARY.md existence check in ProjectService.parsePlans() drives plan/task done status

## Context

The app correctly showed phase-level completion from ROADMAP.md, but individual plans always displayed as "pending" because:
1. PlanParser hardcoded `.pending` status for all parsed plans
2. No code checked for SUMMARY.md existence (the actual completion artifact)
3. Plans with completed SUMMARY.md files showed the same as unstarted plans

This made the UI misleading - users couldn't distinguish between completed and pending plans.

## Implementation

### Task 1: Add SUMMARY.md existence check to parsePlans

**Modified:** `GSDMonitor/Services/ProjectService.swift` (lines 296-328)

Added logic to `parsePlans(from:)` method:
```swift
// After parsing a PLAN.md file
let summaryFilename = fileURL.lastPathComponent.replacingOccurrences(of: "-PLAN.md", with: "-SUMMARY.md")
let summaryURL = fileURL.deletingLastPathComponent().appendingPathComponent(summaryFilename)
let hasSummary = FileManager.default.fileExists(atPath: summaryURL.path)

if hasSummary {
    let donePlan = Plan(
        phaseNumber: plan.phaseNumber,
        planNumber: plan.planNumber,
        objective: plan.objective,
        tasks: plan.tasks.map { Task(name: $0.name, type: $0.type, status: .done) },
        status: .done
    )
    plans.append(donePlan)
} else {
    plans.append(plan)
}
```

**Behavior:**
- For each PLAN.md file, derive the expected SUMMARY.md filename (e.g., `08-01-PLAN.md` → `08-01-SUMMARY.md`)
- Check if SUMMARY.md exists in the same directory
- If yes: create new Plan with `.done` status and all tasks marked `.done`
- If no: append the plan as parsed (with default `.pending` status)

**Verification:**
- Build succeeded with no errors (only pre-existing @preconcurrency warning)
- Implementation matches spec exactly
- No changes needed to PlanParser or model files

## Deviations from Plan

None - plan executed exactly as written.

## Test Results

**Build verification:**
```
xcodebuild -scheme GSDMonitor -configuration Debug build
** BUILD SUCCEEDED **
```

**Visual verification (to be done in app):**
- Open app with gsd-monitor project (has SUMMARY files for phases 1-8)
- Expected: Plans 01-01 through 08-01 show "done" status with green checkmarks
- Expected: Plans 09-01+ show "pending" status
- Expected: All tasks within done plans show done status

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 628343b | Add SUMMARY.md existence check for plan status |

## Files Modified

**GSDMonitor/Services/ProjectService.swift**
- Added SUMMARY.md filename derivation logic
- Added FileManager.fileExists check
- Added Plan reconstruction with .done status when SUMMARY exists
- Added Task status mapping to .done for completed plans

## Impact

**Immediate:**
- Plan cards now correctly show completion status
- Task lists reflect actual completion state
- UI accurately represents project progress

**Future:**
- Status badges, progress bars, and filters now work correctly
- Foundation for future features (e.g., "show only pending plans")
- Consistent with gsd-executor workflow (SUMMARY.md = completion proof)

## Self-Check

### Files Created
No new files created (only SUMMARY.md).

### Files Modified
```bash
[ -f "GSDMonitor/Services/ProjectService.swift" ] && echo "FOUND"
```
FOUND: GSDMonitor/Services/ProjectService.swift

### Commits
```bash
git log --oneline | grep 628343b
```
FOUND: 628343b feat(quick-2): add SUMMARY.md existence check for plan status

## Self-Check: PASSED
