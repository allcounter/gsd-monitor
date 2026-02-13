---
phase: 13-process-foundation
plan: "03"
subsystem: process-execution-engine
tags: [swift6, concurrency, asyncstream, observable, macos, foundation, actor, json-persistence]

dependency_graph:
  requires:
    - phase: 13-01
      provides: "CommandRun, CommandState, CommandRequest model types"
    - phase: 13-02
      provides: "ProcessActor for spawning and streaming child processes"
  provides:
    - actor CommandHistoryStore — JSON persistence to ~/Library/Application Support/GSDMonitor/command-history.json
    - "@MainActor @Observable CommandRunnerService — public command execution API with per-project FIFO queues"
    - rerun() for one-click re-run from history
    - auto-retry once on failure, then stop
    - removeQueuedCommand() for individual queue item removal
  affects:
    - 14 (Phase 14 UI binding will use CommandRunnerService.activeRuns, projectQueues, recentRuns)

tech-stack:
  added: []
  patterns:
    - "AsyncStream.makeStream() per-project FIFO queue — one consumer loop per project serializes commands"
    - "@MainActor @Observable for UI-bindable service state (Phase 14 ready)"
    - "Actor isolation for file I/O — CommandHistoryStore prevents concurrent read/write contention"
    - "_Concurrency.Task qualification — required throughout as GSDMonitor.Task shadows Swift Concurrency Task"
    - "Atomic file writes (Data.write options:.atomic) for crash-safe JSON persistence"

key-files:
  created:
    - GSDMonitor/Services/CommandHistoryStore.swift
    - GSDMonitor/Services/CommandRunnerService.swift
  modified:
    - GSDMonitor/Services/ProcessActor.swift
    - GSDMonitor.xcodeproj/project.pbxproj

key-decisions:
  - "AsyncStream.makeStream() for per-project queues: consumer loop (for await) provides natural FIFO serialization without explicit locking"
  - "CommandHistoryStore as actor: actor isolation prevents concurrent file access when multiple projects complete commands simultaneously"
  - "exitCode() and didCrash() added to ProcessActor: CommandRunnerService needs post-completion exit code and termination reason for state classification"
  - "Crashed state detected via proc.terminationReason == .uncaughtSignal after stream completion"
  - "Auto-retry enqueues new CommandRequest (not reusing run ID): distinct run identity for history clarity"
  - "loadForProject() called with await from @MainActor context: Swift 6 requires await for all cross-actor calls, even for synchronous actor methods"

patterns-established:
  - "_Concurrency.Task: All Task { } blocks in Services/ must use _Concurrency.Task prefix (GSDMonitor.Task shadowing is module-wide)"
  - "Per-project key pattern: [String: T] dictionaries keyed by projectPath.path string throughout CommandRunnerService"

requirements-completed: [PROC-01, SAFE-01]

duration: 3min
completed: 2026-02-17
---

# Phase 13 Plan 03: CommandRunnerService + CommandHistoryStore Summary

**@MainActor @Observable CommandRunnerService wiring ProcessActor, ShellEnvironmentService, and GSDOutputParser into per-project FIFO queues (AsyncStream.makeStream), with CommandHistoryStore actor for atomic JSON persistence to ~/Library/Application Support/GSDMonitor/command-history.json**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-17T21:18:25Z
- **Completed:** 2026-02-17T21:21:12Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- CommandHistoryStore actor persists command history with 200-run-per-project trimming, atomic writes, and ISO8601 JSON encoding — safe against concurrent access and process crashes
- CommandRunnerService wires all Phase 13 foundation components: ShellEnvironmentService resolves claude path, ProcessActor executes with PTY, GSDOutputParser parses output, CommandHistoryStore persists results
- Per-project FIFO serialization via AsyncStream.makeStream(): each project has its own consumer loop that drains requests one at a time while different projects run in parallel
- Observable state (activeRuns, projectQueues, recentRuns) ready for Phase 14 UI binding without any refactoring
- ProcessActor extended with exitCode() and didCrash() for post-completion state classification (crashed vs failed)
- Zero Swift 6 strict concurrency warnings (only pre-existing AppDelegate warning unrelated to this plan)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create CommandHistoryStore for JSON persistence** - `6818b2d` (feat)
2. **Task 2: Create CommandRunnerService with per-project queues** - `6b1529c` (feat)

## Files Created/Modified

- `GSDMonitor/Services/CommandHistoryStore.swift` - actor: JSON persistence, loadAll/loadForProject/save/removeQueuedCommand, 200-run trim, atomic writes
- `GSDMonitor/Services/CommandRunnerService.swift` - @MainActor @Observable: enqueue/cancel/removeQueuedCommand/rerun/loadHistory, AsyncStream per-project queues, executeCommand full lifecycle
- `GSDMonitor/Services/ProcessActor.swift` - Added exitCode() and didCrash() methods for post-completion state classification
- `GSDMonitor.xcodeproj/project.pbxproj` - Registered CommandHistoryStore.swift and CommandRunnerService.swift in Services group and Sources build phase

