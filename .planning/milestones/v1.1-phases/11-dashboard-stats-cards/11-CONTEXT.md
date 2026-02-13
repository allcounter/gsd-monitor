# Phase 11: Dashboard Stats Cards - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Projekt-header viser stats-kort med key metrics: total faser, completion %, aktive faser, og total tid brugt. Stats opdaterer automatisk ved FSEvents-ændringer. Grid er responsive og tilpasser sig window width.

</domain>

<decisions>
## Implementation Decisions

### Card content
- Show all four metrics: total phases, completion %, active phases, total time spent
- Velocity metric shows total execution time (e.g. "1.8 hrs"), not per-plan average
- Include milestone label (e.g. "v1.1 Visual Overhaul") as section title above the stats grid

### Layout & sizing
- Always visible, no collapsible toggle
- Spacious density — large numbers, generous whitespace, stats are a visual focal point

### Visual style
- Solid dark surface background (bg1/bg2) matching existing phase card style
- Subtle divider between stats section and scrollable phase cards below

### Placement
- Below header, pinned — stats don't scroll away with phase cards
- Milestone name as section title above the stats grid
- Subtle divider separates stats from scrollable phase card area

### Claude's Discretion
- Grid arrangement (single row of 4 vs 2x2 — pick based on available width)
- Card max width vs stretch-to-fill behavior
- Accent color scheme (unique per card or uniform — pick what looks best with Gruvbox)
- Whether to include SF Symbol icons per card
- Count-up animation on first appearance (decide based on complexity vs polish)
- Data scope: current milestone only vs all milestones combined

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

*Phase: 11-dashboard-stats-cards*
*Context gathered: 2026-02-17*
