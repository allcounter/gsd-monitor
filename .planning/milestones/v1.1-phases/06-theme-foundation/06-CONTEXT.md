# Phase 6: Theme Foundation - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Gruvbox Dark farvepalet integreret som centraliseret tema-system. Alle UI-komponenter bruger Gruvbox-farver fra ét sted, ingen hardcodede systemfarver (.blue, .green, .gray) tilbage i kodebasen. Status badges bruger én parametriseret komponent med konsistente Gruvbox-farver. Interactive elements bevarer themed feel.

</domain>

<decisions>
## Implementation Decisions

### Color palette scope
- Full Gruvbox Dark palette: all bg0-bg4, fg0-fg4, and all 8 accent colors (red, green, yellow, blue, purple, aqua, orange, gray)
- Original Pavel Pertsev variant (not Material)
- Main app background: bg0 (#282828)
- Two naming layers: raw Gruvbox names (Theme.bg0, Theme.aqua) + semantic aliases (Theme.statusActive = Theme.yellow)

### Status color mapping
- In progress / active: Yellow (#d79921)
- Complete: Green (#98971a)
- Not started: Gray (fg4 #a89984)
- Blocked: Red (#cc241d)

### Interactive element styling
- Sidebar list selection: Gruvbox accent highlight using bg2 (#504945) background
- Buttons: Custom Gruvbox-styled with themed colors, rounded corners, hover states
- Window title bar and toolbar: Themed to blend with bg0 — immersive look, not native title bar

### Badge component design
- Shape: Rounded pill (capsule like GitHub labels)
- Color style: Filled background with solid Gruvbox accent color and contrasting text
- Text style: Lowercase ("in progress", "complete", "blocked")
- One parametrised component for all status badges

### Claude's Discretion
- Badge size relative to surrounding text (pick what looks balanced)
- Exact hover/press states for buttons
- Font weights and spacing within the theme system
- How to handle the forced dark mode (preferredColorScheme vs Info.plist)

</decisions>

<specifics>
## Specific Ideas

- Two-layer naming: raw Gruvbox palette names for flexibility, semantic aliases for consistency — downstream phases use semantic names
- Title bar should blend seamlessly with app background for an immersive, terminal-like feel
- Badges should feel compact and label-like, not dominate the UI

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-theme-foundation*
*Context gathered: 2026-02-15*
