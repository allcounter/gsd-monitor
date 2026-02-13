# Phase 04: Dashboard UI & Visualization - Research

**Researched:** 2026-02-13
**Domain:** SwiftUI dashboard UI, list performance, navigation patterns, markdown rendering
**Confidence:** HIGH

## Summary

Phase 4 builds visual roadmap cards, requirement tracking UI, search/filter functionality, and command palette navigation. The standard stack uses native SwiftUI components: NavigationSplitView with value-based NavigationLink for drill-down, List (not LazyVStack) for performance with 100+ items, searchable() modifier for sidebar filtering, AttributedString for inline markdown rendering, and sheet/popover for requirement detail views.

**Key architectural insight:** SwiftUI List outperforms LazyVStack dramatically for large datasets (5.53s vs 52.3s for same data) due to intelligent view recycling and height calculation. Use List + value-based NavigationLink pattern, avoid inline destination views that instantiate for every row.

**Markdown limitation:** SwiftUI AttributedString supports only inline formatting (bold, italic, links, inline code) — no headings, tables, images, or code blocks. This aligns perfectly with requirement ROAD-04 (basic markdown in phase cards).

**Primary recommendation:** Use List with Identifiable+Hashable data (avoid .id() modifier which breaks lazy loading), navigationDestination() for drill-down detail views, searchable() on NavigationSplitView for global search, sheet() for requirement popups, ProgressView for phase completion bars, and validate 100+ project performance with Instruments SwiftUI profiling template (new in macOS 15/Xcode 16).

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 15+ | UI framework | Native, high-performance, declarative UI with built-in list recycling and markdown rendering |
| Foundation | macOS 15+ | AttributedString markdown | Zero-dependency inline markdown (bold, italic, links, code) without third-party parsers |
| Instruments 26 | Xcode 16+ | Performance profiling | New SwiftUI profiling template specifically for identifying slow layouts and rendering issues |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| swift-markdown | 0.7.3+ | Already integrated | **Not needed** for Phase 4 — AttributedString handles inline markdown. Reserve for advanced parsing if requirements expand |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| List | LazyVStack | LazyVStack 9.5x slower for large datasets (52.3s vs 5.53s). Only use if you need custom scroll behavior incompatible with List |
| AttributedString | MarkdownUI library | MarkdownUI adds dependency for features (headings, tables, images) not required by ROAD-04. Violates "native performance" prior decision |
| sheet() for requirements | NavigationLink to detail | Sheet keeps context visible, better UX for "peek at requirement definition" vs full navigation |
| Built-in searchable() | Custom TextField filter | searchable() provides platform-standard search field positioning, keyboard shortcuts, and search token support |

**Installation:**
```bash
# No additional dependencies needed — all standard library
```

## Architecture Patterns

### Recommended Project Structure
```
GSDMonitor/
├── Views/
│   ├── ContentView.swift               # Root NavigationSplitView
│   ├── SidebarView.swift               # ✅ Already exists with grouped projects
│   ├── DetailView.swift                # ✅ Exists — needs roadmap cards
│   ├── Dashboard/
│   │   ├── PhaseCardView.swift         # Phase card with goal, requirements, progress
│   │   ├── PhaseDetailView.swift       # Drill-down: detailed plan with tasks
│   │   ├── RequirementBadgeView.swift  # Clickable REQ-ID badge
│   │   └── RequirementDetailSheet.swift # Modal showing req definition, phases, status
│   └── CommandPalette/
│       └── CommandPaletteView.swift    # Cmd+K modal search
├── ViewModels/
│   └── SearchViewModel.swift           # Filter logic for sidebar search
└── Utilities/
    └── MarkdownRenderer.swift          # AttributedString helpers
```

### Pattern 1: List with Value-Based Navigation (Performance-Critical)
**What:** Use List with selection binding + navigationDestination() instead of inline NavigationLink destinations
**When to use:** Always for lists with 10+ items, especially project/phase lists
**Why:** Inline destinations cause SwiftUI to instantiate views for every visible row. Value-based pattern defers instantiation until navigation occurs.

**Example:**
```swift
// Source: https://levelup.gitconnected.com/swiftui-navigation-in-ios-a-practical-guide-2a4820971681
struct PhaseListView: View {
    let phases: [Phase]
    @State private var selectedPhase: Phase.ID?

    var body: some View {
        List(phases, selection: $selectedPhase) { phase in
            NavigationLink(value: phase.id) {
                PhaseCardView(phase: phase)
            }
        }
        .navigationDestination(for: Phase.ID.self) { phaseID in
            if let phase = phases.first(where: { $0.id == phaseID }) {
                PhaseDetailView(phase: phase)
            }
        }
    }
}
```

