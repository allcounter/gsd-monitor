# Phase 13: Process Foundation - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Headless command execution engine: the app can execute GSD commands as child processes with live-streamed output and reliable cancellation. ProcessActor, CommandRunnerService, PATH resolution, cancel/kill, and queue model. No UI in this phase — output panel is Phase 14, command triggers are Phase 15.

</domain>

<decisions>
## Implementation Decisions

### Cancel behavior
- Graceful shutdown first: send SIGINT, wait (Claude's discretion on timeout duration), then SIGKILL if still running
- Cancellation requires user confirmation before executing
- Cancelled commands are marked with a distinct "cancelled" state, separate from "failed"

### Queue & blocking
- Per-project queue: each project has its own independent command queue — commands for different projects can run in parallel
- Unlimited queue depth: users can stack as many commands as they want, they run in order
- Queued commands are visible and individually removable before they start

### Command lifecycle
- Capture per run: command string, project, start time, duration, exit code (basics)
- Store full stdout/stderr output for later review
- Parse GSD-specific metadata from output: phase, plan, task status
- Command history persists to disk across app restarts
- One-click re-run from history: users can re-trigger a previous command with the same parameters

### Error & recovery
- On non-zero exit: show exit code + contextual recovery suggestions (e.g., "re-run", "check logs")
- If claude CLI path not found: guide user with clear installation/configuration instructions
- Auto-retry once on failure, then stop — user must manually re-trigger after that
- Crashed processes (externally killed, system issues) get a distinct "crashed" state, different from normal failure

### Claude's Discretion
- Graceful shutdown timeout duration (likely 3-5 seconds)
- History retention policy (count-based vs time-based)
- Persistence storage format and location
- GSD output parsing patterns for metadata extraction
- Exact recovery suggestion content per error type

</decisions>

<specifics>
## Specific Ideas

- Command states form a clear lifecycle: queued → running → succeeded / failed / cancelled / crashed
- Per-project parallelism with per-project serialization — multiple projects can run simultaneously but each project runs one at a time
- Re-run capability from history for quick retry workflows

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 13-process-foundation*
*Context gathered: 2026-02-17*
