---
phase: 12-milestone-timeline
plan: 01
subsystem: data-model
tags: [swift, milestone, roadmap-parser, codable, identifiable, sendable, regex]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: Phase struct and PhaseStatus enum used in Milestone.isComplete derivation
  - phase: 02-file-discovery
    provides: RoadmapParser infrastructure that parseMilestones() extends
provides:
  - Milestone struct (Identifiable, Sendable) with name, phaseNumbers, isComplete
  - Roadmap.milestones field populated by parser, excluded from Codable
  - parseMilestones() extracting milestones from ## Milestones section of ROADMAP.md
affects: [12-02-milestone-timeline-views]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Derived field pattern: milestones excluded from CodingKeys, set to [] in init(from decoder:)
    - Regex milestone parsing: NSRegularExpression extracts name + phase range from bullet format

key-files:
  created: []
  modified:
    - GSDMonitor/Models/Roadmap.swift
    - GSDMonitor/Services/RoadmapParser.swift

key-decisions:
  - "Milestone is NOT Codable — derived at parse time, excluded from CodingKeys to preserve existing JSON encode/decode"
  - "isComplete derived from phases.allSatisfy { .done } — single source of truth, no duplication"
  - "Graceful degradation: parseMilestones returns [] if no ## Milestones section (projects without milestone structure)"

patterns-established:
  - "Derived data pattern: add non-Codable fields to Codable structs via custom init(from decoder:) that sets field to default"

requirements-completed: [DASH-03]

# Metrics
duration: 1min
completed: 2026-02-17
---

# Phase 12 Plan 01: Milestone Data Model and Parser Summary

**Milestone struct and RoadmapParser extension extracting milestone groupings from ROADMAP.md ## Milestones section, with isComplete derived from phase statuses**

## Performance

- **Duration:** ~1 min
- **Started:** 2026-02-17T11:45:01Z
- **Completed:** 2026-02-17T11:46:01Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `Milestone` struct with `Identifiable` + `Sendable` conformance, `name`, `phaseNumbers`, `isComplete` fields
- Extended `Roadmap` with `milestones: [Milestone]` field excluded from Codable via explicit CodingKeys + custom decoder init
- Added `parseMilestones()` to `RoadmapParser` using regex to extract milestone name and phase range from `## Milestones` section
- This project's ROADMAP.md will produce 2 milestones: v1.0 MVP (phases 1-5, complete) and v1.1 Visual Overhaul (phases 6-12, not complete)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Milestone struct and milestones field to Roadmap** - `64b4586` (feat)
2. **Task 2: Extend RoadmapParser to parse milestone sections** - `bfac9a0` (feat)

## Files Created/Modified

- `GSDMonitor/Models/Roadmap.swift` - Added Milestone struct; Roadmap gains milestones field with custom Codable init
- `GSDMonitor/Services/RoadmapParser.swift` - Added parseMilestones() method; parse() now passes milestones to Roadmap init

## Decisions Made

- Milestone is NOT Codable — it is derived at parse time, excluded from CodingKeys. This preserves existing JSON encode/decode without any changes to consumers.
- `isComplete` derived from `phases.allSatisfy { $0.status == .done }` — single source of truth derived from already-parsed data, no duplication.
- Graceful degradation: if no `## Milestones` section exists, return empty array. Timeline views in Plan 02 simply won't render, which is correct behavior for projects without milestone structure.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `Roadmap.milestones` populated by parser and ready for Plan 02 timeline views
- Plan 02 can access `roadmap.milestones` directly in SwiftUI views
- Both milestones carry `phaseNumbers: [Int]` enabling MilestoneGroupView to filter the phases array

---
*Phase: 12-milestone-timeline*
*Completed: 2026-02-17*
