---
phase: quick-33
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Services/SearchService.swift
  - GSDMonitor/Views/CommandPalette/CommandPaletteView.swift
  - GSDMonitor/Views/ContentView.swift
autonomous: true
requirements: [QUICK-33]
must_haves:
  truths:
    - "Cmd+K opens a centered overlay search palette"
    - "Typing filters results across all loaded projects (phases, requirements, plans, state)"
    - "Arrow keys navigate results, Enter selects, Escape closes"
    - "Results grouped by type (Project, Phase, Requirement, Plan)"
    - "Selecting a result navigates to the project and opens relevant detail"
  artifacts:
    - path: "GSDMonitor/Services/SearchService.swift"
      provides: "Cross-project search with scoring"
    - path: "GSDMonitor/Views/CommandPalette/CommandPaletteView.swift"
      provides: "Overlay UI with keyboard navigation"
  key_links:
    - from: "ContentView.swift"
      to: "CommandPaletteView"
      via: "Cmd+K keyboard shortcut toggles overlay"
    - from: "CommandPaletteView"
      to: "SearchService"
      via: "Text input triggers search across projectService.projects"
    - from: "CommandPaletteView"
      to: "ContentView selectedProjectID"
      via: "Selection callback sets project and dismisses palette"
---

<objective>
Implement a Cmd+K command palette for cross-project search in GSD Monitor.

Purpose: Let users instantly find phases, requirements, plans, and projects across all loaded projects without scrolling through the sidebar.
Output: SearchService for scoring/ranking + CommandPaletteView overlay + Cmd+K wiring in ContentView.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Models/Project.swift
@GSDMonitor/Models/Phase.swift
@GSDMonitor/Models/Requirement.swift
@GSDMonitor/Models/Plan.swift
@GSDMonitor/Models/Roadmap.swift
@GSDMonitor/Models/State.swift
@GSDMonitor/Services/ProjectService.swift
@GSDMonitor/Views/ContentView.swift
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Theme/Theme.swift

<interfaces>
<!-- Key types the executor needs -->

From Project.swift:
```swift
struct Project: Identifiable {
    let id: UUID
    let name: String
    let path: URL
    var roadmap: Roadmap?
    var state: State?
    var requirements: [Requirement]?
    var plans: [Plan]?
}
```

From Phase.swift:
```swift
struct Phase: Identifiable {
    let number: Int
    let name: String
    let goal: String
    let status: PhaseStatus
    let requirements: [String]
}
```

From Requirement.swift:
```swift
struct Requirement: Identifiable {
    let id: String       // e.g. "NAV-01"
    let category: String
    let description: String
    let status: RequirementStatus
}
```

From Plan.swift:
```swift
struct Plan: Identifiable {
    let phaseNumber: Int
    let planNumber: Int
    let objective: String
    let tasks: [Task]
    let status: PlanStatus
}
```

From ContentView.swift:
```swift
// Key state to wire into:
@SwiftUI.State private var projectService = ProjectService()
@SwiftUI.State private var selectedProjectID: UUID?
// ProjectService.projects: [Project] — all loaded projects
```

