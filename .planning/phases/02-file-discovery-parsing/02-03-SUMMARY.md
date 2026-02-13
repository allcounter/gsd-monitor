---
phase: 02-file-discovery-parsing
plan: 03
subsystem: parsing
tags:
  - tdd
  - markdown-parsing
  - swift-markdown
  - requirements
  - plans
dependency_graph:
  requires:
    - 02-01-foundation-services
  provides:
    - requirements-md-parsing
    - plan-md-parsing
  affects:
    - requirements-tracking
    - plan-status-monitoring
tech_stack:
  added: []
  patterns:
    - markup-walker-pattern
    - regex-based-parsing
    - sendable-structs
key_files:
  created:
    - GSDMonitor/Services/RequirementsParser.swift
    - GSDMonitor/Services/PlanParser.swift
    - GSDMonitorTests/RequirementsParserTests.swift
    - GSDMonitorTests/PlanParserTests.swift
  modified:
    - GSDMonitor.xcodeproj/project.pbxproj
decisions:
  - Use MarkupWalker for Requirements.md (structured markdown traversal)
  - Use regex-based parsing for PLAN.md (handles custom XML-like tags)
  - Test target infrastructure setup required (Ruby xcodeproj gem)
metrics:
  duration: 453s
  tasks_completed: 1
  files_created: 4
  files_modified: 1
  commits: 2
  completed_date: 2026-02-13
---

# Phase 02 Plan 03: Requirements & Plan Parsers Summary

RequirementsParser extracts REQ-IDs, categories, descriptions, checkbox status, and traceability mappings from REQUIREMENTS.md using MarkupWalker; PlanParser extracts phase/plan numbers, objective, and tasks from PLAN.md using regex-based frontmatter and XML-tag parsing.

## TDD Execution

### RED Phase (Commit d5ced56)

**Test Infrastructure Setup:**
- Created test target using Ruby xcodeproj gem (blocking issue - Rule 3)
- Added `GENERATE_INFOPLIST_FILE = YES` to test target settings
- Fixed `PRODUCT_MODULE_NAME` configuration

**Failing Tests Created:**
- RequirementsParserTests.swift
  - `testParseEmptyRequirements`: Empty content returns empty array
  - `testParseRequirementsWithCategories`: Extract REQ-IDs with categories
  - `testParseTraceabilityTable`: Extract phase mappings from traceability
  - `testParseNoTraceabilityTable`: Handle missing traceability gracefully
- PlanParserTests.swift
  - `testParseEmptyPlan`: Empty content returns nil
  - `testParsePlanWithPhaseAndPlanNumbers`: Extract phase/plan numbers from frontmatter
  - `testParseTaskTypes`: Distinguish between auto and checkpoint tasks
  - `testParseNoTasks`: Handle plans with empty task lists
  - `testParseMalformedFrontmatter`: Return nil for unparseable content

**Why tests failed:** Parsers did not exist yet (expected RED phase behavior).

### GREEN Phase (Commit 075b5e0)

**RequirementsParser Implementation:**
- Uses `MarkupWalker` struct conforming to swift-markdown visitor pattern
- `visitHeading(_ heading: Heading)`: Tracks H3 headings as category names
- `visitListItem(_ listItem: ListItem)`: Extracts requirements from checkbox list items
  - Regex pattern: `**REQ-ID**: Description`
  - Checkbox state: `[x]` = validated, `[ ]` = active
- `extractTraceability(from: String)`: Parses Traceability table via string scanning
  - Matches pattern: `| REQ-ID | Phase N | Status |`
  - Extracts phase number from "Phase N" text
- Merges traceability mappings into requirement structs

**PlanParser Implementation:**
- `extractFrontmatter(from: String)`: Extracts YAML between first two `---` delimiters
- `extractPhaseNumber(from frontmatter: String)`: Regex `phase:\s*(\d+)`
- `extractPlanNumber(from frontmatter: String)`: Regex `plan:\s*(\d+)`
- `extractObjective(from: String)`: Content between `<objective>` and `</objective>` tags
- `extractTasks(from: String)`: Regex `<task\s+type="([^"]+)">\s*<name>(?:Task\s+\d+:\s*)?([^<]+)</name>`
  - Strips "Task N: " prefix from task names
  - Maps `type="auto"` → TaskType.auto
  - Maps `type="checkpoint:*"` → TaskType.checkpoint

