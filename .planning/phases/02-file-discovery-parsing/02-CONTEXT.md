# Phase 2: File Discovery & Parsing - Context

**Gathered:** 2026-02-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Discover GSD projects by scanning configured directories for `.planning/` folders, parse all planning files (ROADMAP.md, STATE.md, REQUIREMENTS.md, PLAN.md, config.json) into Swift models, and persist file access with security-scoped bookmarks. User can also manually add projects via file picker.

</domain>

<decisions>
## Implementation Decisions

### Projekt-scanning
- Scan ~/Developer recursively as default scan path
- Configurable scan list — user can add additional root directories to auto-scan (e.g., ~/Projects, ~/Work)
- Scan triggers only at app launch (no periodic or live rescanning in this phase)
- App starts with sidebar overview, does NOT restore last selected project

### Manuel tilføjelse
- File picker (standard macOS Open dialog) for adding projects outside scan paths
- Right-click context menu → "Remove" for removing manually added projects from sidebar
- No drag & drop — file picker only

### Sidebar-visning
- Projects show name + small progress bar in sidebar
- Projects grouped by scan source (e.g., "~/Developer", "Manually Added")

### Claude's Discretion
- Scan depth for recursive scanning (balance thoroughness vs performance)
- Symlink handling (safety-first approach)
- Handling of disappeared projects (removed from disk)
- Minimum file requirement for displaying a project
- Behavior when user adds a folder without .planning/
- Parsing depth for PLAN.md, REQUIREMENTS.md, and config.json
- Error handling for corrupt/unexpected markdown format
- Sorting order within sidebar groups
- node_modules/.git exclusion during scanning

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. User trusts Claude's judgment on implementation details, with key UX decisions locked above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-file-discovery-parsing*
*Context gathered: 2026-02-13*
