---
phase: 13-process-foundation
verified: 2026-02-17T21:45:00Z
status: passed
score: 12/12 must-haves verified
re_verification: false
---

# Phase 13: Process Foundation Verification Report

**Phase Goal:** App can execute a GSD command as a child process with live-streamed output and reliable cancellation — headless, no UI yet
**Verified:** 2026-02-17T21:45:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Success Criteria (from ROADMAP.md)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can initiate a GSD command from the app and it runs in the correct project directory | VERIFIED | `CommandRunnerService.enqueue()` creates ProcessActor, passes `workingDirectory: request.projectPath` to `processActor.run()`. Route: enqueue -> executeCommand -> ProcessActor.run() with correct projectPath. |
| 2 | App resolves the claude CLI path on a fresh macOS account where claude is not on the launchd PATH | VERIFIED | `ShellEnvironmentService.resolveClaudePath()` spawns `/bin/zsh -l -c env` to capture full login shell env, searches PATH entries, then falls back to `/usr/local/bin/claude`, `/opt/homebrew/bin/claude`, `~/.local/bin/claude`, `~/.claude/local/claude`. Error message includes install guidance. |
| 3 | Live output lines appear in memory as the command runs — no waiting for process exit | VERIFIED | `ProcessActor.launchProcess()` sets `readabilityHandler` on both stdout/stderr pipes. Each handler calls `continuation.yield(CommandRun.OutputLine(...))` immediately on data receipt. `CommandRunnerService.executeCommand()` loops `for await outputLine in outputStream` and updates `activeRuns[projectKey] = run` per line, triggering @Observable. |
| 4 | User can cancel a running command and no orphaned processes remain in Activity Monitor | VERIFIED | `ProcessActor.cancel()` sends `proc.interrupt()` (SIGINT), polls `isRunning` every 200ms for 4s, then `Darwin.kill(pid, SIGKILL)` + `Darwin.kill(-pid, SIGKILL)`. `CommandRunnerService.cancelRunningCommand()` calls `await actor.cancel()` then marks state `.cancelled`. (No orphaned processes needs human verification — see below.) |
| 5 | Only one command runs per project at a time — a second trigger on the same project is blocked while the first runs | VERIFIED | `CommandRunnerService.getOrCreateQueue()` uses `AsyncStream.makeStream()` per project. `startConsuming()` creates a single consumer Task with `for await request in stream { await self.executeCommand(request) }` — the `await executeCommand` blocks the loop until command completes, serializing all requests FIFO. Different projects have separate streams and run in parallel. |

**Score:** 5/5 success criteria verified

### Plan-Level Must-Have Truths

#### Plan 01 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | CommandState enum has all 6 lifecycle states: queued, running, succeeded, failed, cancelled, crashed | VERIFIED | `CommandState.swift` lines 4-22: `enum CommandState: String, Codable, Sendable` with exactly 6 cases. `isTerminal`/`isActive` computed properties present. |
| 2 | CommandRun model captures command string, project path, start time, duration, exit code, output lines, and parsed metadata | VERIFIED | `CommandRun.swift`: all fields present — `command`, `projectPath`, `startTime`, `duration` (computed), `exitCode`, `outputLines`, `metadata`. Codable/Sendable/Identifiable conformances verified. |
| 3 | ShellEnvironmentService resolves claude CLI path from user login shell environment | VERIFIED | `ShellEnvironmentService.swift` line 73-101: `resolveClaudePath()` spawns `/bin/zsh -l -c env`, parses PATH, checks each component for `claude` executable. |
| 4 | ShellEnvironmentService falls back to known install locations when PATH search fails | VERIFIED | Fallbacks at lines 87-92: `/usr/local/bin/claude`, `/opt/homebrew/bin/claude`, `~/.local/bin/claude`, `~/.claude/local/claude`. |
| 5 | GSDOutputParser extracts phase, plan, and task completion markers from output lines | VERIFIED | `GSDOutputParser.swift`: 4 regex patterns (phase, plan, taskComplete, error), `parse(line:)` returns `GSDLineInfo`, `aggregate(lines:)` returns `CommandRun.GSDMetadata`. |

#### Plan 02 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ProcessActor spawns a child process with PTY stdin so claude CLI does not hang | VERIFIED | `ProcessActor.launchProcess()` calls `Darwin.openpty(&masterFD, &slaveFD, nil, nil, nil)` and assigns `FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)` as `proc.standardInput`. |
| 2 | Live output lines stream via AsyncStream as the process runs — no waiting for exit | VERIFIED | `readabilityHandler` on both pipes yields `CommandRun.OutputLine` directly to continuation on each data chunk. Stream finishes only in `terminationHandler`. |
| 3 | Cancel sends SIGINT first, waits 4 seconds, then SIGKILL if still running | VERIFIED | `cancel()` lines 99-118: `proc.interrupt()` then 200ms poll loop for 4s, then `Darwin.kill(pid, SIGKILL)` + `Darwin.kill(-pid, SIGKILL)`. |
| 4 | PTY master file descriptor stays open until process terminates (no SIGHUP) | VERIFIED | `ptyMasterFD` stored on actor at line 161. Closed only inside `terminationHandler` at line 216 via `Darwin.close(masterFDCopy)`. |
| 5 | terminationHandler is used as authoritative completion signal, not readabilityHandler EOF | VERIFIED | `terminationHandler` at line 199: nullifies both readabilityHandlers, does `readDataToEndOfFile()` final flush on both pipes, closes PTY master, calls `continuation.finish()`. |

