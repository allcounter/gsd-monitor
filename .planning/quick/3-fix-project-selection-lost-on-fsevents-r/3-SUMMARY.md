---
phase: quick
plan: 3
subsystem: ui
tags: [swiftui, uuid, cryptokit, fsevents, state-management]

# Dependency graph
requires:
  - phase: quick-2
    provides: Plan status parsing based on SUMMARY.md existence
provides:
  - Deterministic UUID generation from project path using SHA-256
  - Stable project selection across FSEvents-triggered reloads
affects: [future sidebar state management, project persistence]

# Tech tracking
tech-stack:
  added: [CryptoKit for SHA-256 hashing]
  patterns: [Deterministic ID generation from file paths, optional-with-fallback initializer pattern]

key-files:
  created: []
  modified: [GSDMonitor/Models/Project.swift]

key-decisions:
  - "SHA-256 hash of path.path creates deterministic UUID (first 16 bytes of hash become UUID bytes)"
  - "Optional id parameter in manual init with deterministicID(from:) fallback preserves Codable path"
  - "Codable init(from decoder:) completely unchanged - continues reading stored UUID from JSON"

patterns-established:
  - "Static deterministicID(from:) factory pattern for path-based stable identifiers"
  - "Optional parameter with computed fallback in manual init to avoid breaking Codable"

# Metrics
duration: 0m 49s
completed: 2026-02-16
---

# Quick Task 3: Fix Project Selection Lost on FSEvents Summary

**Deterministic UUID generation from project path ensures sidebar selection survives FSEvents-triggered reloads**

## Performance

- **Duration:** 0m 49s
- **Started:** 2026-02-16T01:28:19Z
- **Completed:** 2026-02-16T01:29:08Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Project selection in sidebar now persists across file change reloads
- Same project directory always produces identical UUID regardless of when parsed
- Codable JSON decoding path completely preserved (stored IDs still read from cache)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add deterministic UUID generation and wire it into project parsing** - `8e6f623` (feat)

## Files Created/Modified
- `GSDMonitor/Models/Project.swift` - Added CryptoKit import, deterministicID(from:) static method, optional id parameter with deterministic fallback

## Decisions Made

**1. SHA-256 hash approach for deterministic UUID**
Used SHA-256 hash of `path.path` string, taking first 16 bytes to construct UUID. Ensures same path always generates same UUID across app launches and FSEvents reloads.

**2. Optional id parameter pattern**
Changed manual init from `id: UUID = UUID()` to `id: UUID? = nil` with `self.id = id ?? Project.deterministicID(from: path)`. This preserves Codable decoding path (which provides non-nil id from JSON) while making programmatic creation deterministic.

**3. No changes to ProjectService**
The existing `Project(name:path:...)` call in parseProject already omits the id parameter, so it automatically inherits the deterministic behavior without any service-layer changes.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - straightforward implementation with clean separation between Codable and manual initialization paths.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Sidebar selection state is now stable. Future work on project persistence or state management can rely on deterministic UUIDs for project identification.

## Self-Check: PASSED

Files verified:
- GSDMonitor/Models/Project.swift: FOUND

Commits verified:
- 8e6f623: FOUND

---
*Phase: quick*
*Completed: 2026-02-16*