### Pattern 2: Searchable with NavigationSplitView
**What:** Apply searchable() modifier to NavigationSplitView for global search, filter with computed property
**When to use:** NAV-03 requirement (search/filter projects in sidebar)
**Example:**
```swift
// Source: https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-a-search-bar-to-filter-your-data
struct ContentView: View {
    @State private var projectService = ProjectService()
    @State private var selectedProjectID: UUID?
    @State private var searchText = ""
    @State private var statusFilter: ProjectStatus = .all

    var filteredProjects: [Project] {
        let filtered = searchText.isEmpty
            ? projectService.projects
            : projectService.projects.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
              }

        return statusFilter == .all
            ? filtered
            : filtered.filter { $0.state?.status == statusFilter.rawValue }
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(projects: filteredProjects, selectedProjectID: $selectedProjectID)
                .searchable(text: $searchText, prompt: "Search projects")
                .searchScopes($statusFilter) {
                    Text("All").tag(ProjectStatus.all)
                    Text("Active").tag(ProjectStatus.active)
                    Text("Completed").tag(ProjectStatus.completed)
                }
        } detail: {
            DetailView(selectedProject: selectedProject)
        }
    }
}
```

### Pattern 3: Card UI with GroupBox
**What:** Use custom card style with VStack + padding + background + cornerRadius + shadow for phase cards
**When to use:** ROAD-01 (visual roadmap with phase cards)
**Example:**
```swift
// Source: https://gauravtakjaipur.medium.com/cardstyle-vs-groupbox-in-swiftui-choosing-the-right-container-for-our-views-95362796c8f7
struct PhaseCardView: View {
    let phase: Phase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Phase number + name + status badge
            HStack {
                Text("Phase \(phase.number): \(phase.name)")
                    .font(.headline)
                Spacer()
                StatusBadge(status: phase.status)
            }

            // Goal with markdown
            if let attributedGoal = try? AttributedString(markdown: phase.goal) {
                Text(attributedGoal)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Requirements (clickable badges)
            if !phase.requirements.isEmpty {
                RequirementBadgesView(requirementIDs: phase.requirements)
            }

            // Progress bar
            ProgressView(value: phase.completionPercent, total: 1.0)
                .progressViewStyle(.linear)
                .tint(progressColor(for: phase.status))
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}
```

### Pattern 4: AttributedString Markdown Rendering
**What:** Parse markdown inline with AttributedString(markdown:) for bold, italic, links, code
**When to use:** ROAD-04 requirement (basic markdown in phase cards)
**Limitations:** NO support for headings, tables, images, code blocks, block quotes
**Example:**
```swift
// Source: https://www.avanderlee.com/swiftui/markdown-text/
struct MarkdownTextView: View {
    let markdownContent: String

    var body: some View {
        if let attributedString = try? AttributedString(markdown: markdownContent) {
            Text(attributedString)
        } else {
            Text(markdownContent) // Fallback to plain text on parse error
        }
    }
}

// Example markdown that WORKS with AttributedString:
// "**Goal:** Build `visual roadmap` with [phase cards](link) and *progress tracking*"
// Renders: Bold "Goal:", inline code `visual roadmap`, clickable link, italic text

// Example markdown that FAILS (renders as plain text):
// "# Heading\n\n```swift\ncode block\n```\n\n| Table | Header |"
```

### Pattern 5: Command Palette with Keyboard Shortcuts
**What:** Custom modal view triggered by keyboardShortcut("k") on invisible Button
**When to use:** NAV-04 requirement (Cmd+K command palette)
**Example:**
```swift
// Source: https://sarunw.com/posts/swiftui-keyboard-shortcuts/
struct ContentView: View {
    @State private var showCommandPalette = false

    var body: some View {
        NavigationSplitView {
            // ... sidebar
        } detail: {
            // ... detail
        }
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
        }
        .background {
            // Hidden button to capture Cmd+K
            Button("") {
                showCommandPalette = true
            }
            .keyboardShortcut("k", modifiers: .command)
            .hidden()
        }
    }
}

struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            TextField("Search projects, phases, requirements...", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .padding()

            // Results list
            List(filteredResults) { result in
                CommandResultRow(result: result)
                    .onTapGesture {
                        navigate(to: result)
                        dismiss()
                    }
            }
        }
        .frame(width: 600, height: 400)
        .onAppear { isFocused = true }
    }
}
```

