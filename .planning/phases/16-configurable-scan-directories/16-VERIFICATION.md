---
phase: 16-configurable-scan-directories
verified: 2026-02-21T12:00:00Z
status: human_needed
score: 4/4 success criteria verified
human_verification:
  - test: "Open app, click gear icon at bottom of sidebar, click + button, select any directory — confirm a new scan source appears in the Additional section of the popover and that its GSD projects appear in the sidebar within a few seconds"
    expected: "New directory row appears in popover Additional section with project count and 'scanned just now' label; sidebar gains a new Section header for the directory with its projects listed"
    why_human: "NSOpenPanel interaction and live project discovery require runtime observation; grep cannot verify the async scan completes and projects surface in the UI"
  - test: "Add a directory, then click the minus.circle.fill button on that row in the popover — confirm the directory disappears from the popover and its projects disappear from the sidebar"
    expected: "Row removed from Additional section; sidebar Section header for that directory gone; projects that belonged to it no longer visible"
    why_human: "State mutation and reactive sidebar update must be observed at runtime"
  - test: "Verify ~/Developer row has NO minus button and that calling removeScanDirectory with the Developer URL is a no-op"
    expected: "Default section row has no remove button visible; if attempted via code, guard fires and directory stays"
    why_human: "UI absence of a button is a visual check; the data-layer guard is in code (verified) but the UI constraint must be visually confirmed"
  - test: "Quit and relaunch the app — confirm all previously added scan directories are still present in the popover and their projects still appear in the sidebar"
    expected: "Scan sources persisted via UserDefaults survive app restart; popover shows same Additional entries as before quit"
    why_human: "Persistence requires a real app lifecycle (quit + relaunch) which cannot be simulated with grep"
  - test: "Drag a folder from Finder onto the open ScanDirectoriesPopoverView — confirm it is added as a scan source with blue highlight border during hover"
    expected: "Border highlights in brightBlue on drag hover; folder added to Additional section on drop; projects discovered"
    why_human: "Drag-and-drop is a user gesture that requires runtime observation"
---

# Phase 16: Configurable Scan Directories — Verification Report

**Phase Goal:** Users control which directories the app scans for GSD projects, with ~/Developer as the permanent default
**Verified:** 2026-02-21
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Success Criteria (from ROADMAP.md)

These are the authoritative contract for Phase 16. Plan-level truths that go beyond these (e.g., collapsible DisclosureGroup sections) are treated as implementation details, not goal requirements.

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| 1 | User can open Settings and add any directory as a scan source — app immediately begins scanning it for .planning/ projects | ? HUMAN NEEDED | Code fully wired: `addScanDirectoryViaPanel()` → NSOpenPanel → `addScanDirectory()` → `discoveryService.discoverProjects()` → appends to `projects`. Gear button in sidebar opens `ScanDirectoriesPopoverView` with + button calling this path. Runtime behavior requires human observation. |
| 2 | User can remove a previously added scan directory — its projects disappear from the sidebar | ? HUMAN NEEDED | Code fully wired: `removeScanDirectory()` guards ~/Developer, removes matching projects, updates `scanSources` (UserDefaults), removes `scanSourceStates` entry, restarts monitoring. Remove button in `ScanDirectoryRow` calls `onRemove` which calls `projectService.removeScanDirectory(source)`. Runtime behavior requires human observation. |
| 3 | ~/Developer is always present as a scan source and cannot be removed | VERIFIED | Data layer: `removeScanDirectory()` guards with `guard url.path != developerURL.path else { return }` (line 262). UI layer: `ScanDirectoriesPopoverView` hardcodes `defaultSource` as ~/Developer and passes `isRemovable: false` to its `ScanDirectoryRow`, which suppresses the minus button. `scanSources` getter defaults to ~/Developer when no UserDefaults entry exists (line 27). Triple-layered protection. |
| 4 | Projects from all configured directories appear together in the sidebar alongside ~/Developer projects | VERIFIED | `SidebarView.filteredProjects` calls `projectService.groupedProjects` which buckets all projects by scan source. When no search/filter is active, ALL scan sources (including empty ones) are included. Sidebar renders one `Section` per group. ~/Developer explicitly sorted first (lines 55-56). |