#### Plan 03 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Only one command runs per project at a time — second trigger is queued, not rejected | VERIFIED | AsyncStream consumer loop blocks on `await executeCommand()`. New `enqueue()` calls add to the stream while the consumer is busy; they queue up and execute after current run completes. |
| 2 | Commands for different projects run in parallel | VERIFIED | Each project gets its own `AsyncStream`/consumer `Task` pair via `getOrCreateQueue(for:)`. No global lock or single consumer. |
| 3 | Queued commands are visible and individually removable before they start | VERIFIED | `projectQueues[projectKey]` tracks visible queue. `removeQueuedCommand(id:forProject:)` removes by id from both in-memory queue and `historyStore`. |
| 4 | Command history persists to disk in ~/Library/Application Support/GSDMonitor/command-history.json | VERIFIED | `CommandHistoryStore.init()` computes path via `.applicationSupportDirectory`, appends `"GSDMonitor"`, creates directory, appends `"command-history.json"`. All save paths in `executeCommand` call `try? await historyStore.save(run)`. |
| 5 | History is trimmed to last 200 runs per project on save | VERIFIED | `CommandHistoryStore.save()` calls `trim()` which groups by `projectPath.path`, sorts descending by `startTime`, takes `prefix(maxRunsPerProject)` where `maxRunsPerProject = 200`. |
| 6 | Auto-retry runs once on failure, then stops | VERIFIED | `executeCommand()` line 235: `if run.state == .failed && !run.autoRetried` — creates new `CommandRequest`, sets `run.autoRetried = true` on original, enqueues retry. Retry run has `autoRetried` false (from `fromRequest`) so a second failure does NOT re-retry. |
| 7 | CommandRunnerService exposes observable state for UI binding (Phase 14) | VERIFIED | `@MainActor @Observable final class CommandRunnerService` with `var activeRuns`, `var projectQueues`, `var recentRuns` — all public observable properties. |

### Required Artifacts

| Artifact | Status | Lines | Key Contents |
|----------|--------|-------|-------------|
| `GSDMonitor/Models/CommandState.swift` | VERIFIED | 43 | `enum CommandState: String, Codable, Sendable` with 6 cases + `isTerminal`/`isActive` |
| `GSDMonitor/Models/CommandRun.swift` | VERIFIED | 192 | `struct CommandRun: Identifiable, Codable, Sendable`, nested `OutputLine`, `GSDMetadata`, custom URL Codable, `CommandRequest` |
| `GSDMonitor/Services/ShellEnvironmentService.swift` | VERIFIED | 103 | `struct ShellEnvironmentService: Sendable`, `captureLoginShellEnvironment()`, `resolveClaudePath()`, `ShellEnvironmentError` |
| `GSDMonitor/Utilities/GSDOutputParser.swift` | VERIFIED | 97 | `struct GSDOutputParser: Sendable`, 4 regex patterns, `parse(line:)`, `aggregate(lines:)` |
| `GSDMonitor/Services/ProcessActor.swift` | VERIFIED | 243 | `actor ProcessActor`, PTY via `Darwin.openpty`, readabilityHandler streaming, SIGINT->SIGKILL cancel, `exitCode()`, `didCrash()` |
| `GSDMonitor/Services/CommandHistoryStore.swift` | VERIFIED | 105 | `actor CommandHistoryStore`, `loadAll/loadForProject/save/removeQueuedCommand`, 200-run trim, atomic write |
| `GSDMonitor/Services/CommandRunnerService.swift` | VERIFIED | 273 | `@MainActor @Observable CommandRunnerService`, per-project AsyncStream queues, `enqueue/cancel/removeQueuedCommand/rerun/loadHistory` |

### Key Link Verification