## Decisions Made

- **AsyncStream.makeStream() per-project queue:** The consumer loop's `for await request in stream` naturally serializes commands — the loop blocks on each `executeCommand()` call until it returns, then takes the next request. This gives FIFO order without explicit locking or semaphores.
- **exitCode() and didCrash() on ProcessActor:** CommandRunnerService needs the process exit code and termination reason after the output stream closes. These are synchronous methods safe to call post-completion since the stream finishing guarantees the process has terminated.
- **loadForProject with await:** Swift 6 requires `await` for all cross-actor method calls, even synchronous ones, since the actor's executor must be entered. Fixed `try? await historyStore.loadForProject(projectPath)`.
- **Crashed state distinct from failed:** `proc.terminationReason == .uncaughtSignal` (SIGSEGV, SIGBUS, etc.) maps to `.crashed`. Normal non-zero exit maps to `.failed`. User SIGINT cancellation maps to `.cancelled`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added exitCode() and didCrash() to ProcessActor**
- **Found during:** Task 2 (CommandRunnerService implementation)
- **Issue:** Plan specified `await processActor.exitCode()` and `await processActor.didCrash()` but ProcessActor only exposed `isRunning()` and `processIdentifier()`. These methods are required for CommandRunnerService to classify terminal states.
- **Fix:** Added `func exitCode() -> Int32?` (returns `proc.terminationStatus` when not running) and `func didCrash() -> Bool` (returns `proc.terminationReason == .uncaughtSignal`) to ProcessActor
- **Files modified:** GSDMonitor/Services/ProcessActor.swift
- **Verification:** Build succeeds with zero errors; methods logically correct (process is guaranteed terminated after stream finish)
- **Committed in:** 6b1529c (Task 2 commit)

**2. [Rule 1 - Bug] Swift 6 actor isolation: loadForProject requires await**
- **Found during:** Task 2 build (first build attempt)
- **Issue:** `(try? historyStore.loadForProject(projectPath)) ?? []` — Swift 6 error: "actor-isolated instance method 'loadForProject' cannot be called from outside of the actor". Even synchronous actor methods require await from outside.
- **Fix:** Changed to `(try? await historyStore.loadForProject(projectPath)) ?? []`
- **Files modified:** GSDMonitor/Services/CommandRunnerService.swift
- **Verification:** Build succeeds with zero errors
- **Committed in:** 6b1529c (Task 2 commit)

**3. [Rule 1 - Bug] Dead code: unused retryRun variable**
- **Found during:** Task 2 code review before commit
- **Issue:** `var retryRun = CommandRun.fromRequest(retryRequest)` was created and `autoRetried` set but `retryRun` was never used — only `retryRequest` was enqueued. The `autoRetried` marking on the retry run would happen via the run's `fromRequest` + execution path, not pre-set.
- **Fix:** Removed the dead code block
- **Files modified:** GSDMonitor/Services/CommandRunnerService.swift
- **Verification:** Build succeeds, auto-retry logic intact
- **Committed in:** 6b1529c (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (1 Rule 2 - Missing Critical, 2 Rule 1 - Bug)
**Impact on plan:** All three fixes were necessary for compilation and correctness under Swift 6. No scope creep.

## Issues Encountered

The Task 1 and Task 2 pbxproj registrations had to be done together (both files registered before either file existed on disk), because Xcode's build system fails immediately if any registered source file is missing — even if that file belongs to a different task. This was handled correctly by registering both in pbxproj during Task 1's work, then creating both files before any build verification.

## Next Phase Readiness

- Phase 13 Process Foundation is complete: all three plans delivered
- CommandRunnerService is the single entry point Phase 14 needs: enqueue(), cancelRunningCommand(), removeQueuedCommand(), rerun(), loadHistory()
- Observable state properties are ready: activeRuns, projectQueues, recentRuns
- History persistence works across app restarts via CommandHistoryStore
- **Important carry-forward for Phase 14:** CommandRunnerService is @MainActor — UI code calling it should be on MainActor or use await for cross-actor calls

## Self-Check: PASSED

- CommandHistoryStore.swift: FOUND
- CommandRunnerService.swift: FOUND
- 13-03-SUMMARY.md: FOUND
- Commit 6818b2d: FOUND (Task 1 - CommandHistoryStore)
- Commit 6b1529c: FOUND (Task 2 - CommandRunnerService)
- Commit 8219930: FOUND (metadata)

---
*Phase: 13-process-foundation*
*Completed: 2026-02-17*
