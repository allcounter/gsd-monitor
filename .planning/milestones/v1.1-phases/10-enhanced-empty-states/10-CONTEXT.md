# Phase 10: Enhanced Empty States - Context

**Gathered:** 2026-02-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Themed empty state views for screens that have no content. Uses ContentUnavailableView with SF Symbols and Gruvbox colors. Covers sidebar (no projects) and detail view (no phase selected / no phases). No new features or capabilities.

</domain>

<decisions>
## Implementation Decisions

### Empty state locations
- Tom sidebar: when no projects are discovered
- Tom detail view: when no project is selected, or project has no phases

### Visual approach
- Use ContentUnavailableView (native macOS pattern)
- SF Symbols for icons
- Gruvbox-farver from existing Theme system

### Claude's Discretion
- Which SF Symbols to use for each empty state
- Exact text/messaging for each empty state
- Icon sizing and layout details
- Whether to include subtle instructional text (e.g. "Tilføj scan source i indstillinger")

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. Follow existing Gruvbox theme patterns from Phase 6.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 10-enhanced-empty-states*
*Context gathered: 2026-02-16*
