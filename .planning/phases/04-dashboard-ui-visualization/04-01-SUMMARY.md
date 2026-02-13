---
phase: 04-dashboard-ui-visualization
plan: 01
subsystem: "models-parsing"
tags: ["swift", "parsing", "models", "components"]
dependency_graph:
  requires: ["phase-02-file-discovery-parsing", "phase-03-file-system-monitoring"]
  provides: ["project-requirements-data", "project-plans-data", "shared-status-badge"]
  affects: ["dashboard-views", "requirement-badges", "phase-cards"]
tech_stack:
  added: []
  patterns: ["shared-components", "async-safe-enumerator-extraction"]
key_files:
  created:
    - "GSDMonitor/Views/Components/StatusBadge.swift"
  modified:
    - "GSDMonitor/Models/Project.swift"
    - "GSDMonitor/Services/ProjectService.swift"
    - "GSDMonitor/Utilities/PreviewData.swift"
    - "GSDMonitor/Views/DetailView.swift"
decisions:
  - "Extract parsePlans helper to avoid async/sync conflict with FileManager.enumerator"
  - "Use xcodeproj gem to add StatusBadge.swift to Xcode project programmatically"
metrics:
  duration_minutes: 3
  completed_date: "2026-02-13"
  task_count: 2
  file_count: 5
---

# Phase 04 Plan 01: Project Data Extension Summary

Extended Project model with requirements and plans data, wired parsing into ProjectService, and extracted StatusBadge as shared component for dashboard UI reuse.

## One-liner

Project model now carries requirements and plans arrays parsed from REQUIREMENTS.md and all PLAN.md files in phases/ subdirectories; StatusBadge extracted to Components/ for dashboard-wide reuse.

## What Was Built

### Task 1: Add requirements and plans to Project model and wire parsing

**Outcome:** Project model extended with requirements and plans properties, fully wired parsing pipeline

**Changes:**
- Added `var requirements: [Requirement]?` and `var plans: [Plan]?` to Project struct
- Updated CodingKeys, init(from decoder:), encode(to:), and manual initializer
- Wired RequirementsParser to parse REQUIREMENTS.md in ProjectService.parseProject
- Implemented plan scanning using FileManager.enumerator to find all *-PLAN.md files in .planning/phases/ subdirectories
- Extracted `parsePlans(from:)` helper method to avoid async/sync conflict with FileManager.enumerator iteration
- Added sample requirements (3) and plans (2) to PreviewData for UI testing

**Files modified:**
- `GSDMonitor/Models/Project.swift` (added 2 properties, updated all init/encode/decode methods)
- `GSDMonitor/Services/ProjectService.swift` (added parsePlans helper, wired both parsers)
- `GSDMonitor/Utilities/PreviewData.swift` (added sample requirements and plans)

**Commit:** `4af2a9d`

### Task 2: Extract StatusBadge as shared component

**Outcome:** StatusBadge now accessible from any view in the GSDMonitor module

**Changes:**
- Created `GSDMonitor/Views/Components/StatusBadge.swift` with internal visibility
- Moved StatusBadge implementation from DetailView private struct to shared component
- Preserved exact implementation: HStack with Circle + Text, statusColor, statusText, padding, background, cornerRadius
- Added StatusBadge.swift to Xcode project using Ruby xcodeproj gem
- Removed private StatusBadge declaration from DetailView.swift

**Files modified:**
- `GSDMonitor/Views/Components/StatusBadge.swift` (created)
- `GSDMonitor/Views/DetailView.swift` (removed private StatusBadge)
- `GSDMonitor.xcodeproj/project.pbxproj` (added file reference)

**Commit:** `01fae58`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed async/sync conflict with FileManager.enumerator**
- **Found during:** Task 1 - parsing plans in ProjectService.parseProject
- **Issue:** Swift 6 strict concurrency prevents iterating FileManager.enumerator in async context. Build error: "instance method 'makeIterator' is unavailable from asynchronous contexts"
- **Fix:** Extracted synchronous `parsePlans(from:)` helper method that performs enumeration outside async context
- **Files modified:** `GSDMonitor/Services/ProjectService.swift`
- **Commit:** `4af2a9d` (included in Task 1 commit)

**Rationale:** This is a blocking issue (Rule 3) - cannot complete Task 1 without fixing the async/sync violation. The fix is minimal (extract helper method) and doesn't change architecture.

## Verification

All success criteria met:

1. **Build succeeds:** `xcodebuild build` completes with zero errors
2. **Project model extended:** `requirements: [Requirement]?` and `plans: [Plan]?` properties present
3. **Parsing wired:** ProjectService.parseProject populates requirements from REQUIREMENTS.md and plans from all PLAN.md files in phases/
4. **StatusBadge shared:** Accessible from any view in GSDMonitor module (internal visibility)
5. **PreviewData compiles:** Sample requirements (3) and plans (2) included
6. **No regressions:** All existing functionality preserved (DetailView still renders phases)

## Self-Check: PASSED

**Created files:**
- FOUND: GSDMonitor/Views/Components/StatusBadge.swift

**Commits:**
- FOUND: 4af2a9d (Task 1: add requirements and plans to Project model)
- FOUND: 01fae58 (Task 2: extract StatusBadge as shared component)

**Build status:**
- BUILD SUCCEEDED (verified after Task 1 and Task 2)

## Next Steps

Ready for Phase 04 Plan 02: Phase Cards Grid View
- Can now display requirements badges on phase cards (requirements data available on Project)
- Can filter and group plans by phase (plans data available on Project)
- Can reuse StatusBadge in phase cards and requirement badges (shared component)
