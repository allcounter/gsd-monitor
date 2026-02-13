---
phase: 13-process-foundation
plan: "02"
subsystem: process-execution-engine
tags: [swift6, concurrency, asyncstream, pty, darwin, foundation-process, process-management]

dependency_graph:
  requires:
    - phase: 13-01
      provides: "CommandRun.OutputLine type used for stream elements"
  provides:
    - actor ProcessActor — owns one Foundation.Process with PTY stdin and Pipe stdout/stderr
    - run() returning AsyncStream<CommandRun.OutputLine> for live output streaming
    - cancel() with SIGINT->4s wait->SIGKILL escalation
  affects:
    - 13-03 (CommandRunnerService will create and own ProcessActor instances per command run)

tech-stack:
  added: []
  patterns:
    - _Concurrency.Task disambiguation — GSDMonitor.Task shadows Swift Task; use _Concurrency.Task explicitly
    - PTY-stdin + Pipe-stdout/stderr hybrid — openpty() for stdin (prevents TTY hang), Pipes for streaming
    - AsyncStream.Continuation direct yield from readabilityHandler (thread-safe per Swift docs)
    - terminationHandler-authoritative — terminationHandler does final flush + finish(), not readabilityHandler EOF

key-files:
  created:
    - GSDMonitor/Services/ProcessActor.swift
  modified:
    - GSDMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "_Concurrency.Task qualifier required: GSDMonitor.Task model shadows Swift Concurrency Task in module scope; all Task { } and Task.sleep() calls must use _Concurrency.Task prefix"
  - "AsyncStream builder stores continuation synchronously, then _Concurrency.Task launches process on actor — avoids [weak self] in AsyncStream closure which would trigger Sendable errors"
  - "readabilityHandler yields directly to continuation (not via actor method) because AsyncStream.Continuation.yield is documented thread-safe; this avoids Task dispatch overhead per output chunk"

patterns-established:
  - "_Concurrency.Task: Always qualify Task when GSDMonitor.Task is in scope (affects all Services files)"
  - "PTY-stdin hybrid: Use openpty() for stdin to prevent claude TTY hang; keep masterFD open until terminationHandler; slaveFD via closeOnDealloc FileHandle"

requirements-completed: [PROC-01, PROC-03, PROC-04, PROC-05]

duration: 2min
completed: 2026-02-17
---

# Phase 13 Plan 02: ProcessActor Summary

**Swift actor that spawns Foundation.Process with PTY stdin (openpty), streams stdout/stderr via readabilityHandler-bridged AsyncStream, and cancels with SIGINT then SIGKILL after 4 seconds**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-17T21:12:58Z
- **Completed:** 2026-02-17T21:17:00Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- ProcessActor implements the PTY-stdin + Pipe-stdout/stderr hybrid pattern: `Darwin.openpty()` for stdin (critical to prevent claude CLI hanging in non-TTY), separate Pipes for live streaming
- readabilityHandler on both stdout/stderr pipes yields `CommandRun.OutputLine` directly to the AsyncStream continuation (thread-safe, no actor dispatch overhead per chunk)
- terminationHandler nullifies handlers, does final `readDataToEndOfFile()` flush on both pipes, closes PTY master, and calls `continuation.finish()` — authoritative completion signal
- `cancel()` sends `process.interrupt()` (SIGINT), polls isRunning every 200ms for 4 seconds, then `Darwin.kill(pid, SIGKILL)` + `Darwin.kill(-pid, SIGKILL)` if still running
- Zero Swift 6 strict concurrency warnings (only pre-existing AppDelegate warning)

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement ProcessActor with PTY, streaming, and cancellation** - `af3446a` (feat)

## Files Created/Modified

- `GSDMonitor/Services/ProcessActor.swift` - actor ProcessActor: PTY stdin, Pipe streaming, AsyncStream output, SIGINT+SIGKILL cancel
- `GSDMonitor.xcodeproj/project.pbxproj` - Added ProcessActor.swift to Services group and Sources build phase (PROC1302 IDs)

## Decisions Made

- **_Concurrency.Task qualifier:** GSDMonitor has a `Task` model struct (Plan.swift) that shadows Swift Concurrency's `Task` globally across the module. All concurrency `Task { }` and `Task.sleep()` calls in ProcessActor must use `_Concurrency.Task` prefix. This will affect all future service files in Phase 13+.
- **AsyncStream builder pattern:** The AsyncStream closure captures the continuation synchronously (stored in a local var), which is then passed to a `_Concurrency.Task` that calls the actor's `launchProcess()`. This avoids `[weak self]` in the AsyncStream closure (which would require Sendable conformance on the closure type) while keeping setup on the actor.
- **Direct continuation.yield from readabilityHandler:** Per Swift documentation, `AsyncStream.Continuation.yield()` is thread-safe and can be called from any thread. Yielding directly from the GCD-dispatched readabilityHandler (rather than dispatching via `_Concurrency.Task`) eliminates per-chunk overhead. No actor state is mutated in the handler — only the continuation is used.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] _Concurrency.Task qualifier for GSDMonitor.Task shadowing**
- **Found during:** Task 1 build verification
- **Issue:** `Task { }` and `Task.sleep(for:)` in ProcessActor.swift failed to compile: "type 'Task' has no member 'sleep'" and "trailing closure passed to parameter of type 'any Decoder'" — GSDMonitor.Task (from Plan.swift) shadowed Swift Concurrency's Task throughout the module
- **Fix:** Added `_Concurrency.Task` qualifier to all Task usage: `_Concurrency.Task { ... }` for fire-and-forget closures, `_Concurrency.Task.sleep(nanoseconds:)` for the cancel poll loop, and switched from `.milliseconds` Duration syntax (requires `_Concurrency.Task.sleep(for:)` which also failed) to `nanoseconds:` parameter
- **Files modified:** GSDMonitor/Services/ProcessActor.swift
- **Verification:** Build succeeds with zero errors
- **Committed in:** af3446a (Task 1 commit)

**2. [Rule 1 - Bug] AsyncStream [weak self] closure not Sendable**
- **Found during:** Task 1 build verification (same build pass as fix #1)
- **Issue:** `AsyncStream<CommandRun.OutputLine> { [weak self] continuation in ... }` — AsyncStream's build closure is `@Sendable (Continuation) -> Void` and does not support capture lists. The `[weak self]` syntax was treated as a trailing closure parameter mismatch
- **Fix:** Extracted continuation from the AsyncStream builder synchronously into a local `storedContinuation` variable, then passed it to `_Concurrency.Task { ... }` which calls the actor's `launchProcess()`. This maintains actor isolation correctly while making the setup async
- **Files modified:** GSDMonitor/Services/ProcessActor.swift
- **Verification:** Build succeeds with zero errors
- **Committed in:** af3446a (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 - Bug)
**Impact on plan:** Both fixes required for compilation under Swift 6. The Task shadowing issue is a structural module-level concern that will recur in Plan 03 (CommandRunnerService) — documented in decisions.

## Issues Encountered

None beyond the auto-fixed compilation issues above.

## Next Phase Readiness

- ProcessActor is complete and compiles with zero warnings
- Plan 03 (CommandRunnerService) can use `ProcessActor()` directly — one actor instance per command run
- **Important carry-forward:** All Swift Concurrency `Task` usage in Phase 13 files must use `_Concurrency.Task` prefix due to GSDMonitor.Task shadowing

---
*Phase: 13-process-foundation*
*Completed: 2026-02-17*