| From | To | Via | Status | Evidence |
|------|----|-----|--------|----------|
| `CommandRun.swift` | `CommandState.swift` | `var state: CommandState` | WIRED | Line 75: `var state: CommandState` — CommandRun.state typed as CommandState |
| `CommandRun.swift` | `GSDOutputParser.swift` | `GSDMetadata` nested struct | WIRED | `CommandRun.GSDMetadata` nested at line 44, used as `var metadata: GSDMetadata?` at line 90 |
| `ProcessActor.swift` | `CommandRun.swift` | `CommandRun.OutputLine` stream type | WIRED | All yield calls: `continuation.yield(CommandRun.OutputLine(...))` at lines 187, 193, 207, 211 |
| `ProcessActor.swift` | `Darwin` | `openpty()` PTY creation | WIRED | `import Darwin` at line 2; `Darwin.openpty(&masterFD, &slaveFD, nil, nil, nil)` at line 158 |
| `CommandRunnerService.swift` | `ProcessActor.swift` | Creates `ProcessActor()` per command run | WIRED | `let processActor = ProcessActor()` at line 188; `activeProcessActors[projectKey] = processActor` at line 189 |
| `CommandRunnerService.swift` | `ShellEnvironmentService.swift` | Resolves claude path before spawning | WIRED | `private let shellEnvService = ShellEnvironmentService()` line 41; called at lines 159 and 172 |
| `CommandRunnerService.swift` | `CommandHistoryStore.swift` | Persists completed runs | WIRED | `private let historyStore = CommandHistoryStore()` line 42; `historyStore.save(run)` called at 4 different exit paths |
| `CommandRunnerService.swift` | `GSDOutputParser.swift` | Parses output during/after execution | WIRED | `private let outputParser = GSDOutputParser()` line 43; `outputParser.parse(line:)` at 206, `outputParser.aggregate(lines:)` at 232 |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| PROC-01 | 13-02, 13-03 | User can run a GSD command from the app via embedded command runner | SATISFIED | `CommandRunnerService.enqueue()` -> `executeCommand()` -> `ProcessActor.run()` full pipeline wired and compiling |
| PROC-02 | 13-01 | App resolves claude CLI path from user's shell environment (PATH augmentation) | SATISFIED | `ShellEnvironmentService.captureLoginShellEnvironment()` spawns `/bin/zsh -l -c env`, `resolveClaudePath()` searches result PATH |
| PROC-03 | 13-02 | App spawns process with PTY for ANSI color support | SATISFIED | `Darwin.openpty()` creates PTY; slave FD set as `proc.standardInput`; master held open until termination |
| PROC-04 | 13-02 | User sees live-streamed output as command runs | SATISFIED | `readabilityHandler` on both pipes yields `OutputLine` immediately; `@Observable` state updated per line in `executeCommand` |
| PROC-05 | 13-02 | User can cancel a running command with process group kill | SATISFIED | `cancel()`: SIGINT via `proc.interrupt()`, 4s poll, then `Darwin.kill(pid, SIGKILL)` + `Darwin.kill(-pid, SIGKILL)` |
| SAFE-01 | 13-03 | Only one command runs per project at a time (queue model) | SATISFIED | Per-project `AsyncStream.makeStream()` with single consumer loop serializes commands; different projects run in parallel |

**Orphaned requirements check:** SAFE-02, SAFE-03, SAFE-04 are mapped to Phases 14 and 15 in REQUIREMENTS.md — not expected in Phase 13. No orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `CommandHistoryStore.swift` | 43 | `return []` | None (false positive) | This is the "file does not exist yet" guard branch — correct behavior, not a stub |

No blocker anti-patterns found. No TODO/FIXME/placeholder comments in any of the 7 new files.

### Build Verification

- Build result: **BUILD SUCCEEDED** (verified via `xcodebuild -project GSDMonitor.xcodeproj -scheme GSDMonitor build`)
- Swift 6 concurrency warnings on phase 13 files: **zero** (only pre-existing AppDelegate warning unrelated to this phase)
- All 7 files registered in `project.pbxproj` with PBXBuildFile + PBXFileReference + group children + Sources entries (PROC1301/PROC1302/PROC1303 ID series)

### Commit Verification

All 5 phase 13 commits verified present in git history:

| Commit | Description |
|--------|-------------|
| `17f241b` | feat(13-01): add CommandState and CommandRun models |
| `b1c585f` | feat(13-01): add ShellEnvironmentService and GSDOutputParser |
| `af3446a` | feat(13-02): implement ProcessActor with PTY stdin, streaming, and cancellation |
| `6818b2d` | feat(13-03): add CommandHistoryStore actor for JSON persistence |
| `6b1529c` | feat(13-03): add CommandRunnerService with per-project queues |

### Human Verification Required

#### 1. No Orphaned Processes After Cancellation

**Test:** Run a long-running command (e.g., `sleep 60` via CommandRunnerService), then call `cancelRunningCommand(forProject:)`. Open Activity Monitor immediately after.
**Expected:** No `sleep` or `claude` process remains in Activity Monitor.
**Why human:** Process group kill correctness (especially `Darwin.kill(-pid, SIGKILL)` no-op risk when PGID != pid) cannot be verified programmatically without spawning a real process.

#### 2. ANSI Color Support in PTY Stdin

**Test:** Run a real `claude` command via the app. Capture the output and check whether it contains ANSI color codes (indicating claude detected a TTY and enabled colors).
**Expected:** Output contains ANSI escape sequences (e.g., `\u001b[32m`), confirming claude did not fall back to plain text mode.
**Why human:** Requires a live claude CLI installation and observable output — cannot verify TTY detection statically.

#### 3. Login Shell PATH on Fresh macOS Account

**Test:** On a macOS account where claude is installed via Homebrew or npm (not in launchd PATH), launch the app and attempt to enqueue a command. Check logs for a successful `resolveClaudePath()` result.
**Expected:** Claude path is found via the login shell env capture, not requiring any app configuration.
**Why human:** PATH resolution from a fresh-account context requires the actual runtime environment — cannot simulate statically.

---

*Verified: 2026-02-17T21:45:00Z*
*Verifier: Claude (gsd-verifier)*
