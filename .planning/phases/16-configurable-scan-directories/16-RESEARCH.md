# Phase 16: Configurable Scan Directories - Research

**Researched:** 2026-02-21
**Domain:** SwiftUI macOS — settings popover, NSOpenPanel, drag-and-drop, UserDefaults persistence, FSEvents monitoring
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Settings UI & access**
- Gear icon at bottom of sidebar, always visible — opens a popover
- Popover titled "Scan Directories", dedicated to scan sources only (no general settings)
- Two sections: "Default" (~/Developer, non-removable) and "Additional" (user-added)
- Each directory row shows: abbreviated path with ~, project count, last scan time (e.g. "~/Projects — 3 projects · scanned 2m ago")
- Paths displayed with ~ abbreviation (~/Projects not /Users/name/Projects)

**Adding directories**
- + button opens macOS standard NSOpenPanel folder picker
- Drag & drop folder from Finder onto popover also supported
- Directory added immediately, scan happens after — shows "0 projects" until scan completes
- Duplicate add shows inline warning: "Already added"

**Removing directories**
- Small − or trash icon on each user-added row (not on ~/Developer)
- Click to remove immediately — projects from that source disappear from sidebar

**Sidebar presentation**
- Projects grouped by source directory with collapsible section headers
- Headers show abbreviated path: "~/Developer", "~/Projects", etc.
- ~/Developer group always first, additional sources sorted alphabetically below
- Projects within each group sorted alphabetically
- Empty groups (0 projects) still visible with "No projects found" message

**Scan feedback & persistence**
- Scanning indicator shown in the settings popover near the directory row being scanned
- Scan sources persisted in UserDefaults across app restarts
- FSEvents monitoring on all scan directories — new projects appear automatically in real-time
- If a scan directory is deleted/inaccessible: stays in list with error badge, user can re-add or remove

### Claude's Discretion
- Exact popover sizing and spacing
- Gear icon style and placement details
- Scanning indicator design (spinner, progress bar, etc.)
- Animation on group collapse/expand
- Error badge design

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SCAN-01 | User can add custom scan directories via settings | NSOpenPanel + drag-and-drop in ScanDirectoriesPopover; addScanDirectory() in ProjectService |
| SCAN-02 | User can remove scan directories | removeScanDirectory() removes from UserDefaults + drops projects + restarts FSEvents watcher |
| SCAN-03 | App scans all configured directories for .planning/ projects | ProjectDiscoveryService.discoverProjects(in:) already supports [URL]; ProjectService.loadProjects() already reads scanSources |
| SCAN-04 | ~/Developer remains default scan directory | Default branch in scanSources getter already returns ~/Developer; must prevent removal from UI |
</phase_requirements>

---

## Summary

Phase 16 is almost entirely additive UI work on top of an already-capable backend. `ProjectService` already has a `scanSources` property backed by UserDefaults, `ProjectDiscoveryService` already scans multiple URLs, and `groupedProjects` already groups by scan source. The scanning infrastructure (FSEvents via `FileWatcherService`, `startScanSourceMonitoring`) is complete. What is missing is: (1) a gear-icon-triggered popover in the sidebar for managing scan directories, (2) per-scan-source metadata (project count, last-scan timestamp, scanning/error state), and (3) wiring the popover actions to `ProjectService` add/remove methods.

The largest architectural addition is tracking per-source scan state (is-scanning flag, last scan timestamp, accessibility error flag) so the popover rows can display live feedback. This state should live in `ProjectService` as observable properties. Drag-and-drop of folders from Finder onto the popover requires a SwiftUI `.onDrop(of: [.fileURL])` receiver — straightforward in this macOS-only app.

The sidebar change is small: add a toolbar or bottom-bar gear button that presents a `ScanDirectoriesPopoverView` as a `.popover`. Collapsible section headers in the project list require `@AppStorage`-backed expansion state keyed by source path. The `Section` header in the current `SidebarView` is already using the group source string as a label — collapse support needs a `DisclosureGroup` wrapper per section.

