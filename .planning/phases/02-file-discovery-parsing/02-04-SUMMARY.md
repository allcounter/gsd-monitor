---
phase: 02-file-discovery-parsing
plan: 04
subsystem: integration
tags:
  - project-service
  - ui-integration
  - observable-pattern
  - grouped-sidebar
dependency_graph:
  requires:
    - 02-01-foundation-services
    - 02-02-core-parsers
    - 02-03-requirements-plan-parsers
  provides:
    - project-coordination
    - manual-project-management
    - grouped-project-display
    - roadmap-visualization
  affects:
    - all-ui-features
    - phase-3-live-updates
tech_stack:
  added: []
  patterns:
    - observable-mainactor-service
    - grouped-list-sections
    - context-menu-actions
    - progress-visualization
key_files:
  created:
    - GSDMonitor/Services/ProjectService.swift
  modified:
    - GSDMonitor/Views/ContentView.swift
    - GSDMonitor/Views/SidebarView.swift
    - GSDMonitor/Views/DetailView.swift
    - GSDMonitor/Utilities/PreviewData.swift
    - GSDMonitor/Services/RoadmapParser.swift
    - GSDMonitor/Services/StateParser.swift
decisions:
  - Use @Observable pattern instead of ObservableObject for modern SwiftUI integration
  - Group projects by scan source in sidebar (~/Developer, Manually Added)
  - Progress bars calculated from phase.status == .done count
  - Context menus only on manually added projects (scan-discovered are read-only in UI)
  - Use _Concurrency.Task to avoid collision with Plan.Task model struct
metrics:
  duration: 466s
  tasks_completed: 2
  files_created: 1
  files_modified: 7
  commits: 2
  completed_date: 2026-02-13
---

# Phase 02 Plan 04: ProjectService Integration Summary

ProjectService coordinates discovery, parsing, and bookmarks; views display grouped projects with progress bars, manual add/remove, and parsed roadmap data in detail view.

## Tasks Completed

### Task 1: Create ProjectService coordinator
- **Commit:** c981bf8
- **Files:**
  - GSDMonitor/Services/ProjectService.swift (new)
  - GSDMonitor.xcodeproj/project.pbxproj
  - GSDMonitor/Services/RoadmapParser.swift (fixed)
  - GSDMonitor/Services/StateParser.swift (fixed)
- **What was done:**
  - Created `@MainActor @Observable final class ProjectService`
  - Orchestrates ProjectDiscoveryService, BookmarkService, and all parsers
  - `loadProjects()` async method loads from bookmarks and scans sources
  - `addProjectManually()` shows NSOpenPanel, validates .planning/, saves bookmark
  - `removeManualProject()` removes from array and deletes bookmark
  - `groupedProjects` computed property groups by scan source
  - Tracks manual vs scanned projects in UserDefaults
  - Deduplicates by path (manual projects take precedence)
  - Handles disappeared projects by removing stale bookmarks
  - Uses @Observable (not ObservableObject) per modern SwiftUI pattern

  **Parser fixes (deviation Rule 1):**
  - Fixed RoadmapParser and StateParser to use `struct` instead of `class`
  - Changed from `override func` to `mutating func` for MarkupWalker
  - Changed `walker.visit()` call to use `var walker` (mutable)
  - Fixed listItem text extraction: `format()` instead of `plainText`
  - These parsers were implemented incorrectly in Plan 02-02
  - Plan 02-03 summary documented struct pattern but 02-02 used class

### Task 2: Update views with ProjectService integration
- **Commit:** c766dbd
- **Files:**
  - GSDMonitor/Views/ContentView.swift
  - GSDMonitor/Views/SidebarView.swift
  - GSDMonitor/Views/DetailView.swift
  - GSDMonitor/Utilities/PreviewData.swift
- **What was done:**

  **ContentView:**
  - Added `@SwiftUI.State private var projectService = ProjectService()`
  - Uses `.task { await projectService.loadProjects() }` for launch scanning
  - Passes projectService to SidebarView
  - Finds selected project from `projectService.projects` by ID

  **SidebarView:**
  - Accepts `projectService: ProjectService` instead of `[Project]`
  - Groups projects by scan source using `ForEach(projectService.groupedProjects)`
  - Section headers show source path (e.g., "~/Developer", "Manually Added")
  - ProjectRow component shows name + progress bar
  - Progress calculated as: `completedPhases.count / totalPhases.count`
  - Toolbar button (plus icon) triggers `addProjectManually()`
  - Context menu on manually added projects: "Remove from GSD Monitor"
  - Uses `_Concurrency.Task` to avoid collision with `Plan.Task` model

  **DetailView:**
  - Shows project name as largeTitle
  - Displays current position from State: "Phase N, Plan M"
  - Lists roadmap phases with PhaseRow component
  - Each phase shows: number, name, goal, requirements, status badge
  - StatusBadge shows colored dot + text (gray/blue/green)
  - Empty state when no roadmap available
  - Scrollable content for long roadmaps

  **PreviewData:**
  - Full project with 3 phases (done, in progress, not started), state, config
  - Minimal project (name + path only)
  - Partial project (roadmap but no state)
  - `groupedProjects` static data for sidebar previews

## Verification Results

All success criteria met:

- [x] ProjectService coordinates discovery + parsing + bookmarks
- [x] Uses @Observable pattern (not ObservableObject)
- [x] Sidebar shows grouped projects with progress bars
- [x] Detail view shows parsed roadmap phases with status badges
- [x] Manual add via NSOpenPanel + toolbar button
- [x] Remove via context menu (manual projects only)
- [x] Bookmarks persist file access (UserDefaults storage)
- [x] App starts with no project selected (empty detail state)
- [x] Zero Swift 6 warnings

**Build output:** `** BUILD SUCCEEDED **` with zero compiler warnings

## Deviations from Plan

**Auto-fixed Issues:**

**1. [Rule 1 - Bug] RoadmapParser and StateParser used class instead of struct**
- **Found during:** Task 1 implementation
- **Issue:** Build errors: "method does not override any method from its superclass", "cannot use mutating member on immutable value". RoadmapParser and StateParser (from Plan 02-02) used `class RoadmapWalker: MarkupWalker` with `override func`, but swift-markdown MarkupWalker is a protocol requiring struct with `mutating func` (documented in Plan 02-03 summary).
- **Fix:** Changed walkers from class to struct, changed `override func` to `mutating func`, changed `let walker` to `var walker`, fixed listItem text extraction to use `format()` instead of `plainText`
- **Files modified:** GSDMonitor/Services/RoadmapParser.swift, GSDMonitor/Services/StateParser.swift
- **Commit:** Included in c981bf8

**2. [Rule 3 - Blocking issue] Parsers missing from Xcode project**
- **Found during:** Task 1 compilation
- **Issue:** Build errors: "cannot find 'RoadmapParser' in scope", "cannot find 'StateParser' in scope", "cannot find 'ConfigParser' in scope". RoadmapParser, StateParser, ConfigParser were created in prior plans but never added to Xcode project file.
- **Fix:** Used Ruby xcodeproj gem to add missing parser files to Services group and build phase. Also fixed incorrect paths for RequirementsParser and PlanParser.
- **Files modified:** GSDMonitor.xcodeproj/project.pbxproj
- **Commit:** Included in c981bf8

**3. [Rule 1 - Bug] Task type name collision**
- **Found during:** Task 2 compilation
- **Issue:** Build error: "trailing closure passed to parameter of type 'any Decoder' that does not accept a closure". Compiler confused Swift Concurrency's `Task` with `Plan.Task` model struct (both in scope).
- **Fix:** Used `_Concurrency.Task` to explicitly reference concurrency Task. Extracted button action into separate method for clarity.
- **Files modified:** GSDMonitor/Views/SidebarView.swift
- **Commit:** Included in c766dbd

All deviations were auto-fixed under Rules 1 and 3 (bugs and blocking issues). No architectural decisions required.

## Architecture Notes

**ProjectService Coordination:**
- Single source of truth for all projects
- @Observable makes it automatically trackable by SwiftUI
- @MainActor ensures all UI updates are main-thread safe
- Computed `groupedProjects` property derives UI structure from flat list
- UserDefaults stores both scanSources and manualProjectPaths

**Bookmark Lifecycle:**
- Manual projects saved with path as identifier
- Resolved on each loadProjects() call
- Stale bookmarks refreshed automatically (BookmarkService)
- Disappeared projects removed from tracking

**Project Grouping:**
- Projects grouped by source: scan sources first (alphabetical), then "Manually Added"
- Within groups: alphabetical by name
- Group membership determined by manualProjectPaths set

**Progress Calculation:**
- Count phases where `status == .done`
- Divide by total phases
- Linear ProgressView shows completion percentage
- Missing roadmap = no progress bar

**Task Name Collision:**
- Swift doesn't provide `Swift.Task` namespace
- Must use `_Concurrency.Task` to access concurrency Task
- Alternative: rename Plan.Task model to avoid collision (future consideration)

## Dependencies

**Services Used:**
- ProjectDiscoveryService (02-01)
- BookmarkService (02-01)
- RoadmapParser (02-02, fixed in 02-04)
- StateParser (02-02, fixed in 02-04)
- ConfigParser (02-02)
- RequirementsParser (02-03)
- PlanParser (02-03)

**SwiftUI APIs:**
- @Observable macro (macOS 14+)
- NavigationSplitView
- List with selection binding
- Section with headers
- ProgressView (linear style)
- ContentUnavailableView
- .task modifier for async work

**AppKit:**
- NSOpenPanel for directory picker

## Next Steps

Phase 02 is now complete! The app:
- Discovers all .planning/ projects in ~/Developer
- Displays them in grouped sidebar with progress
- Shows parsed roadmap in detail view
- Allows manual project addition and removal
- Persists bookmarks across launches

Phase 03 will add:
- FSEvents-based live file monitoring
- Auto-refresh when ROADMAP.md, STATE.md change
- Visual indicators for file updates

Phase 04 will build:
- Full visual dashboard with phase cards
- Requirement tracking UI
- Plan status display
- Interactive roadmap visualization

## Self-Check: PASSED

Verification results:
- FOUND: GSDMonitor/Services/ProjectService.swift
- FOUND: GSDMonitor/Views/ContentView.swift (modified)
- FOUND: GSDMonitor/Views/SidebarView.swift (modified)
- FOUND: GSDMonitor/Views/DetailView.swift (modified)
- FOUND: GSDMonitor/Utilities/PreviewData.swift (modified)
- FOUND: commit c981bf8 (Task 1)
- FOUND: commit c766dbd (Task 2)
- BUILD: ** BUILD SUCCEEDED ** with zero warnings
