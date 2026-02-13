# Phase 15: Command Triggering & Integration - Context

**Gathered:** 2026-02-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Entry points for running GSD commands from the app UI — context buttons on phase/plan cards, a Cmd+K command palette, command history browsing, and running state coordination including FSEvents suppression during active runs.

</domain>

<decisions>
## Implementation Decisions

### Context buttons
- Appear on both phase cards AND individual plan rows
- Phase cards: smart default button (adapts: "Plan" if unplanned, "Execute" if planned, "Verify" if executed) PLUS a ··· menu for all applicable commands (discuss, plan, execute, verify)
- Plan rows: button executes that specific plan only (not the whole phase)
- Smart default button: filled accent button (Gruvbox-colored) with label — prominent, draws attention
- While a command is running: action button transforms into a red "Cancel" button

### Command palette (Cmd+K)
- Contains both GSD commands (plan-phase, execute-phase, verify, discuss, etc.) and app actions (refresh, toggle theme, open settings)
- Flat searchable list — type to filter, no category grouping
- Includes a project picker step within the palette — user selects project before running command
- Step-by-step parameter prompting — after picking a command, palette prompts for required params (phase number, plan number, etc.)

### Command history
- Dedicated history view (separate section/tab), not embedded in the output panel
- Minimal entry display: command name, timestamp, success/fail badge — compact list
- Tapping an entry expands to show full captured output, with a "Re-run" button available
- Retain last 50 command runs per project

### Running state indicators
- Indicators appear everywhere relevant: sidebar project row, phase card, plan row, and output panel header
- Visual treatment: animated spinner icon + elapsed time counter ("2m 34s")
- Output panel auto-opens whenever any command starts
- FSEvents reloads suppressed during active command runs (existing decision from Phase 13)

### Claude's Discretion
- Exact spinner animation style
- Command palette keyboard navigation details
- History view placement (tab vs sidebar section)
- How parameter prompts flow in the palette UI
- Exact ··· menu items per phase state

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

*Phase: 15-command-triggering-integration*
*Context gathered: 2026-02-18*
