# Phase 16: Configurable Scan Directories - Context

**Gathered:** 2026-02-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Users control which base directories the app scans for GSD projects. ~/Developer is the permanent default scan source. Users can add and remove additional scan directories. Projects from all sources appear in the sidebar grouped by source.

</domain>

<decisions>
## Implementation Decisions

### Settings UI & access
- Gear icon at bottom of sidebar, always visible — opens a popover
- Popover titled "Scan Directories", dedicated to scan sources only (no general settings)
- Two sections: "Default" (~/Developer, non-removable) and "Additional" (user-added)
- Each directory row shows: abbreviated path with ~, project count, last scan time (e.g. "~/Projects — 3 projects · scanned 2m ago")
- Paths displayed with ~ abbreviation (~/Projects not /Users/name/Projects)

### Adding directories
- + button opens macOS standard NSOpenPanel folder picker
- Drag & drop folder from Finder onto popover also supported
- Directory added immediately, scan happens after — shows "0 projects" until scan completes
- Duplicate add shows inline warning: "Already added"

### Removing directories
- Small − or trash icon on each user-added row (not on ~/Developer)
- Click to remove immediately — projects from that source disappear from sidebar

### Sidebar presentation
- Projects grouped by source directory with collapsible section headers
- Headers show abbreviated path: "~/Developer", "~/Projects", etc.
- ~/Developer group always first, additional sources sorted alphabetically below
- Projects within each group sorted alphabetically
- Empty groups (0 projects) still visible with "No projects found" message

### Scan feedback & persistence
- Scanning indicator shown in the settings popover near the directory row being scanned
- Scan sources persisted in UserDefaults across app restarts
- FSEvents monitoring on all scan directories — new projects appear automatically in real-time
- If a scan directory is deleted/inaccessible: stays in list with error badge, user can re-add or remove

### Claude's Discretion
- Exact popover sizing and spacing
- Gear icon style and placement details
- Scanning indicator design (spinner, progress bar, etc.)
- Animation on group collapse/expand
- Error badge design

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 16-configurable-scan-directories*
*Context gathered: 2026-02-21*
