# Phase 01 Plan 02: NavigationSplitView Skeleton Summary

**One-liner:** NavigationSplitView foundation with sidebar/detail layout, ContentUnavailableView empty states, and automatic macOS theme switching

---

## Metadata

```yaml
phase: 01-foundation-models
plan: 02
subsystem: UI Foundation
tags: [swiftui, navigation, empty-states, ui-skeleton]
completed: 2026-02-13T06:45:41Z
duration: 2 minutes
```

## Dependency Graph

**Requires:**
- Phase 01 Plan 01 (Models: Project, Roadmap, Phase, State)

**Provides:**
- NavigationSplitView architecture
- Empty state UI patterns
- Preview data infrastructure

**Affects:**
- All future view components (will use this navigation structure)
- Phase 02 (file parsing will populate the empty sidebar)
- Phase 04 (roadmap visualization will replace detail placeholder)

## Tech Stack

**Added:**
- NavigationSplitView (SwiftUI macOS 14+)
- ContentUnavailableView (macOS 14+ empty states)
- SwiftUI Previews with color scheme variants

**Patterns:**
- Two-column NavigationSplitView (.balanced style)
- Value-type selection (@SwiftUI.State for UUID?, avoids @Observable memory leaks)
- Empty state first approach (tests ContentUnavailableView before adding data)
- Namespace qualification (@SwiftUI.State to avoid model name collision)

## Key Files

**Created:**
- `GSDMonitor/Views/SidebarView.swift` - Sidebar with "No Projects Found" empty state
- `GSDMonitor/Views/DetailView.swift` - Detail pane with "Select a Project" placeholder
- `GSDMonitor/Utilities/PreviewData.swift` - Mock Project data for Xcode previews

**Modified:**
- `GSDMonitor/Views/ContentView.swift` - Replaced placeholder with NavigationSplitView root
- `GSDMonitor.xcodeproj/project.pbxproj` - Added new files to build system

## Implementation Summary

### What Was Built

Built the UI skeleton following Phase 01's "empty state first" philosophy:

1. **ContentView** - Root view with NavigationSplitView containing:
   - Sidebar column with SidebarView
   - Detail column with DetailView
   - `.balanced` style for proper macOS column widths
   - `@SwiftUI.State private var selectedProjectID: UUID?` for selection state

2. **SidebarView** - Project list sidebar:
   - Shows ContentUnavailableView when `projects.isEmpty`
   - Empty state: "No Projects Found" with folder.badge.questionmark icon
   - List with NavigationLink when projects exist (ready for Phase 2)

3. **DetailView** - Roadmap display area:
   - Shows ContentUnavailableView when no project selected
   - Empty state: "Select a Project" with sidebar.left icon
   - Simple text placeholder when project selected (Phase 4 will build full roadmap view)

4. **PreviewData** - Mock data for Xcode previews:
   - Two mock projects (one with Roadmap, one without)
   - Uses proper model initializers with default parameters
   - Enables #Preview to work for all views

### Key Decisions

| Decision | Rationale | Impact |
|----------|-----------|--------|
| Use `@SwiftUI.State` instead of `@State` | Avoid name collision with `State` model (from 01-01) | No ambiguity, explicit namespace |
| Two-column NavigationSplitView (not three) | GSD projects don't need inspector pane | Simpler architecture, matches macOS design |
| `.balanced` style | Equal emphasis on sidebar and detail | Better UX than `.automatic` (which favors detail) |
| Empty state first approach | Test ContentUnavailableView before adding complexity | Validates UI patterns work before Phase 2 parsing |
| Value-type selection (UUID?) | Avoid @Observable memory leak (PITFALLS.md Pitfall 2) | Safe concurrency, no retain cycles |
| Mock empty array in ContentView | Forces empty state rendering | Verifies "No Projects Found" displays correctly |

### Deviations from Plan

**Auto-fixed Issues:**

**1. [Rule 1 - Bug] Name collision between SwiftUI.State and State model**
- **Found during:** Task 1 build
- **Issue:** Swift compiler error: "struct 'State' cannot be used as an attribute" when using `@State`
- **Root cause:** Our `State` model (from 01-01) conflicts with SwiftUI's `@State` property wrapper
- **Fix:** Changed `@State` to `@SwiftUI.State` in ContentView.swift to explicitly use SwiftUI namespace
- **Files modified:** GSDMonitor/Views/ContentView.swift
- **Commit:** 7a44413