**Score:** 2/4 fully programmatically verified; 2/4 code-complete but require human runtime observation.

---

## Required Artifacts

### Plan 01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `GSDMonitor/Services/ProjectService.swift` | ScanSourceState tracking, addScanDirectory(), removeScanDirectory() | VERIFIED | `struct ScanSourceState` at file scope (lines 7-11). `scanSourceStates: [String: ScanSourceState]` and `duplicateWarningPath: String?` as Observable properties (lines 17-18). `addScanDirectory()` at line 207, `removeScanDirectory()` at line 259, `addScanDirectoryViaPanel()` at line 289. All substantive and wired. |
| `GSDMonitor/Views/Settings/ScanDirectoriesPopoverView.swift` | Popover UI for managing scan directories | VERIFIED | 244 lines. Default/Additional sections present (lines 36-76). `ScanDirectoryRow` private subview with path abbreviation, project count, relative time, scanner spinner, error badge, remove button (lines 132-237). Drag-and-drop `.onDrop(of: [.fileURL])` at line 101. + button calling `addScanDirectoryViaPanel()` at line 85. |

### Plan 02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `GSDMonitor/Views/SidebarView.swift` | Gear button with popover + project sections grouped by source | VERIFIED | `showingScanSettings` state at line 9. `.safeAreaInset(edge: .bottom)` gear button at lines 184-201 opening `ScanDirectoriesPopoverView` via `.popover(isPresented: $showingScanSettings)`. `filteredProjects` groups by scan source (lines 36-94). `Section` used for project groups (lines 205-244). Sorted with ~/Developer first. |

