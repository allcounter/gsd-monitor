---
phase: 02-file-discovery-parsing
plan: 01
subsystem: file-discovery
tags:
  - infrastructure
  - services
  - spm-integration
  - file-system
  - security
dependency_graph:
  requires: []
  provides:
    - bookmark-lifecycle-management
    - recursive-directory-scanning
    - security-scoped-resource-access
  affects:
    - all-file-parsing-plans
    - ui-integration
tech_stack:
  added:
    - swift-markdown@0.7.3
  patterns:
    - security-scoped-bookmarks
    - recursive-file-enumeration
    - sendable-services
key_files:
  created:
    - GSDMonitor/Services/BookmarkService.swift
    - GSDMonitor/Services/ProjectDiscoveryService.swift
  modified:
    - GSDMonitor.xcodeproj/project.pbxproj
    - GSDMonitor/GSDMonitor.entitlements
decisions:
  - Use @unchecked Sendable for BookmarkService due to UserDefaults thread-safety
  - Async discovery service without Task.detached for Swift 6 compatibility
  - App-scoped bookmarks for persistent file access across launches
metrics:
  duration: 251s
  tasks_completed: 2
  files_created: 2
  files_modified: 2
  commits: 2
  completed_date: 2026-02-13
---

# Phase 02 Plan 01: Foundation Services Summary

Swift-markdown SPM dependency integrated, BookmarkService for security-scoped bookmark lifecycle with staleness refresh, and ProjectDiscoveryService for recursive .planning/ discovery with safety guards.

## Tasks Completed

### Task 1: Add swift-markdown SPM dependency and update entitlements
- **Commit:** cf3ce73
- **Files:**
  - GSDMonitor.xcodeproj/project.pbxproj
  - GSDMonitor/GSDMonitor.entitlements