**Primary recommendation:** Build `ScanDirectoriesPopoverView` as a self-contained view that reads/writes `projectService.scanSources` directly, add scan-state tracking to `ProjectService`, and wire the gear button into `SidebarView`'s bottom toolbar area.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 14+ | All UI — popover, list, drag-and-drop | Already the entire app UI layer |
| Foundation/UserDefaults | system | Scan source persistence | Already used for `scanSources` |
| FSEvents (via FileWatcherService) | system | Real-time directory monitoring | Already implemented in `FileWatcherService` |
| NSOpenPanel | AppKit/system | Folder picker dialog | Standard macOS folder picker; already used in `addProjectManually()` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| UniformTypeIdentifiers | system | Drag-and-drop type matching (`.fileURL`) | Used in `.onDrop(of: [.fileURL])` for Finder drag |
| AsyncAlgorithms | already in project | `.debounce` on FSEvents stream | Already imported in `ProjectService` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UserDefaults for scan sources | Security-scoped bookmarks | Bookmarks needed for sandboxed apps; app is NOT sandboxed (`com.apple.security.app-sandbox = false`) so plain paths in UserDefaults are fine |
| `.onDrop(of: [.fileURL])` | `NSFilenamesPboardType` (NSView drag) | SwiftUI `.onDrop` is idiomatic and sufficient here |

**Installation:** No new dependencies required. All needed frameworks are already in the project.

---

## Architecture Patterns

### Recommended Project Structure

```
GSDMonitor/
├── Services/
│   └── ProjectService.swift          # add: addScanDirectory(), removeScanDirectory(), scanState tracking
├── Views/
│   ├── SidebarView.swift             # add: gear button, collapsible sections, popover state
│   └── Settings/
│       └── ScanDirectoriesPopoverView.swift   # NEW: popover view for scan sources
```

### Pattern 1: Scan State Tracking in ProjectService

**What:** Per-source metadata (isScanning, lastScannedAt, isAccessible) stored as a dictionary on `ProjectService`.
**When to use:** Whenever a scan starts/finishes for a given URL, update the dictionary. Popover rows observe this to show spinners and timestamps.

```swift
// In ProjectService (@Observable, @MainActor)
struct ScanSourceState {
    var isScanning: Bool = false
    var lastScannedAt: Date? = nil
    var isAccessible: Bool = true
}

var scanSourceStates: [String: ScanSourceState] = [:]  // keyed by URL.path

// Before scanning a source:
scanSourceStates[url.path, default: ScanSourceState()].isScanning = true

// After scanning:
scanSourceStates[url.path, default: ScanSourceState()].isScanning = false
scanSourceStates[url.path, default: ScanSourceState()].lastScannedAt = Date()
```

### Pattern 2: ScanDirectoriesPopoverView

**What:** A `View` presented as `.popover` from the gear button. Shows two sections: Default (~/Developer, non-removable) and Additional (user-added, removable). Has a + button for NSOpenPanel and a `.onDrop` target.
**When to use:** Gear button tapped in sidebar bottom bar.

```swift
struct ScanDirectoriesPopoverView: View {
    let projectService: ProjectService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Scan Directories")
                .font(.headline)
                .padding()

            Divider()

            // Default section
            ScanSourceSection(title: "Default", sources: [defaultSource], removable: false)

            // Additional section
            ScanSourceSection(title: "Additional", sources: additionalSources, removable: true)

            Divider()

            // Add button
            Button(action: addDirectory) {
                Label("Add Directory...", systemImage: "plus")
            }
            .padding()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }
}
```

### Pattern 3: Gear Button in Sidebar Bottom Bar

**What:** A toolbar button at the bottom of `SidebarView` that toggles `@State private var showingScanSettings: Bool` and presents `ScanDirectoriesPopoverView` via `.popover`.
**When to use:** User clicks gear icon to open scan directory manager.

```swift
// In SidebarView:
@SwiftUI.State private var showingScanSettings = false

// In toolbar or safeAreaInset(edge: .bottom):
Button {
    showingScanSettings.toggle()
} label: {
    Image(systemName: "gear")
}
.popover(isPresented: $showingScanSettings) {
    ScanDirectoriesPopoverView(projectService: projectService)
        .frame(width: 340)
}
```

### Pattern 4: Collapsible Section Headers

