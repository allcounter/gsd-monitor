# Phase 12: Milestone Timeline - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Milestone-tidslinje der viser faser som forbundne noder i DetailView, placeret over phase cards. Hver node viser fase-navn, status og progress inline. Status-farver matcher Gruvbox-palette.

</domain>

<decisions>
## Implementation Decisions

### Milestone sections
- Completed milestones (e.g. v1.0) collapsed to a single summary node showing milestone name + phase count (e.g. "v1.0 MVP - 5/5 phases")
- Collapsed milestone node is expandable — click to reveal individual v1.0 phases as smaller nodes
- Milestone separator is an inline label badge with Gruvbox colors: "v1.0 MVP ✔" / "v1.1 Visual Overhaul"
- Timeline auto-scrolls to current milestone on load — completed milestones above the fold

### Claude's Discretion
- Node design: icon, text layout, progress indicator per node
- Timeline layout: vertical vs horizontal, connecting line style, spacing
- Interaction: hover states, click-to-scroll-to-phase-card behavior
- Animation: node appearance, expand/collapse transitions
- How expanded v1.0 phases differ visually from current milestone phases

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for timeline visualization within the Gruvbox theme.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 12-milestone-timeline*
*Context gathered: 2026-02-17*