- **What was done:**
  - Added swift-markdown package (https://github.com/swiftlang/swift-markdown.git)
  - Resolved to version 0.7.3 (minimum 0.5.0, up to next major)
  - Updated entitlements to include:
    - `com.apple.security.files.user-selected.read-write` (changed from read-only)
    - `com.apple.security.files.bookmarks.app-scope` (new)
  - Package resolved successfully with swift-cmark dependency
  - Project builds cleanly

### Task 2: Create BookmarkService and ProjectDiscoveryService
- **Commit:** e3739a3
- **Files:**
  - GSDMonitor/Services/BookmarkService.swift (new)
  - GSDMonitor/Services/ProjectDiscoveryService.swift (new)
  - GSDMonitor.xcodeproj/project.pbxproj
- **What was done:**
  - **BookmarkService** - Complete bookmark lifecycle management:
    - `saveBookmark(for:identifier:)` - Creates security-scoped bookmark with `.withSecurityScope`
    - `resolveBookmark(for:)` - Resolves bookmark with automatic staleness refresh
    - `removeBookmark(for:)` - Removes stored bookmark
    - `allBookmarkIdentifiers()` - Lists all stored bookmarks
    - `accessSecurityScoped(_:operation:)` - Wraps operations with scoped resource access
    - Uses UserDefaults suite "com.gsdmonitor.bookmarks" for isolated storage
    - Marked `@unchecked Sendable` due to UserDefaults thread-safety guarantees
  - **ProjectDiscoveryService** - Recursive directory scanning:
    - `discoverProjects(in: URL)` - Single-root scanning
    - `discoverProjects(in: [URL])` - Multi-root with deduplication
    - Skips symlinks via `.isSymbolicLinkKey` resource check
    - Excludes: node_modules, .git, build, DerivedData, .build, Pods, Carthage
    - Enforces depth limit of 6 levels
    - Verifies ROADMAP.md exists before considering .planning/ as valid project
    - Returns `DiscoveredProject` structs (name, path, scanSource)
  - Both services compile under Swift 6 strict concurrency with zero warnings

## Verification Results

All success criteria met:

- [x] swift-markdown package resolved and importable (v0.7.3)
- [x] Entitlements updated for bookmark and read-write access
- [x] BookmarkService manages complete bookmark lifecycle with staleness refresh
- [x] ProjectDiscoveryService recursively finds .planning/ directories with safety guards
- [x] Project builds with zero Swift 6 warnings

**Build output:** `** BUILD SUCCEEDED **` with zero compiler warnings (only AppIntents metadata processor info, not a Swift warning)

## Deviations from Plan

**Auto-fixed Issues:**

**1. [Rule 1 - Bug] Swift 6 Task API compatibility**
- **Found during:** Task 2 implementation
- **Issue:** Initial code used `Task.detached` pattern which doesn't exist in Swift 6 Task API. Build errors: "type 'Task' has no member 'detached'" and "value of type 'Task' has no member 'value'"
- **Fix:** Simplified to direct async function implementation without Task wrapper, which is the correct Swift 6 pattern for async work
- **Files modified:** GSDMonitor/Services/ProjectDiscoveryService.swift
- **Commit:** Included in e3739a3

**2. [Rule 2 - Missing critical functionality] UserDefaults Sendable conformance**
- **Found during:** Task 2 implementation
- **Issue:** Build error: "stored property 'defaults' of 'Sendable'-conforming class 'BookmarkService' has non-Sendable type 'UserDefaults'"
- **Fix:** Added `@unchecked Sendable` to BookmarkService since UserDefaults is thread-safe for reads/writes (documented Apple API guarantee)
- **Files modified:** GSDMonitor/Services/BookmarkService.swift
- **Commit:** Included in e3739a3

**3. [Rule 1 - Bug] FileManager.DirectoryEnumerator error handler API**
- **Found during:** Task 2 implementation
- **Issue:** Attempted to set `enumerator.errorHandler` which doesn't exist on FileManager.DirectoryEnumerator. The enumerator has built-in error handling behavior.
- **Fix:** Removed error handler code. FileManager.DirectoryEnumerator automatically continues enumeration on errors (default behavior).
- **Files modified:** GSDMonitor/Services/ProjectDiscoveryService.swift
- **Commit:** Included in e3739a3

All deviations were auto-fixed under Rules 1-2 (bugs and missing critical functionality). No architectural decisions required.

## Architecture Notes

**Security-Scoped Bookmarks:**
- App-scoped bookmarks persist between launches
- User must still grant access via file picker initially
- Staleness detection and auto-refresh ensures continued access
- Critical for maintaining access to user-selected directories

**Discovery Service Design:**
- Sync FileManager enumeration wrapped in async function
- No true background threading needed for this use case
- Depth limit prevents runaway recursion in deep directory trees
- Excluded directories prevent scanning large dependency folders

**Sendable Conformance:**
- BookmarkService: `@unchecked Sendable` safe due to UserDefaults thread-safety
- ProjectDiscoveryService: struct with value-type properties, automatic Sendable
- DiscoveredProject: struct, automatic Sendable

## Dependencies

**Package Dependencies:**
- swift-markdown@0.7.3 (with swift-cmark@0.7.1)

**System APIs:**
- URL.bookmarkData(options:)
- URL.startAccessingSecurityScopedResource()
- FileManager.DirectoryEnumerator
- UserDefaults (isolated suite)

## Next Steps

Phase 02 Plan 02 can now:
- Use BookmarkService to persist user-selected directory access
- Use ProjectDiscoveryService to scan for GSD projects
- Parse markdown files found in .planning/ directories
- Build UI integration layer on top of these services

## Self-Check: PASSED

Verification results:
- FOUND: GSDMonitor/Services/BookmarkService.swift
- FOUND: GSDMonitor/Services/ProjectDiscoveryService.swift
- FOUND: commit cf3ce73 (Task 1)
- FOUND: commit e3739a3 (Task 2)