**What:** Wrap each `Section` content in a `DisclosureGroup` with per-source expansion state persisted to `@AppStorage`.
**When to use:** Each source group in the sidebar project list.

```swift
// Use AppStorage keyed by source path (URL-safe key):
@AppStorage("collapsed_developer") private var developerCollapsed = false

DisclosureGroup(isExpanded: $developerCollapsed) {
    ForEach(group.projects) { project in ProjectRow(...) }
} label: {
    Text(group.source).font(.caption).foregroundStyle(Theme.textMuted)
}
```

Note: `@AppStorage` keys must be static strings. Since source paths are dynamic, use `@State` for expansion state within the view (acceptable — collapses reset on relaunch, which is fine behavior).

### Pattern 5: Drag-and-Drop from Finder

**What:** SwiftUI `.onDrop(of: [.fileURL])` on the popover surface. Load URLs from `NSItemProvider`.
**When to use:** User drags a folder from Finder onto the popover.

```swift
.onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
    for provider in providers {
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url = url, url.hasDirectoryPath else { return }
            Task { @MainActor in
                projectService.addScanDirectory(url)
            }
        }
    }
    return true
}
```

### Pattern 6: Add/Remove Scan Directory in ProjectService

**What:** New `addScanDirectory(_ url: URL)` and `removeScanDirectory(_ url: URL)` methods. These update `scanSources`, restart FSEvents monitoring, and trigger a background scan.
**When to use:** From popover + button (NSOpenPanel result) and drop handler.

```swift
func addScanDirectory(_ url: URL) {
    // Guard duplicate
    guard !scanSources.contains(url) else {
        // Signal "already added" — set a transient warning state
        return
    }
    var sources = scanSources
    sources.append(url)
    scanSources = sources

    // Mark as scanning
    scanSourceStates[url.path, default: ScanSourceState()].isScanning = true

    Task {
        let discovered = await discoveryService.discoverProjects(in: url)
        for d in discovered {
            if let project = await parseProject(at: d.path, scanSource: d.scanSource) {
                if !projects.contains(where: { $0.path == project.path }) {
                    projects.append(project)
                }
            }
        }
        scanSourceStates[url.path, default: ScanSourceState()].isScanning = false
        scanSourceStates[url.path, default: ScanSourceState()].lastScannedAt = Date()

        // Restart scan-source FSEvents monitoring to include new directory
        stopMonitoring()
        startMonitoring()
        startScanSourceMonitoring()
    }
}

func removeScanDirectory(_ url: URL) {
    // Remove projects from this source
    projects.removeAll { project in
        project.path.path.hasPrefix(url.path) && !manualProjectPaths.contains(project.path.path)
    }

    // Remove from sources
    var sources = scanSources
    sources.removeAll { $0.path == url.path }
    scanSources = sources

    scanSourceStates.removeValue(forKey: url.path)

    // Restart monitoring without this directory
    stopMonitoring()
    startMonitoring()
    startScanSourceMonitoring()
}
```

### Anti-Patterns to Avoid

- **Calling `loadProjects()` on add/remove:** `loadProjects()` does a full re-scan of all sources and restarts all monitoring — wasteful for incremental add/remove. Prefer targeted `addScanDirectory`/`removeScanDirectory` methods.
- **Storing scan state in SwiftUI view:** Scan-in-progress state belongs in `ProjectService` (observable) so multiple views can react to it.
- **Using security-scoped bookmarks for scan directories:** The app is NOT sandboxed. Plain URL paths in UserDefaults are sufficient. Adding bookmark complexity for non-sandboxed access is unnecessary (contrast: the existing `BookmarkService` for manually-added projects can also be simplified, but that is out of scope).
- **Making ~/Developer removable in the data layer:** The "cannot remove default" constraint is purely UI — ~/Developer is excluded from the remove UI, not special-cased in the data layer. `scanSources` can technically hold anything; the protection is in the view.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Folder picker dialog | Custom file browser | `NSOpenPanel` (already used in `addProjectManually()`) | macOS standard; handles sandboxing, permissions, user trust |
| File URL from drag | Manual pasteboard parsing | `NSItemProvider.loadObject(ofClass: URL.self)` | Handles async loading, file promises |
| "Scanned 2m ago" relative time string | Manual date diff math | `RelativeDateTimeFormatter` (Foundation) | Handles localization, edge cases (just now, yesterday, etc.) |
| Collapsible sidebar sections | Custom expand/collapse | `DisclosureGroup` (SwiftUI) | Native animation, accessibility |