From Theme.swift:
```swift
// Use these for consistent styling:
Theme.bg0, Theme.bg0Hard, Theme.bg1, Theme.bg2, Theme.bg3
Theme.fg0, Theme.fg1, Theme.fg4
Theme.textPrimary, Theme.textSecondary, Theme.textMuted
Theme.accent, Theme.surface
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create SearchService with scoring engine and CommandPaletteView</name>
  <files>GSDMonitor/Services/SearchService.swift, GSDMonitor/Views/CommandPalette/CommandPaletteView.swift</files>
  <action>
**SearchService.swift** — A pure search engine that operates on `[Project]`:

Create an enum `SearchResultType` with cases: `.project`, `.phase(Phase)`, `.requirement(Requirement)`, `.plan(Plan)`.

Create a struct `SearchResult: Identifiable` with fields:
- `id: UUID` (use UUID() default)
- `projectID: UUID` — which project this result belongs to
- `projectName: String` — for display in grouped results
- `title: String` — the matched item's name/title
- `subtitle: String` — secondary info (phase number, req ID, plan objective excerpt)
- `type: SearchResultType`
- `score: Int` — relevance score

Create `SearchService` class with a single method:
```swift
func search(query: String, in projects: [Project]) -> [String: [SearchResult]]
```
Returns results grouped by type label string ("Projects", "Phases", "Requirements", "Plans").

**Scoring algorithm:**
- Title exact match (case-insensitive contains): +10 points
- Content match (goal, description, objective): +1 point
- Word boundary bonus: if query matches at start of a word in title, +5 bonus
- Minimum score threshold: only return results with score > 0

**What to search per type:**
- **Projects**: name (title), state?.status (content)
- **Phases**: name (title), goal (content), requirements joined (content)
- **Requirements**: id + description (title), category (content)
- **Plans**: objective (title), task names joined (content)

Sort results within each group by score descending, then alphabetically.

---

**CommandPaletteView.swift** — A floating overlay with search + keyboard nav:

Props/bindings:
- `projects: [Project]` — from projectService
- `isPresented: Binding<Bool>` — controls visibility
- `onSelect: (SearchResult) -> Void` — callback when user picks a result

Structure:
1. Semi-transparent black backdrop (`Color.black.opacity(0.4)`) covering full window, tap to dismiss
2. Centered card (max width 560, max height 420) with `Theme.bg0Hard` background, rounded corners 12, shadow
3. Top: TextField with magnifying glass icon, placeholder "Search projects, phases, requirements...", auto-focused using `@FocusState`
4. Divider
5. ScrollViewReader + ScrollView with grouped results
6. Each group: section header (type name in `Theme.fg4`, `.caption` font)
7. Each result row: title (Theme.fg1) + subtitle (Theme.fg4, .caption), highlighted row uses `Theme.bg2`
8. Empty state: "No results" in Theme.fg4 when query non-empty but no results
9. Footer hint: "arrow-up arrow-down to navigate, return to select, esc to close" in Theme.textMuted, .caption2

**Keyboard navigation state:**
- `@SwiftUI.State private var selectedIndex: Int = 0` — flat index across all results
- `@SwiftUI.State private var flatResults: [SearchResult] = []` — flattened for keyboard nav
- Use `.onKeyPress` (macOS 14+) OR `.background(KeyEventHandlingView())` with NSView subclass to capture arrow keys, Enter, Escape
- Arrow up/down: move selectedIndex (clamp 0...flatResults.count-1), scroll to visible
- Enter: call onSelect with flatResults[selectedIndex], dismiss
- Escape: dismiss

Use `.onChange(of: searchText)` to debounce search (no actual debounce needed — SearchService is synchronous and fast on small datasets). Update flatResults and grouped results on each keystroke. Reset selectedIndex to 0 on new search.

For key handling, use `.onKeyPress(.upArrow)`, `.onKeyPress(.downArrow)`, `.onKeyPress(.return)`, `.onKeyPress(.escape)` modifiers on the main VStack — these are available on macOS 14+. Check deployment target; if it's macOS 13, use an NSViewRepresentable key monitor instead (wrap in `LocalEventMonitor` that listens for `.keyDown` events).
  </action>
  <verify>
    <automated>cd . && swift build 2>&1 | tail -5</automated>
  </verify>
  <done>SearchService scores and groups results correctly. CommandPaletteView renders as floating overlay with text field and result list. Both files compile without errors.</done>
</task>

<task type="auto">
  <name>Task 2: Wire Cmd+K shortcut in ContentView and handle navigation</name>
  <files>GSDMonitor/Views/ContentView.swift</files>
  <action>
In ContentView.swift:

1. Add state: `@SwiftUI.State private var showCommandPalette = false`

2. Add the CommandPaletteView as an overlay on the NavigationSplitView:
```swift
.overlay {
    if showCommandPalette {
        CommandPaletteView(
            projects: projectService.projects,
            isPresented: $showCommandPalette,
            onSelect: { result in
                handleCommandPaletteSelection(result)
            }
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}
```

3. Add keyboard shortcut via `.onKeyPress` or a menu command. The cleanest approach for Cmd+K is to use `.commands` or a hidden Button with `.keyboardShortcut("k", modifiers: .command)`. Use this pattern:
```swift
.background {
    Button("") {
        withAnimation(.easeOut(duration: 0.15)) {
            showCommandPalette.toggle()
        }
    }
    .keyboardShortcut("k", modifiers: .command)
    .hidden()
}
```
Place this on the NavigationSplitView so it works globally regardless of focus.

4. Add the navigation handler method:
```swift
private func handleCommandPaletteSelection(_ result: SearchResult) {
    // Navigate to the project
    selectedProjectID = result.projectID

    // Dismiss palette
    withAnimation(.easeOut(duration: 0.15)) {
        showCommandPalette = false
    }
}
```

This selects the project in the sidebar. The detail view auto-updates via the existing binding. For phase/requirement/plan results, the user lands on the correct project and can see the relevant content in the detail view. (Opening a specific phase sheet from the palette would require threading the phase through — keep it simple: navigate to project only for v1.)
  </action>
  <verify>
    <automated>cd . && swift build 2>&1 | tail -5</automated>
  </verify>
  <done>Cmd+K toggles command palette overlay. Selecting a result navigates to the correct project. Escape and backdrop click dismiss the palette. Full app compiles and runs.</done>
</task>

</tasks>

<verification>
1. `swift build` compiles without errors
2. Run app: Cmd+K opens palette overlay centered on window
3. Type a project name — results appear grouped and scored
4. Arrow keys move highlight, Enter selects and navigates to project
5. Escape closes palette, clicking backdrop closes palette
6. Search across phases, requirements, plans returns grouped results
</verification>

<success_criteria>
- Cmd+K opens a command palette overlay anywhere in the app
- Typing filters across all loaded projects, phases, requirements, plans
- Results scored: title match = 10, content = 1, word boundary = +5
- Results grouped by type with section headers
- Keyboard navigation: arrows, Enter, Escape all work
- Selecting a result navigates to the relevant project
- Gruvbox dark theme consistent with existing UI
</success_criteria>

<output>
After completion, create `.planning/quick/33-cmd-k-command-palette-s-gning-p-tv-rs-af/33-SUMMARY.md`
</output>