**Test Results:**
```
Test Suite 'PlanParserTests' passed (5 tests, 0.003s)
Test Suite 'RequirementsParserTests' passed (4 tests, 0.008s)
** TEST SUCCEEDED **
```

### REFACTOR Phase

Skipped - implementations are clean and meet requirements. No obvious refactoring needed.

## Deviations from Plan

**Auto-fixed Issues:**

**1. [Rule 3 - Blocking issue] Test target infrastructure missing**
- **Found during:** RED phase setup
- **Issue:** No test target existed in Xcode project, preventing TDD workflow
- **Fix:** Created test target programmatically using Ruby xcodeproj gem with proper Swift 6 configuration
- **Files modified:** GSDMonitor.xcodeproj/project.pbxproj
- **Commit:** Included in d5ced56

**2. [Rule 1 - Bug] MarkupWalker API misunderstanding**
- **Found during:** GREEN phase implementation
- **Issue:** Initial implementation used class-based walker with override methods. swift-markdown uses struct-based protocol with mutating methods.
- **Fix:** Changed to `struct RequirementsWalker: MarkupWalker` with `mutating func` visitor methods
- **Files modified:** GSDMonitor/Services/RequirementsParser.swift
- **Commit:** Included in 075b5e0

**3. [Rule 2 - Missing critical functionality] Test files with wrong extensions**
- **Found during:** GREEN phase testing
- **Issue:** Test files appeared with `.future` extensions from previous incomplete plan execution
- **Fix:** Restored correct files from git commit, removed extraneous files
- **Files affected:** GSDMonitorTests/*.swift
- **Commit:** Fixed before 075b5e0

## Verification Results

All success criteria met:

- [x] RequirementsParser produces [Requirement] from markdown with correct IDs, categories, descriptions, statuses
- [x] PlanParser produces Plan from PLAN.md string with correct phase/plan numbers, objective, tasks
- [x] Both parsers handle missing/malformed input without crashing
- [x] Test suite passes with happy path + edge case coverage
- [x] Zero Swift 6 warnings

**Build output:** `** BUILD SUCCEEDED **` with zero compiler warnings

**Test output:**
```
Test Suite 'All tests' passed at 2026-02-13 20:18:31.469
 Executed 9 tests, with 0 failures (0 unexpected) in 0.011 (0.014) seconds
```

## Architecture Notes

**RequirementsParser Design:**
- Uses swift-markdown's MarkupWalker for structured document traversal
- Maintains state (`currentCategory`) across visitor calls
- Two-pass approach: AST walk + string-based traceability extraction
- Traceability table uses string parsing (not in markdown AST)

**PlanParser Design:**
- String-based parsing (not MarkupWalker) due to custom XML-like tags in PLAN.md
- YAML frontmatter extracted via delimiter scanning
- Regex patterns for structured extraction
- Defensive: returns `nil` for unparseable content

**swift-markdown Integration:**
- MarkupWalker is a protocol requiring `Result == Void`
- Methods are `mutating` (walker is a struct, not class)
- Visitor pattern: implement specific `visit*` methods
- `descendInto(_ markup: Markup)` continues tree traversal

## Dependencies

**Existing:**
- swift-markdown@0.7.3 (from Plan 02-01)
- Foundation (regex, string manipulation)

**Test Infrastructure:**
- XCTest framework
- Test target with Swift 6 strict concurrency
- Ruby xcodeproj gem (for project manipulation)

## Next Steps

Phase 02 Plan 04 can now:
- Use RequirementsParser to load REQUIREMENTS.md from .planning/ directories
- Use PlanParser to load PLAN.md files from phase directories
- Build requirement tracking UI showing REQ-IDs and traceability
- Display plan status with task-level detail
- Integrate with ProjectDiscoveryService from Plan 02-01

## Self-Check: PASSED

Verification results:
- FOUND: GSDMonitor/Services/RequirementsParser.swift
- FOUND: GSDMonitor/Services/PlanParser.swift
- FOUND: GSDMonitorTests/RequirementsParserTests.swift
- FOUND: GSDMonitorTests/PlanParserTests.swift
- FOUND: commit d5ced56 (RED phase)
- FOUND: commit 075b5e0 (GREEN phase)
- VERIFIED: All 9 tests pass
- VERIFIED: Zero Swift 6 warnings
