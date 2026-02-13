# Phase 14: Output Panel - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Command output UI panel within the app. Users see live-streamed output from GSD commands, distinguish stderr from stdout, know when a command succeeded or failed, and can toggle between raw output and a structured task checklist view. Cancel UX with confirmation. No command triggering UI (that's Phase 15).

</domain>

<decisions>
## Implementation Decisions

### Panel placement & layout
- Right sidebar panel — splits main content area horizontally (sidebar | dashboard | output panel)
- Always visible — shown even when no command is running
- Resizable divider — user drags to adjust split between dashboard and output panel
- Idle state shows last command output — persists until a new command starts

### Output stream presentation
- System font (San Francisco) — not monospace. App feel, not terminal feel
- stderr lines in Gruvbox red text color, stdout in default foreground color
- Smart auto-scroll — auto-scroll when at bottom, pause when user scrolls up, resume when they scroll back down
- Rolling buffer of ~5000 lines — prevents memory issues on long-running commands

### Structured GSD view
- Task checklist + progress bar as the structured view: phase/plan header, progress bar with task count, checklist with status symbols (checkmark, diamond, circle)
- Structured view is the default when a command starts
- Segmented control in panel header to toggle between Structured and Raw views
- Elapsed timer shown next to progress bar while command runs

### Completion & error states
- Success: green banner at top of panel with exit code, task summary, and duration. Output stays visible below
- Failure: red error banner with exit code, plus highlight last stderr lines. Output stays visible for debugging
- Cancel: standard macOS alert dialog ("Cancel running command?") before sending SIGINT
- Notifications: only on failure — send a macOS notification when a command fails. Success is visible in the panel

### Claude's Discretion
- Exact panel minimum/maximum width constraints
- Divider styling and drag handle design
- Progress bar gradient colors (should follow Gruvbox theme)
- Banner animation/transition style
- How many stderr lines to highlight on failure

</decisions>

<specifics>
## Specific Ideas

- Structured view mockup: Phase/Plan header, progress bar with "2/4 tasks", then checklist lines with status symbols matching the app's existing StatusBadge pattern
- Panel should feel like part of the app, not an embedded terminal — hence system font and structured default view
- Smart auto-scroll is important for long GSD runs where user might want to read earlier output

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 14-output-panel*
*Context gathered: 2026-02-17*
