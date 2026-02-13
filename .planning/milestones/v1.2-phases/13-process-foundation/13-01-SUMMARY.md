---
phase: 13-process-foundation
plan: "01"
subsystem: process-execution-engine
tags: [models, services, utilities, swift6, concurrency, shell-environment]
dependency_graph:
  requires: []
  provides: [CommandState, CommandRun, CommandRequest, ShellEnvironmentService, GSDOutputParser, GSDLineInfo]
  affects: []
tech_stack:
  added: []
  patterns: [Codable-URL-encoding, nonisolated-unsafe-regex, async-throws-subprocess]
key_files:
  created:
    - GSDMonitor/Models/CommandState.swift
    - GSDMonitor/Models/CommandRun.swift
    - GSDMonitor/Services/ShellEnvironmentService.swift
    - GSDMonitor/Utilities/GSDOutputParser.swift
  modified:
    - GSDMonitor.xcodeproj/project.pbxproj
decisions:
  - "nonisolated(unsafe) on Regex static properties: Swift 6 does not recognize Regex<...> as Sendable even though they are immutable; nonisolated(unsafe) is the correct annotation for immutable shared state"
  - "CommandRun.GSDMetadata nested vs top-level: kept nested inside CommandRun per plan spec since it is exclusively used as a field of CommandRun"
  - "CommandRequest not Codable: only CommandRun (completed runs) is persisted; enqueued requests are ephemeral"
metrics:
  duration: "4 minutes"
  completed_date: "2026-02-17"
  tasks_completed: 2
  files_created: 4
  files_modified: 1
requirements_fulfilled: [PROC-02]
---

# Phase 13 Plan 01: Process Foundation Data Models Summary

Foundation types for the GSD command execution engine: CommandState 6-case lifecycle enum, CommandRun Codable/Sendable model with nested OutputLine/GSDMetadata, ShellEnvironmentService for login shell PATH capture and claude CLI discovery, and GSDOutputParser for extracting GSD metadata from command output lines.

## Tasks Completed

| # | Task | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Create CommandState and CommandRun models | 17f241b | CommandState.swift, CommandRun.swift, project.pbxproj |
| 2 | Create ShellEnvironmentService and GSDOutputParser | b1c585f | ShellEnvironmentService.swift, GSDOutputParser.swift |

## What Was Built

### CommandState (GSDMonitor/Models/CommandState.swift)
- `enum CommandState: String, Codable, Sendable` with exactly 6 cases:
  - `queued`, `running`, `succeeded`, `failed`, `cancelled`, `crashed`
- `isTerminal: Bool` — true for succeeded/failed/cancelled/crashed
- `isActive: Bool` — true for queued/running
- Per user decision: cancelled and crashed are distinct from failed

### CommandRun (GSDMonitor/Models/CommandRun.swift)
- `struct CommandRun: Identifiable, Codable, Sendable`
- Properties: id, command, arguments, projectPath (URL), projectName, state, startTime, endTime, exitCode, outputLines, metadata, autoRetried
- Nested `OutputLine` struct with `Stream` enum (stdout/stderr)
- Nested `GSDMetadata` struct: phaseNumber, planNumber, tasksCompleted, hasErrors
- `duration: TimeInterval?` computed from startTime/endTime
- Custom URL Codable encoding/decoding matching Project.swift pattern (encode as path string)
- `CommandRequest: Sendable` (non-Codable, ephemeral) for queue enqueuing
- `static func fromRequest(_:startTime:) -> CommandRun` factory method

### ShellEnvironmentService (GSDMonitor/Services/ShellEnvironmentService.swift)
- `struct ShellEnvironmentService: Sendable` (nonisolated)
- `captureLoginShellEnvironment() async throws -> [String: String]` — spawns `/bin/zsh -l -c env`, parses KEY=VALUE output, handles values with embedded `=` characters
- `resolveClaudePath() async -> URL?` — searches shell PATH first, then fallbacks: `/usr/local/bin/claude`, `/opt/homebrew/bin/claude`, `~/.local/bin/claude`, `~/.claude/local/claude`
- `ShellEnvironmentError: Error, LocalizedError` with `parseFailure` and `claudeNotFound` cases
  - `claudeNotFound` message guides user: "Install via: npm install -g @anthropic-ai/claude-code"
- Per research pitfall 4: env is re-captured on each call (not cached)

### GSDOutputParser (GSDMonitor/Utilities/GSDOutputParser.swift)
- `struct GSDOutputParser: Sendable`
- `GSDLineInfo: Sendable` with phaseNumber, planNumber, isTaskComplete, isError
- `parse(line: String) -> GSDLineInfo` — extracts GSD metadata from a single output line
- `aggregate(lines: [GSDLineInfo]) -> CommandRun.GSDMetadata` — reduces line array into summary
- Swift Regex patterns: `/##?\s+Phase\s+(\d+)/`, `/[Pp]lan\s+(\d+)/`, task complete markers, error markers
- `nonisolated(unsafe)` on static Regex properties (Swift 6 strict concurrency fix — Regex not Sendable)
- Documented as LOW confidence per research (LLM output patterns need iteration)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Swift 6 strict concurrency: Regex static properties not Sendable**
- **Found during:** Task 2 build verification
- **Issue:** `static let` Regex literals in a `Sendable` struct triggered "non-'Sendable' type may have shared mutable state" errors for all 4 regex patterns in GSDOutputParser
- **Fix:** Added `nonisolated(unsafe)` annotation to each static Regex property. These are immutable constants (compiled at startup) — the annotation correctly communicates this is safe shared state
- **Files modified:** GSDMonitor/Utilities/GSDOutputParser.swift
- **Commit:** b1c585f

## Verification Results

- [x] Build succeeds with zero errors
- [x] All 4 new files appear in project.pbxproj (16 PROC1301 references: 4 PBXBuildFile + 4 PBXFileReference + 4 group children + 4 Sources)
- [x] CommandState has exactly 6 cases: queued, running, succeeded, failed, cancelled, crashed
- [x] CommandRun conforms to Identifiable, Codable, Sendable
- [x] ShellEnvironmentService.resolveClaudePath() compiles and returns Optional URL
- [x] GSDOutputParser.parse(line:) compiles and returns GSDLineInfo
- [x] No Swift 6 strict concurrency warnings on any new file (only pre-existing AppDelegate warning)

## Self-Check: PASSED

Files exist:
- GSDMonitor/Models/CommandState.swift: FOUND
- GSDMonitor/Models/CommandRun.swift: FOUND
- GSDMonitor/Services/ShellEnvironmentService.swift: FOUND
- GSDMonitor/Utilities/GSDOutputParser.swift: FOUND

Commits:
- 17f241b: FOUND (feat(13-01): add CommandState and CommandRun models)
- b1c585f: FOUND (feat(13-01): add ShellEnvironmentService and GSDOutputParser)