**Note:** `expandedGroups: Set<String>` is declared (line 11) but unused — a dead state variable left over from the `DisclosureGroup` → `Section` switch made during UI polish commit `605d920`. This is a minor code smell but has no functional impact. Collapsibility was not a ROADMAP success criterion.

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ScanDirectoriesPopoverView.swift` | `ProjectService.addScanDirectory` | NSOpenPanel + `_Concurrency.Task` | WIRED | Line 85: `await projectService.addScanDirectoryViaPanel()` which calls `addScanDirectory(url)` at line 299 |
| `ScanDirectoriesPopoverView.swift` | `ProjectService.removeScanDirectory` | onRemove closure on ScanDirectoryRow | WIRED | Line 67: `projectService.removeScanDirectory(source)` passed as `onRemove` closure |
| `ProjectService.addScanDirectory` | `ProjectDiscoveryService.discoverProjects` | `_Concurrency.Task` background scan | WIRED | Line 238: `await discoveryService.discoverProjects(in: [url])` inside async Task |
| `SidebarView.swift` | `ScanDirectoriesPopoverView` | `.popover(isPresented: $showingScanSettings)` | WIRED | Line 195: `ScanDirectoriesPopoverView(projectService: projectService)` inside popover modifier |
| `SidebarView.swift` | `ProjectService.groupedProjects` | `filteredProjects` computed var | WIRED | Line 38: `var groups = projectService.groupedProjects` |
| `ProjectService.scanSources` | `UserDefaults` | computed property get/set | WIRED | Lines 23, 32: reads and writes `UserDefaults.standard` key `"scanSources"` — persistence verified |

---

## Requirements Coverage

| Requirement | Plans | Description | Status | Evidence |
|-------------|-------|-------------|--------|----------|
| SCAN-01 | 16-01, 16-02 | User can add custom scan directories via settings | SATISFIED | `addScanDirectory()` / `addScanDirectoryViaPanel()` wired to gear button popover + button and drag-and-drop |
| SCAN-02 | 16-01, 16-02 | User can remove scan directories | SATISFIED | `removeScanDirectory()` wired to minus button in `ScanDirectoryRow` |
| SCAN-03 | 16-01, 16-02 | App scans all configured directories for .planning/ projects | SATISFIED | `loadProjects()` calls `discoveryService.discoverProjects(in: currentSources)` for all scan sources; `addScanDirectory()` triggers targeted scan of new directory |
| SCAN-04 | 16-01, 16-02 | ~/Developer remains default scan directory | SATISFIED | Triple protection: UserDefaults getter defaults to ~/Developer; `removeScanDirectory()` guards at data layer; UI marks it `isRemovable: false` |

No orphaned requirements. All four SCAN-01 through SCAN-04 requirements are claimed by both plans and fully implemented.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `SidebarView.swift` | 11 | `expandedGroups: Set<String>` declared but never read or mutated beyond declaration | Info | Dead code from DisclosureGroup → Section migration in `605d920`. No functional impact; collapsibility was not a ROADMAP success criterion. |

No blocker or warning anti-patterns found. No TODO/FIXME/placeholder comments. No empty implementations. No stub API routes.

---

## Deviation: DisclosureGroup Replaced by Section

Plan 02's `must_haves.truths` included "Projects in the sidebar are grouped by scan source with collapsible section headers." The implementation uses `Section` (SwiftUI's native list section) instead of `DisclosureGroup`. This occurred in commit `605d920` (UI polish after human checkpoint approval).

**Assessment:** This is not a goal failure. The ROADMAP success criteria do not mention collapsibility — they require projects to appear grouped by source, which `Section` satisfies. The user explicitly approved the change at the human checkpoint gate in Plan 02, Task 2. `expandedGroups` state is dead code and should be removed, but it has no functional impact.

---

## Human Verification Required

### 1. Add Scan Directory End-to-End

**Test:** Launch app, click the gear icon at bottom-right of sidebar, click "Add Directory..." in the popover, select a folder that contains GSD projects with `.planning/ROADMAP.md` files.
**Expected:** The directory appears in the Additional section with a project count and "scanned just now" timestamp; its projects appear in a new sidebar Section within a few seconds.
**Why human:** NSOpenPanel interaction and async project discovery require runtime observation.

### 2. Remove Scan Directory End-to-End

**Test:** With a user-added directory present, click the minus.circle.fill button on that row in the popover.
**Expected:** Row disappears from Additional section; sidebar loses the Section for that directory; any projects that belonged only to that source are gone from the list.
**Why human:** Reactive UI state mutation must be observed at runtime.

### 3. ~/Developer Protection (UI)

**Test:** Inspect the Default section row for ~/Developer — confirm there is no minus/remove button visible.
**Expected:** No remove control on the Default row; only path, project count, and scan time visible.
**Why human:** Absence of a UI element is a visual check.

### 4. Persistence Across Restart

**Test:** Add a scan directory, quit the app (`Cmd-Q`), relaunch — confirm the added directory is still listed in the popover Additional section and its projects are still in the sidebar.
**Expected:** UserDefaults-backed `scanSources` survives app termination and reload.
**Why human:** Requires real app lifecycle (quit + relaunch).

### 5. Drag-and-Drop from Finder

**Test:** Open the scan directories popover, then drag a folder from Finder onto the popover window.
**Expected:** Blue border highlight appears on drag hover; on drop, directory is added to Additional section and projects discovered.
**Why human:** Drag-and-drop requires a user gesture at runtime.

---

## Summary

Phase 16 is **code-complete**. All four requirements (SCAN-01 through SCAN-04) are satisfied at the implementation level:

- `ScanSourceState` struct and per-source state tracking exist and are substantive
- `addScanDirectory()`, `removeScanDirectory()`, and `addScanDirectoryViaPanel()` are all implemented with correct logic
- `ScanDirectoriesPopoverView` is a full implementation with Default/Additional sections, row metadata, drag-and-drop, + button, and duplicate warning
- `SidebarView` gear button opens the popover; sidebar renders groups by scan source with ~/Developer always first
- UserDefaults persistence is wired for `scanSources`
- The ~/Developer protection is triple-layered (defaults, data guard, UI `isRemovable: false`)

The only issue is five human-observable behaviors that grep cannot verify — all of which relate to runtime app behavior (async scans completing, UI reacting, persistence surviving restart, gesture handling). Automated checks pass. **Awaiting human verification** before marking the phase fully passed.

---

_Verified: 2026-02-21_
_Verifier: Claude (gsd-verifier)_