**Key insight:** The backend for this phase is already built. Don't rebuild it — wire the UI to what exists.

---

## Common Pitfalls

### Pitfall 1: `startScanSourceMonitoring` Guard Prevents Restart

**What goes wrong:** `startScanSourceMonitoring()` has an early return if `scanSourceMonitoringTask != nil`. When a new scan directory is added, calling `startScanSourceMonitoring()` again does nothing — the new directory is never watched.
**Why it happens:** The guard was added to prevent an infinite loop (loadProjects → watcher fires → loadProjects).
**How to avoid:** When adding/removing scan sources, always call `stopMonitoring()` first (which nils `scanSourceMonitoringTask`), then `startScanSourceMonitoring()`. This is already the pattern in `addProjectManually()` and `removeManualProject()`.
**Warning signs:** New directories added but `projectsService` doesn't react to new .planning folders appearing in them.

### Pitfall 2: `scanSources` Getter Rebuilds Every Access

**What goes wrong:** The current `scanSources` computed property reads from `UserDefaults` on every get and writes on every set. It has no local cache. If you call it in a tight loop or on multiple views simultaneously, it hammers UserDefaults reads.
**Why it happens:** It is a pure computed property with no backing store.
**How to avoid:** For Phase 16, this is acceptable. If performance degrades, add a `private var _scanSources: [URL]?` cache. But don't pre-optimize unless observed.
**Warning signs:** Sluggish popover open/close.

### Pitfall 3: `groupedProjects` Shows "Manually Added" Group for Scan Source Projects

**What goes wrong:** The current `groupedProjects` logic has two categories: scan sources and "Manually Added". Phase 16 changes the sidebar presentation to group strictly by scan source path. Projects manually added via the old "add project" button fall outside scan sources and show in a "Manually Added" group.
**Why it happens:** The existing sidebar add (+) button in the toolbar calls `addProjectManually()` which uses bookmarks and tracks paths in `manualProjectPaths`. This is a different concept from scan directories.
**How to avoid:** The CONTEXT.md decisions are about scan directories — the existing manual add feature is separate and not removed. The sidebar must continue to show "Manually Added" as a group for those projects. The collapsible section logic applies to all groups uniformly. No change to the manual add flow is needed.
**Warning signs:** Manually-added projects disappear from sidebar after Phase 16.

### Pitfall 4: Drag-and-Drop `UTType.fileURL` vs `.folder`

**What goes wrong:** Using `.folder` UTType in `.onDrop(of:)` may not match all folder-drag scenarios from Finder. Files dragged from Finder come as `.fileURL`.
**Why it happens:** Finder drags supply file URLs, not folder-typed data.
**How to avoid:** Use `.fileURL` in `.onDrop(of: [.fileURL])` and validate `url.hasDirectoryPath` on the received URL.
**Warning signs:** Drop target appears highlighted but no directory is added.

### Pitfall 5: `Date` for lastScannedAt Displayed as Absolute Time

**What goes wrong:** Displaying `Date` directly in the row (e.g., `date.description`) gives an unreadable timestamp.
**Why it happens:** The design spec calls for relative time ("scanned 2m ago").
**How to avoid:** Use `RelativeDateTimeFormatter` with `.named` or `.spellOut` style. Update the display periodically (every 60s is sufficient — use a `Timer` or a `.task` with `try await Task.sleep`).

---

## Code Examples

### RelativeDateTimeFormatter for "scanned 2m ago"
```swift
// Source: Foundation docs (standard library)
let formatter = RelativeDateTimeFormatter()
formatter.unitsStyle = .abbreviated  // "2 min. ago"
formatter.dateTimeStyle = .named     // "2 minutes ago"

let display = formatter.localizedString(for: lastScannedDate, relativeTo: Date())
// Result: "2 minutes ago"
```