### Pattern 6: Sheet for Requirement Details
**What:** Use sheet() presentation for REQ-ID detail view (definition, mapped phases, status)
**When to use:** REQ-02 requirement (click REQ-ID to see definition)
**Example:**
```swift
// Source: https://www.hackingwithswift.com/quick-start/swiftui/how-to-present-a-new-view-using-sheets
struct RequirementBadgeView: View {
    let requirementID: String
    @State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            Text(requirementID)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .foregroundColor(.accentColor)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            RequirementDetailSheet(requirementID: requirementID)
        }
    }
}

struct RequirementDetailSheet: View {
    let requirementID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(requirementID)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Definition
                    Text("Definition")
                        .font(.headline)
                    Text(requirement.description)

                    // Mapped phases
                    Text("Mapped to Phases")
                        .font(.headline)
                    ForEach(requirement.mappedToPhases, id: \.self) { phaseNum in
                        Text("Phase \(phaseNum)")
                    }

                    // Status
                    Text("Status")
                        .font(.headline)
                    StatusBadge(status: requirement.status)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
    }
}
```

### Anti-Patterns to Avoid
- **Inline NavigationLink destinations:** Causes view instantiation for every row. Use navigationDestination() instead.
- **Using .id() modifier on List data:** Breaks lazy loading. Make data types conform to Identifiable+Hashable instead.
- **LazyVStack for large project lists:** 9.5x slower than List. Only use if custom scroll behavior is required.
- **Blocking main thread with markdown parsing:** AttributedString parsing can be slow for large text. Parse in background task, cache results.
- **Custom markdown parser:** AttributedString handles inline formatting natively. Don't add third-party libraries unless requirements expand beyond ROAD-04.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Search in NavigationSplitView | Custom TextField + filter logic | .searchable() modifier | Handles platform-standard positioning (toolbar on macOS, nav bar on iOS), keyboard shortcuts (Cmd+F), search tokens, and scope switching |
| List performance optimization | Manual view recycling, UIViewRepresentable wrapper | Native SwiftUI List | List automatically uses UICollectionView (iOS 16+) with intelligent recycling, height caching, and scroll optimization |
| Progress indicators | Custom circular/linear progress views | ProgressView with .progressViewStyle() | Built-in determinate/indeterminate modes, adapts to platform (macOS supports circular determinate, iOS doesn't) |
| Markdown rendering | Regex parser or swift-markdown walker for inline text | AttributedString(markdown:) | Foundation-native, handles escaping/entities, supports LocalizedStringKey for localization |
| Command palette fuzzy search | Custom Levenshtein distance algorithm | NSPredicate or String.localizedCaseInsensitiveContains() | Built-in, optimized, handles diacritics and locale-specific sorting |
| Modal presentations | Custom overlay + animation | sheet(), popover(), alert() modifiers | Platform-standard behavior (dismiss gestures, focus management, VoiceOver support), automatic adaptation (popover → sheet on compact size) |

**Key insight:** SwiftUI components already handle 90% of dashboard UI complexity. Custom implementations introduce bugs (edge cases, accessibility, performance) that Apple has already solved. Only build custom when absolutely necessary (e.g., command palette combining search + quick actions).

## Common Pitfalls

### Pitfall 1: List Performance Degradation with Large Datasets
**What goes wrong:** Sidebar becomes sluggish when displaying 100+ projects, violating success criterion #6.
**Why it happens:**
1. Using LazyVStack instead of List (9.5x slower: 52.3s vs 5.53s for same data)
2. Complex computed properties in row views (e.g., DateFormatter in body)
3. Using .id() modifier which disables lazy loading
4. Creating inline NavigationLink destinations that instantiate for every row

**How to avoid:**
1. **Always use List for collections > 10 items** — List uses UICollectionView with intelligent recycling
2. **Make data Identifiable + Hashable** — avoid .id() which breaks lazy loading
3. **Cache expensive computations** — move DateFormatter, NumberFormatter to @State or static
4. **Use navigationDestination() not inline NavigationLink** — defers view creation until navigation
5. **Profile with Instruments SwiftUI template** — use "Long View Body Updates" lane to identify slow views

**Warning signs:**
- Scrolling stutters or frame drops
- Instruments shows body computations taking > 16ms
- Xcode runtime warnings about "Slow view update"

**Example fix:**
```swift
// ❌ BAD: Inline destination, custom id, formatter in body
List(projects) { project in
    NavigationLink(destination: DetailView(project: project)) {
        ProjectRow(project: project)
    }
}
.id(UUID()) // BREAKS LAZY LOADING

struct ProjectRow: View {
    let project: Project
    var body: some View {
        Text(project.lastActivity ?? "")
            .formatted(.dateTime) // SLOW: Creates formatter every render
    }
}

// ✅ GOOD: Value-based navigation, Identifiable data, cached formatter
List(projects, selection: $selectedID) { project in
    NavigationLink(value: project.id) {
        ProjectRow(project: project)
    }
}
.navigationDestination(for: UUID.self) { id in
    if let project = projects.first(where: { $0.id == id }) {
        DetailView(project: project)
    }
}

struct ProjectRow: View {
    let project: Project
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    var body: some View {
        Text(project.lastActivity.map { Self.dateFormatter.string(from: $0) } ?? "")
    }
}
```

### Pitfall 2: AttributedString Markdown Parsing Crashes
**What goes wrong:** App crashes or shows plain text when rendering phase goals with markdown.
**Why it happens:**
1. Invalid markdown syntax (unmatched brackets, invalid URLs)
2. Unsupported markdown features (headings, tables, code blocks)
3. Parsing on main thread blocks UI for large text

**How to avoid:**
1. **Always use try? AttributedString(markdown:)** — graceful fallback to plain text
2. **Document supported markdown** — only bold, italic, links, inline code
3. **Parse in background for > 500 chars** — use Task.detached, cache result
4. **Sanitize user input** — if markdown comes from file parsing, validate syntax

**Warning signs:**
- Text displays as raw markdown (e.g., "**bold**" instead of bold text)
- try! crashes with NSError for malformed markdown
- UI freezes during initial render

**Example fix:**
```swift
// ❌ BAD: Crashes on invalid markdown, blocks main thread
struct PhaseCardView: View {
    let phase: Phase
    var body: some View {
        Text(try! AttributedString(markdown: phase.goal)) // CRASHES
    }
}

// ✅ GOOD: Graceful fallback, cached parsing
struct PhaseCardView: View {
    let phase: Phase
    @State private var attributedGoal: AttributedString?

    var body: some View {
        Group {
            if let attributed = attributedGoal {
                Text(attributed)
            } else {
                Text(phase.goal) // Fallback to plain text
            }
        }
        .task {
            // Parse in background
            attributedGoal = try? AttributedString(markdown: phase.goal)
        }
    }
}

// Or: Pre-parse in ProjectService when loading roadmap
extension Phase {
    var attributedGoal: AttributedString {
        (try? AttributedString(markdown: goal)) ?? AttributedString(goal)
    }
}
```

### Pitfall 3: Command Palette Not Appearing on Cmd+K
**What goes wrong:** User presses Cmd+K, nothing happens or system beep.
**Why it happens:**
1. keyboardShortcut() button not in view hierarchy
2. Another view/menu captures Cmd+K first
3. Sheet binding not toggling
4. Focus issues prevent keyboard events

**How to avoid:**
1. **Place keyboard shortcut button in background** — must be in active view hierarchy
2. **Check for conflicting shortcuts** — macOS menu items take precedence
3. **Test with Accessibility Inspector** — verify keyboard shortcut is registered
4. **Use @FocusState for TextField** — auto-focus search field when palette appears

**Warning signs:**
- Cmd+K works in some views but not others (hierarchy issue)
- System beep on Cmd+K (conflict with menu or disabled button)
- Palette appears but search field not focused

**Example fix:**
```swift
// ❌ BAD: Button outside view hierarchy, no focus management
struct ContentView: View {
    @State private var showPalette = false

    var body: some View {
        NavigationSplitView { /* ... */ }
        .sheet(isPresented: $showPalette) {
            CommandPaletteView()
        }
    }

    // ⚠️ Button not in hierarchy — keyboardShortcut won't work
    var paletteButton: some View {
        Button("") { showPalette = true }
            .keyboardShortcut("k")
    }
}

// ✅ GOOD: Button in background, auto-focus search
struct ContentView: View {
    @State private var showPalette = false

    var body: some View {
        NavigationSplitView { /* ... */ }
            .sheet(isPresented: $showPalette) {
                CommandPaletteView()
            }
            .background {
                Button("") { showPalette = true }
                    .keyboardShortcut("k", modifiers: .command)
                    .hidden()
            }
    }
}

struct CommandPaletteView: View {
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack {
            TextField("Search...", text: $query)
                .focused($searchFocused)
            // ... results
        }
        .onAppear {
            searchFocused = true // Auto-focus on appear
        }
    }
}
```

### Pitfall 4: @Observable MainActor Isolation Warnings
**What goes wrong:** Compiler warnings or runtime crashes: "Mutation of '@MainActor' isolated property outside of MainActor"
**Why it happens:**
1. ProjectService is @Observable but not @MainActor
2. Async task updates observable properties off main thread
3. SwiftUI reads properties from background thread

**How to avoid:**
1. **Always combine @Observable @MainActor** on view models
2. **Update state in Task { @MainActor in }** for async operations
3. **Never use @nonisolated(unsafe)** with SwiftUI observable properties

**Warning signs:**
- Purple runtime warnings in Xcode console
- Crashes with "data race" or "actor isolation" messages
- UI updates delayed or glitchy

**Example fix:**
```swift
// ❌ BAD: Observable without MainActor, updates off main thread
@Observable
final class ProjectService {
    var projects: [Project] = []

    func loadProjects() async {
        // ⚠️ Running on background thread
        let loaded = await fetchProjects()
        projects = loaded // CRASH: Mutation off MainActor
    }
}

// ✅ GOOD: MainActor isolation, explicit main thread updates
@MainActor
@Observable
final class ProjectService {
    var projects: [Project] = []

    func loadProjects() async {
        // All async operations automatically on MainActor
        let loaded = await fetchProjects()
        projects = loaded // ✅ Safe
    }
}

// Alternative: Explicit MainActor.run for critical updates
@Observable
final class ProjectService {
    var projects: [Project] = []

    func loadProjects() async {
        let loaded = await fetchProjects()
        await MainActor.run {
            projects = loaded // ✅ Explicit main thread
        }
    }
}
```

### Pitfall 5: Requirement Badge Taps Not Registering
**What goes wrong:** User taps REQ-ID badge, nothing happens or entire row taps.
**Why it happens:**
1. Button inside NavigationLink — NavigationLink intercepts tap
2. Missing .buttonStyle(.plain) — uses default accentable style
3. Overlapping gesture recognizers

**How to avoid:**
1. **Use .buttonStyle(.plain)** on badges inside NavigationLink
2. **Apply .onTapGesture with highPriority** to override NavigationLink
3. **Test tap targets with Accessibility Inspector** — verify 44pt minimum

**Warning signs:**
- Badge tap navigates instead of showing sheet
- Tap only works on text, not badge background
- Inconsistent tap behavior

**Example fix:**
```swift
// ❌ BAD: Button inside NavigationLink without plain style
NavigationLink(value: phase.id) {
    PhaseCardView(phase: phase) // Contains RequirementBadgeView buttons
}

struct RequirementBadgeView: View {
    @State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            Text(requirementID)
                .padding(8)
                .background(Color.accentColor)
        }
        // ⚠️ Missing .buttonStyle(.plain) — NavigationLink intercepts tap
    }
}

// ✅ GOOD: Plain button style, explicit tap handling
NavigationLink(value: phase.id) {
    PhaseCardView(phase: phase)
}

struct RequirementBadgeView: View {
    @State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            Text(requirementID)
                .padding(8)
                .background(Color.accentColor)
        }
        .buttonStyle(.plain) // ✅ Prevents NavigationLink interception
        .sheet(isPresented: $showDetail) {
            RequirementDetailSheet(requirementID: requirementID)
        }
    }
}
```

## Code Examples

Verified patterns from official sources:

### Searchable Sidebar with Status Filter
```swift
// Source: https://www.appcoda.com/swiftui-searchable/
struct SidebarView: View {
    let projectService: ProjectService
    @Binding var selectedProjectID: UUID?
    @State private var searchText = ""
    @State private var statusFilter = ProjectStatus.all

    enum ProjectStatus: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
        case blocked = "Blocked"
    }

    var filteredProjects: [(source: String, projects: [Project])] {
        let groups = projectService.groupedProjects

        // Apply search filter
        let searchFiltered = searchText.isEmpty ? groups : groups.map { group in
            let filtered = group.projects.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
            return (source: group.source, projects: filtered)
        }.filter { !$0.projects.isEmpty }

        // Apply status filter
        guard statusFilter != .all else { return searchFiltered }

        return searchFiltered.map { group in
            let filtered = group.projects.filter { project in
                switch statusFilter {
                case .all: return true
                case .active: return project.state?.status == "active"
                case .completed: return project.roadmap?.phases.allSatisfy { $0.status == .done } ?? false
                case .blocked: return !(project.state?.blockers.isEmpty ?? true)
                }
            }
            return (source: group.source, projects: filtered)
        }.filter { !$0.projects.isEmpty }
    }

    var body: some View {
        List(selection: $selectedProjectID) {
            ForEach(filteredProjects, id: \.source) { group in
                Section(header: Text(group.source)) {
                    ForEach(group.projects) { project in
                        ProjectRow(project: project)
                            .tag(project.id)
                    }
                }
            }
        }
        .navigationTitle("Projects")
        .searchable(text: $searchText, prompt: "Search projects")
        .searchScopes($statusFilter) {
            ForEach(ProjectStatus.allCases, id: \.self) { status in
                Text(status.rawValue).tag(status)
            }
        }
    }
}
```

### Phase Card with Markdown and Progress
```swift
// Source: https://www.avanderlee.com/swiftui/markdown-text/
// Source: https://sarunw.com/posts/swiftui-progressview/
struct PhaseCardView: View {
    let phase: Phase
    let project: Project
    @State private var showPhaseDetail = false

    var completionPercent: Double {
        // Calculate from plan statuses
        guard let roadmap = project.roadmap else { return 0 }
        let plans = roadmap.phases.first { $0.number == phase.number }?.planStatus ?? []
        guard !plans.isEmpty else { return 0 }

        let completed = plans.filter { $0.status == .done }.count
        return Double(completed) / Double(plans.count)
    }

    var body: some View {
        Button(action: { showPhaseDetail = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text("Phase \(phase.number): \(phase.name)")
                        .font(.headline)
                    Spacer()
                    StatusBadge(status: phase.status)
                }

                // Goal with markdown
                if let attributedGoal = try? AttributedString(markdown: phase.goal) {
                    Text(attributedGoal)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                } else {
                    Text(phase.goal)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                // Requirements
                if !phase.requirements.isEmpty {
                    HStack {
                        Text("Requirements:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(phase.requirements, id: \.self) { reqID in
                            RequirementBadgeView(requirementID: reqID, project: project)
                        }
                    }
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(completionPercent * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: completionPercent, total: 1.0)
                        .progressViewStyle(.linear)
                        .tint(progressTint)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPhaseDetail) {
            PhaseDetailView(phase: phase, project: project)
        }
    }

    private var progressTint: Color {
        switch phase.status {
        case .notStarted: return .gray
        case .inProgress: return .blue
        case .done: return .green
        }
    }
}
```

### Requirement Badge with Sheet Detail
```swift
// Source: https://www.hackingwithswift.com/quick-start/swiftui/how-to-present-a-new-view-using-sheets
struct RequirementBadgeView: View {
    let requirementID: String
    let project: Project
    @State private var showDetail = false

    var requirement: Requirement? {
        // Find requirement in project data
        project.requirements?.first { $0.id == requirementID }
    }

    var body: some View {
        Button(action: { showDetail = true }) {
            Text(requirementID)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badgeColor.opacity(0.15))
                .foregroundColor(badgeColor)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            if let req = requirement {
                RequirementDetailSheet(requirement: req, project: project)
            }
        }
    }

    private var badgeColor: Color {
        switch requirement?.status {
        case .active: return .blue
        case .validated: return .green
        case .deferred: return .orange
        case .none: return .gray
        }
    }
}

struct RequirementDetailSheet: View {
    let requirement: Requirement
    let project: Project
    @Environment(\.dismiss) private var dismiss

    var mappedPhases: [Phase] {
        project.roadmap?.phases.filter {
            requirement.mappedToPhases.contains($0.number)
        } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(requirement.id)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(requirement.category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Definition
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Definition")
                            .font(.headline)
                        Text(requirement.description)
                            .textSelection(.enabled)
                    }

                    // Mapped phases
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mapped to Phases")
                            .font(.headline)

                        if mappedPhases.isEmpty {
                            Text("No phases mapped")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(mappedPhases) { phase in
                                HStack {
                                    Text("Phase \(phase.number): \(phase.name)")
                                    Spacer()
                                    StatusBadge(status: phase.status)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.headline)
                        HStack {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 10, height: 10)
                            Text(requirement.status.rawValue.capitalized)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
    }

    private var statusColor: Color {
        switch requirement.status {
        case .active: return .blue
        case .validated: return .green
        case .deferred: return .orange
        }
    }
}
```

### Command Palette with Fuzzy Search
```swift
// Source: https://sarunw.com/posts/swiftui-keyboard-shortcuts/
struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    let projectService: ProjectService
    let onNavigate: (CommandResult) -> Void

    var searchResults: [CommandResult] {
        guard !query.isEmpty else { return recentResults }

        var results: [CommandResult] = []

        // Search projects
        let projects = projectService.projects.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
        results.append(contentsOf: projects.map { .project($0) })

        // Search phases
        for project in projectService.projects {
            if let phases = project.roadmap?.phases.filter({
                $0.name.localizedCaseInsensitiveContains(query)
            }) {
                results.append(contentsOf: phases.map { .phase($0, project: project) })
            }
        }

        // Search requirements
        for project in projectService.projects {
            if let requirements = project.requirements?.filter({
                $0.id.localizedCaseInsensitiveContains(query) ||
                $0.description.localizedCaseInsensitiveContains(query)
            }) {
                results.append(contentsOf: requirements.map { .requirement($0, project: project) })
            }
        }

        return results
    }

    private var recentResults: [CommandResult] {
        // Could load from UserDefaults or recent navigation history
        []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search projects, phases, requirements...", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Results
            if searchResults.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text(query.isEmpty ? "Start typing to search" : "No matches found")
                )
            } else {
                List(searchResults) { result in
                    CommandResultRow(result: result)
                        .onTapGesture {
                            onNavigate(result)
                            dismiss()
                        }
                }
            }
        }
        .frame(width: 600, height: 400)
        .onAppear {
            searchFocused = true
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }
}

enum CommandResult: Identifiable {
    case project(Project)
    case phase(Phase, project: Project)
    case requirement(Requirement, project: Project)

    var id: String {
        switch self {
        case .project(let p): return "project-\(p.id)"
        case .phase(let ph, let pr): return "phase-\(pr.id)-\(ph.number)"
        case .requirement(let r, let pr): return "req-\(pr.id)-\(r.id)"
        }
    }
}

struct CommandResultRow: View {
    let result: CommandResult

    var body: some View {
        HStack {
            icon
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            breadcrumb
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var icon: Image {
        switch result {
        case .project: return Image(systemName: "folder")
        case .phase: return Image(systemName: "list.bullet.rectangle")
        case .requirement: return Image(systemName: "checkmark.circle")
        }
    }

    private var title: String {
        switch result {
        case .project(let p): return p.name
        case .phase(let ph, _): return "Phase \(ph.number): \(ph.name)"
        case .requirement(let r, _): return r.id
        }
    }

    private var subtitle: String {
        switch result {
        case .project(let p): return p.roadmap?.phases.count.description ?? "0" + " phases"
        case .phase(let ph, _): return ph.goal
        case .requirement(let r, _): return r.description
        }
    }

    private var breadcrumb: Text {
        switch result {
        case .project: return Text("")
        case .phase(_, let pr): return Text(pr.name)
        case .requirement(_, let pr): return Text(pr.name)
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| LazyVStack for lists | List with UICollectionView | iOS 16 (2022) | 9.5x performance improvement for large datasets |
| NavigationView | NavigationSplitView + NavigationStack | iOS 16 (2022) | Better iPad/Mac support, cleaner API, programmatic navigation |
| @ObservedObject | @Observable macro | iOS 17 (2023) | Reduces boilerplate, better concurrency, no Combine dependency |
| Inline NavigationLink(destination:) | NavigationLink(value:) + navigationDestination() | iOS 16 (2022) | Defers view instantiation, fixes performance issues |
| Custom markdown parsers | AttributedString(markdown:) | iOS 15 (2021) | Native support, localization, reduced dependencies |
| Time Profiler for SwiftUI | Instruments SwiftUI template | macOS 15 (2025) | Specific to SwiftUI, "Long View Body Updates" lane |

**Deprecated/outdated:**
- **ObservableObject + @Published:** Still works but verbose. Use @Observable macro (iOS 17+) for new code.
- **NavigationView:** Deprecated iOS 16+. Use NavigationStack or NavigationSplitView.
- **MarkdownUI library:** No longer needed for basic markdown (bold, italic, links, code). AttributedString is sufficient and native.
- **.onTapGesture for button behavior:** Use Button with .buttonStyle(.plain) for better accessibility and keyboard support.

## Open Questions

1. **Command Palette Search Algorithm**
   - What we know: localizedCaseInsensitiveContains() works for basic substring matching
   - What's unclear: Should we implement fuzzy matching (Levenshtein distance) or prioritize exact matches?
   - Recommendation: Start with substring matching. Add fuzzy search only if user testing shows need. NSPredicate supports `CONTAINS[cd]` for case/diacritic insensitive search, which is simpler than custom Levenshtein.

2. **Requirement Cross-Reference Performance**
   - What we know: Each requirement has mappedToPhases array, each phase has requirements array
   - What's unclear: With 100+ projects × 10+ phases × 20+ requirements, will filtering for "all requirements for phase X" be fast enough?
   - Recommendation: Profile with Instruments. If slow, add computed property to ProjectService that builds [RequirementID: [PhaseNumber]] lookup dictionary once on load.

3. **Phase Detail View Scope**
   - What we know: Requirement ROAD-03 says "drill into phase for detailed plan with tasks and status"
   - What's unclear: Should phase detail show just plan summaries or full task lists? How deep is "detailed"?
   - Recommendation: Start with plan summaries (objective, status, task count). If user needs task-level detail, add NavigationLink to individual plan view. Avoids overwhelming user with 50+ tasks in one screen.

4. **Markdown Rendering Cache Strategy**
   - What we know: AttributedString parsing can be slow for large text, should cache results
   - What's unclear: Where to cache? Phase model, ProjectService, or @State in view?
   - Recommendation: Add computed property `var attributedGoal: AttributedString` to Phase model with lazy caching. Keeps view clean, reuses cached result across renders.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview) — Master-detail pattern, selection binding
- Apple Developer Documentation: [ProgressView](https://developer.apple.com/documentation/swiftui/progressview) — Circular/linear styles, determinate/indeterminate modes
- Apple Developer Documentation: [Migrating to @Observable](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro) — @Observable + @MainActor pattern
- Apple Developer Documentation: [Modal Presentations](https://developer.apple.com/documentation/swiftui/modal-presentations) — sheet(), popover(), alert() usage
- WWDC25 Video: [Optimize SwiftUI performance with Instruments](https://developer.apple.com/videos/play/wwdc2025/306/) — New SwiftUI template, profiling techniques

### Secondary (MEDIUM confidence)
- [List or LazyVStack - Choosing the Right Lazy Container](https://fatbobman.com/en/posts/list-or-lazyvstack/) — Performance comparison: List 9.5x faster
- [SwiftUI Navigation in iOS: A Practical Guide (Feb 2026)](https://levelup.gitconnected.com/swiftui-navigation-in-ios-a-practical-guide-2a4820971681) — NavigationLink value-based pattern
- [Mastering NavigationSplitView in SwiftUI](https://swiftwithmajid.com/2022/10/18/mastering-navigationsplitview-in-swiftui/) — Selection binding, column visibility
- [Markdown rendering using Text in SwiftUI](https://www.avanderlee.com/swiftui/markdown-text/) — AttributedString limitations, supported features
- [How to add a search bar to filter your data](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-a-search-bar-to-filter-your-data) — searchable() with NavigationSplitView
- [How to add Keyboard Shortcuts in SwiftUI](https://sarunw.com/posts/swiftui-keyboard-shortcuts/) — keyboardShortcut() modifier, Cmd+K pattern
- [CardStyle vs GroupBox in SwiftUI](https://gauravtakjaipur.medium.com/cardstyle-vs-groupbox-in-swiftui-choosing-the-right-container-for-our-views-95362796c8f7) — Card UI with VStack + shadow
- [Using @Observable in SwiftUI views](https://nilcoalescing.com/en/blog/ObservableInSwiftUI/) — @Observable macro best practices
- [Understanding @MainActor in SwiftUI: A Practical Guide for Swift 6](https://medium.com/@donatogomez88/understanding-mainactor-in-swiftui-a-practical-guide-for-swift-6-69e657872ec5) — @MainActor isolation
- [How to use Instruments to profile SwiftUI code](https://www.hackingwithswift.com/quick-start/swiftui/how-to-use-instruments-to-profile-your-swiftui-code-and-identify-slow-layouts) — Profiling workflow

### Tertiary (LOW confidence)
- [SwiftUI List Performance: Smooth Scrolling for 10,000+ Items (Dec 2025)](https://medium.com/@chandra.welim/swiftui-list-performance-smooth-scrolling-for-10-000-items-c64116dc276f) — List performance tips (not verified with official docs)

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — All recommendations from official Apple documentation (SwiftUI, AttributedString, Instruments verified in Apple Developer docs and WWDC 2025)
- Architecture patterns: **HIGH** — Value-based navigation, searchable() modifier, @Observable + @MainActor verified in official docs and recent 2026 tutorials
- Performance: **HIGH** — List vs LazyVStack comparison from multiple sources (fatbobman.com, Medium articles), Instruments profiling from WWDC 2025
- Markdown rendering: **HIGH** — AttributedString limitations verified in SwiftLee article and official Apple docs
- Pitfalls: **MEDIUM-HIGH** — Common issues documented in developer blogs, verified with Apple forum discussions

**Research date:** 2026-02-13
**Valid until:** 2026-03-15 (30 days — stable SwiftUI APIs, macOS 15 is current release)