**2. [Rule 2 - Missing functionality] PreviewData extension removed**
- **Found during:** Task 1 build
- **Issue:** Plan included `extension Project` with custom init, but Project.swift already has proper init with default parameters (from 01-01)
- **Root cause:** Plan template assumed models lacked convenience initializers
- **Fix:** Removed redundant extension, used existing `init(name:path:roadmap:state:config:)` from Project model
- **Files modified:** GSDMonitor/Utilities/PreviewData.swift
- **Commit:** 7a44413 (same commit, part of Task 1)

## Verification Results

**Build:** ✅ SUCCESS
```
xcodebuild -project GSDMonitor.xcodeproj -scheme GSDMonitor build
** BUILD SUCCEEDED **
```

**Warnings:** None (Swift 6 strict concurrency mode, zero warnings)

**Files created:** ✅ 3 view files + 1 utility
```
GSDMonitor/Views/ContentView.swift (modified)
GSDMonitor/Views/SidebarView.swift
GSDMonitor/Views/DetailView.swift
GSDMonitor/Utilities/PreviewData.swift
```

**Xcode previews:** ✅ (verified all views have #Preview macros with Light/Dark variants)

**Manual verification (visual):**
- App launches showing NavigationSplitView with two columns
- Sidebar displays "No Projects Found" with folder.badge.questionmark icon
- Detail pane shows "Select a Project" with sidebar.left icon
- Both empty states use system colors (readable in light and dark mode)

## Self-Check

Verifying all claimed files and commits exist:

```bash
# Check created files
[ -f "GSDMonitor/Views/ContentView.swift" ] && echo "✅ ContentView.swift"
[ -f "GSDMonitor/Views/SidebarView.swift" ] && echo "✅ SidebarView.swift"
[ -f "GSDMonitor/Views/DetailView.swift" ] && echo "✅ DetailView.swift"
[ -f "GSDMonitor/Utilities/PreviewData.swift" ] && echo "✅ PreviewData.swift"

# Check commit exists
git log --oneline --all | grep -q "7a44413" && echo "✅ Commit 7a44413"
```

**Result:**
✅ ContentView.swift
✅ SidebarView.swift
✅ DetailView.swift
✅ PreviewData.swift
✅ Commit 7a44413

## Self-Check: PASSED

All files exist, commit exists, build succeeds, zero warnings.

## Next Steps

**Phase 01 Plan 03** (next in phase):
- Create PlanningConfig model (if needed for config.json parsing)
- Or proceed to Phase 02 if config parsing not needed yet

**Phase 02** (depends on this plan):
- FileDiscoveryService will populate the empty sidebar with actual projects
- Will scan ~/Developer for .planning/ directories
- ContentView mockProjects will be replaced with real data from service

**Phase 04** (depends on this plan):
- RoadmapView will replace DetailView's text placeholder
- Will display phase cards, progress bars, dependencies
- Will use the selectedProject from navigation state

## Technical Notes

**Swift 6 Concurrency:**
- All models are `Sendable` (from 01-01)
- No @Observable used in views (avoiding memory leak pitfall)
- Value-type selection state (UUID?) is inherently thread-safe

**macOS Design Patterns:**
- NavigationSplitView matches macOS master-detail pattern
- ContentUnavailableView uses native empty state design
- Automatic light/dark mode via system theme (no manual color management)

**Preview Infrastructure:**
- PreviewData enum provides mock data for all views
- Light/Dark mode previews ensure readability in both themes
- Mock data includes realistic GSD project structure (phases, roadmap)

## Lessons Learned

1. **Name collisions are real in Swift** - When domain models use common names (State, Plan), namespace qualification becomes critical
2. **Check existing code before implementing** - Plan assumed models lacked inits, but 01-01 already provided them
3. **Empty state first validates patterns** - Starting with ContentUnavailableView confirmed macOS 14+ requirement and tested UI before adding data complexity
4. **Xcode project manipulation is fragile** - Direct .pbxproj editing requires exact formatting; used Edit tool for surgical changes instead of regex replacement

---

**Plan Status:** ✅ Complete
**Verification:** ✅ Passed
**Commits:** 1 task commit (7a44413)