### NSOpenPanel for Folder Selection (existing pattern in codebase)
```swift
// Source: existing addProjectManually() in ProjectService.swift
func addScanDirectory() async {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.message = "Select a directory to scan for GSD projects"

    let response = await panel.begin()
    guard response == .OK, let url = panel.url else { return }
    addScanDirectory(url)
}
```

### Path Abbreviation with Tilde (existing pattern in codebase)
```swift
// Source: existing groupedProjects in ProjectService.swift
let homePath = FileManager.default.homeDirectoryForCurrentUser.path
let displayPath = url.path.replacingOccurrences(of: homePath, with: "~")
// "/Users/jane/Projects" → "~/Projects"
```

### Accessibility Check for Scan Directory
```swift
func checkAccessibility(of url: URL) -> Bool {
    var isDir: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
    return exists && isDir.boolValue
}
```

### Popover Presentation from Sidebar
```swift
// In SidebarView body, using safeAreaInset for bottom-anchored gear button:
.safeAreaInset(edge: .bottom) {
    HStack {
        Spacer()
        Button {
            showingScanSettings.toggle()
        } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(Theme.textSecondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingScanSettings, arrowEdge: .bottom) {
            ScanDirectoriesPopoverView(projectService: projectService)
                .frame(width: 340, alignment: .leading)
        }
        .padding(8)
    }
    .background(Theme.bg0)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `DisclosureGroup` with manual chevron | Native SwiftUI `DisclosureGroup` with default disclosure | macOS 11+ | Use native; don't build custom |
| `NSOpenPanel` via AppKit bridge | `NSOpenPanel` directly via `await panel.begin()` | macOS 12+ async support | Already used in `addProjectManually()`; use same pattern |
| Manual NSPasteboard for drag | `.onDrop(of: [UTType])` SwiftUI modifier | macOS 11+ | SwiftUI-native, no AppKit bridge needed |

---

## Open Questions

1. **Should the gear button replace or supplement the existing + button in the sidebar toolbar?**
   - What we know: The current + button calls `addProjectManually()` (adds a single project via bookmark), not `addScanDirectory()`. These are different features.
   - What's unclear: Is the old + button still wanted after Phase 16, or is "add scan directory" the new primary action?
   - Recommendation: Keep both. The existing + button adds individual projects; the gear popover manages scan directories. The sidebar toolbar + button can stay as-is. If the user wants to remove it, that is a separate quick task.

2. **Collapsible state persistence: `@AppStorage` vs `@State`**
   - What we know: Section headers are keyed by source path strings (dynamic). `@AppStorage` requires static string keys.
   - What's unclear: Whether collapse state should survive app restarts.
   - Recommendation: Use `@State` (resets on relaunch). Section collapse state is non-critical. If persistence is wanted later, encode a `[String: Bool]` dict to UserDefaults manually.

3. **Timer for "scanned X ago" refresh**
   - What we know: The relative timestamp in popover rows becomes stale after ~1 minute.
   - What's unclear: Whether to use a `Timer.publish` or a `Task` loop.
   - Recommendation: Use `TimelineView(.periodic(from: .now, by: 60))` (SwiftUI-native, available macOS 12+) to auto-refresh the relative time display without manual timer management.

---

## Sources

### Primary (HIGH confidence)
- Codebase direct read — `ProjectService.swift`, `FileWatcherService.swift`, `BookmarkService.swift`, `ProjectDiscoveryService.swift`, `SidebarView.swift`, `GSDMonitor.entitlements`
- Foundation docs (training knowledge, stable API) — `RelativeDateTimeFormatter`, `NSOpenPanel`, `FileManager`

### Secondary (MEDIUM confidence)
- SwiftUI `DisclosureGroup`, `.onDrop`, `.popover`, `safeAreaInset` — standard SwiftUI, stable since macOS 11/12

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; entire stack already in use
- Architecture: HIGH — backend is complete; UI patterns are standard SwiftUI
- Pitfalls: HIGH — identified from direct codebase reading (startScanSourceMonitoring guard, groupedProjects manual-add group)

**Research date:** 2026-02-21
**Valid until:** 2026-03-21 (stable SwiftUI/Foundation APIs)
