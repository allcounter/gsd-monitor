---
phase: 16-configurable-scan-directories
plan: 02
subsystem: ui
tags: [swiftui, macos, popover, disclosure-group, sidebar, scan-directories]

# Dependency graph
requires:
  - 16-01 (ScanDirectoriesPopoverView, ProjectService scan methods)
provides:
  - Gear button at sidebar bottom opening ScanDirectoriesPopoverView
  - Collapsible DisclosureGroup sections per scan source in SidebarView
  - All scan sources shown (even empty) when no search/filter active
  - ~/Developer always first in sidebar sort order
affects:
  - SidebarView (main project list UI)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "expandedGroups Set<String> tracks collapsed groups (inverted: absence = expanded)"
    - ".safeAreaInset(edge: .bottom) for persistent gear button below list content"
    - "Binding<Bool> computed from Set membership for DisclosureGroup isExpanded"
    - "~/Developer special-cased first in sort (~ > all letters in ASCII)"

key-files:
  created: []
  modified:
    - GSDMonitor/Views/SidebarView.swift

key-decisions:
  - "expandedGroups tracks collapsed groups (not expanded) so all groups start expanded by default without initialization"
  - "filteredProjects includes empty scan source groups only when no search/filter active — avoids noise during search"
  - "~/Developer sorted first explicitly because ~ (ASCII 126) sorts after z (122), breaking alphabetical assumption"
  - "Gear button inside .safeAreaInset on projectList List — persists below scrollable content"

requirements-completed: [SCAN-01, SCAN-02, SCAN-03, SCAN-04]

# Metrics
duration: ~2min
completed: 2026-02-21
---

# Phase 16 Plan 02: Gear Button and Collapsible Sidebar Sections Summary

**Gear icon at sidebar bottom opens ScanDirectoriesPopoverView; sidebar projects grouped by scan source in collapsible DisclosureGroup sections with ~/Developer always first**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-02-21T08:11:44Z
- **Completed:** 2026-02-21T08:13:xx Z
- **Tasks:** 1 auto + 1 checkpoint:human-verify
- **Files modified:** 1 (SidebarView.swift)

## Accomplishments

- SidebarView now has a gear icon button fixed at the bottom via `.safeAreaInset(edge: .bottom)` that opens `ScanDirectoriesPopoverView` as a popover anchored at bottom edge
- Project sections replaced with `DisclosureGroup` — all sections start expanded; user can collapse/expand any section, state tracked in `expandedGroups: Set<String>` (inverted logic: presence = collapsed)
- Empty scan source groups (directories with no GSD projects) show "No projects found" placeholder text when no search/filter is active
- `~/Developer` is always sorted first in sidebar — special-cased because `~` (ASCII 126) sorts after all letters, which would put it last in alphabetical sort
- All scan sources (including those with 0 projects) are shown in sidebar when no search or status filter is active

## Task Commits

Each task was committed atomically:

1. **Task 1: Add gear button, popover, and collapsible sections to SidebarView** - `2bd524a` (feat)
2. **Task 2: UI polish from checkpoint verification** - `605d920` (fix) — custom filter buttons, tighter cell spacing, inline duplicate warning

**Plan metadata:** `a632f01` (docs: complete plan)

## Files Created/Modified

- `GSDMonitor/Views/SidebarView.swift` - Added `showingScanSettings`/`expandedGroups` state, gear button via `.safeAreaInset`, `DisclosureGroup` sections, empty group placeholder, ~/Developer-first sort logic, UI polish (filter buttons, cell spacing, duplicate warning)

## Decisions Made

- `expandedGroups` Set tracks which groups are COLLAPSED (inverted pattern) — means no initialization needed; an empty Set means all groups are expanded by default
- Empty scan source groups only shown when no search/filter active — prevents cluttering search results with empty groups
- `~/Developer` explicitly sorted first because `~` character has ASCII value 126 (higher than `z` = 122), which would cause it to sort last alphabetically otherwise
- Gear button placed in `.safeAreaInset` on the List so it remains visible below the scrollable project list at all times
- Post-checkpoint UI polish (custom filter button style, tighter ProjectRow spacing, inline "Already added" duplicate warning) committed as a separate fix after user approval

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] UI polish applied after user verification**
- **Found during:** Task 2 (human-verify checkpoint)
- **Issue:** Filter buttons, cell spacing, and duplicate warning label needed visual refinement for usable UI
- **Fix:** Custom filter button style, tighter list row padding, inline duplicate warning label
- **Files modified:** `GSDMonitor/Views/SidebarView.swift`
- **Verification:** Reviewed visually during makeapp run, approved by user
- **Committed in:** `605d920` (fix commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - UI polish)
**Impact on plan:** Polish fix was necessary for a usable UI. No scope creep.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 16 complete: scan directory management is fully wired end-to-end
- Popover accessible from sidebar gear button; sidebar groups by scan source with collapsible sections
- All scan sources persist across app restart (UserDefaults-backed)
- All SCAN requirements (SCAN-01 through SCAN-04) satisfied — ready for Phase 17 milestone close-out

## Self-Check: PASSED

- [x] `GSDMonitor/Views/SidebarView.swift` exists and was modified
- [x] Commit `2bd524a` exists in git log
- [x] Commit `605d920` exists in git log (UI polish)
- [x] User approved feature end-to-end at checkpoint

---
*Phase: 16-configurable-scan-directories*
*Completed: 2026-02-21*
