# Phase 10: Enhanced Empty States - Research

**Researched:** 2026-02-16
**Domain:** SwiftUI ContentUnavailableView, Empty State UX, SF Symbols
**Confidence:** HIGH

## Summary

Phase 10 implements themed empty state views for three specific scenarios in GSD Monitor: sidebar with no projects discovered, detail view with no project selected, and detail view when a project has no phases. The implementation leverages SwiftUI's ContentUnavailableView (introduced in iOS 17/macOS 14) with custom SF Symbols and Gruvbox colors from the existing Theme system established in Phase 6.

ContentUnavailableView provides three flexible initializers: (1) simple title + system image, (2) title + image + description text, and (3) full closure-based customization with label, description, and actions. The view supports applying custom colors through Text view styling in the description parameter—allowing Gruvbox colors to be applied while maintaining the standard ContentUnavailableView structure.

Empty state UX best practices emphasize clear, actionable messaging: explain what's happening, why it's happening, and what users should do next. For developer tools like GSD Monitor, this translates to instructional text that guides users toward enabling project discovery or selecting a project, rather than generic "no data" messages.

**Primary recommendation:** Use ContentUnavailableView with closure-based initializer for full styling control. Apply Gruvbox foreground colors (Theme.fg1 for title, Theme.fg4 for description, Theme.textSecondary for icons) via Text view styling. Choose contextual SF Symbols: "folder.badge.questionmark" for no projects, "sidebar.left" for no selection, "doc.text.magnifyingglass" or "checklist" for no phases. Keep messaging instructional and encouraging.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Empty state locations
- Tom sidebar: when no projects are discovered
- Tom detail view: when no project is selected, or project has no phases

#### Visual approach
- Use ContentUnavailableView (native macOS pattern)
- SF Symbols for icons
- Gruvbox-farver from existing Theme system

### Claude's Discretion
- Which SF Symbols to use for each empty state
- Exact text/messaging for each empty state
- Icon sizing and layout details
- Whether to include subtle instructional text (e.g. "Tilføj scan source i indstillinger")

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VISL-03 | Empty states bruger themed ContentUnavailableView med relevante SF Symbols og forklarende tekst | ContentUnavailableView closure-based init enables custom Text styling with Gruvbox colors; SF Symbols provide contextual icons; UX best practices guide instructional messaging |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ContentUnavailableView | macOS 14.0+ | Empty state UI component | Native SwiftUI component for standardized empty states, introduced iOS 17/macOS 14 (Sonoma) |
| SF Symbols | macOS 11.0+ | System icon library | Native Apple icon system with 6,900+ symbols, automatic scaling, accessibility support |
| SwiftUI | macOS 14.0+ | UI framework | Native framework already in use throughout GSD Monitor |

### Supporting
N/A — ContentUnavailableView and SF Symbols are built into SwiftUI/macOS.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ContentUnavailableView | Custom VStack with centered text | ContentUnavailableView provides standard macOS empty state pattern, automatic localization support for .search variant, consistent spacing/styling |
| ContentUnavailableView.search | Custom ContentUnavailableView | .search variant auto-localizes but only fits search contexts; custom views needed for "no projects" and "no selection" states |
| Closure-based init | Simple title + systemImage init | Simple init doesn't allow custom Text styling for Gruvbox colors; closure-based enables full color control while maintaining ContentUnavailableView structure |

**Installation:**
No installation needed — ContentUnavailableView is part of SwiftUI on macOS 14.0+.

## Architecture Patterns

### Recommended Project Structure
Empty states will be integrated into existing views:
```
GSDMonitor/
├── Views/
│   ├── SidebarView.swift        # Already has emptyState computed property (line 69-75)
│   ├── DetailView.swift         # Already has empty state (line 106-110)
│   └── Components/              # Optional: extract ThemedContentUnavailableView if patterns repeat
└── Theme/
    └── Theme.swift              # Already contains fg1, fg4, textSecondary for styling
```

### Pattern 1: Themed ContentUnavailableView with Closure Init
**What:** Use closure-based ContentUnavailableView initializer to apply custom Gruvbox colors to Text elements while maintaining standard empty state structure
**When to use:** All empty states that need custom theming (sidebar, detail view)
**Example:**
```swift
// Source: Swift with Majid - Mastering ContentUnavailableView in SwiftUI
ContentUnavailableView {
    Label {
        Text("No Projects Found")
            .foregroundStyle(Theme.fg1)
    } icon: {
        Image(systemName: "folder.badge.questionmark")
            .foregroundStyle(Theme.textSecondary)
    }
} description: {
    Text("GSD projects will appear here when discovered in ~/Developer")
        .foregroundStyle(Theme.fg4)
}
```

### Pattern 2: Context-Specific SF Symbol Selection
**What:** Choose SF Symbols that communicate the specific empty state scenario
**When to use:** Selecting icons for each empty state type
**Example:**
```swift
// Empty sidebar (no projects discovered)
systemImage: "folder.badge.questionmark"  // Existing choice (SidebarView line 72)

// Detail view (no project selected)
systemImage: "sidebar.left"  // Existing choice (DetailView line 108)

// Detail view (project has no phases/roadmap)
systemImage: "doc.text.magnifyingglass"  // Suggests inspecting project files
// OR
systemImage: "checklist"  // Suggests creating a roadmap
// OR
systemImage: "list.bullet.clipboard"  // Planning/roadmap metaphor
```

### Pattern 3: Instructional Empty State Messaging
**What:** Clear, actionable copy that explains state and guides next steps
**When to use:** Writing description text for ContentUnavailableView
**Example:**
```swift
// Source: Empty State UX Best Practices (Contentphilic, UXPin)
// ❌ Vague: "No data available"
// ✅ Clear and actionable:

// Sidebar empty state
title: "No Projects Found"
description: "GSD projects will appear here when discovered in ~/Developer"

// Detail view - no selection
title: "Select a Project"
description: "Choose a project from the sidebar to view its roadmap"

// Detail view - no phases
title: "No Roadmap Data"
description: "This project doesn't have a ROADMAP.md file yet"
// Optional: Add action button to create roadmap
```

### Anti-Patterns to Avoid
- **Generic "No data" messaging:** Empty states should explain the specific scenario and guide action
- **Simple title + systemImage init without custom colors:** Won't apply Gruvbox theme colors; use closure-based init instead
- **Overusing ContentUnavailableView.search:** This pre-built variant only fits search contexts and auto-extracts searchable text—not applicable to "no projects" or "no selection" states
- **Large icon sizes:** ContentUnavailableView has standard sizing; don't override with custom .font() modifiers unless necessary
- **Omitting description text:** Description provides context and guidance—critical for good empty state UX

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Empty state layout | Custom VStack with centered text + image | ContentUnavailableView | Standard macOS pattern, consistent spacing, automatic layout adjustments, accessibility support |
| Icon scaling | Manual frame calculations | SF Symbols with .font() modifier | Symbols scale automatically with Dynamic Type and text size changes |
| Localization | Manual translation of empty state text | ContentUnavailableView.search for search states | .search variant auto-localizes, though custom states require manual translation |
| Empty state variants | Separate custom views for each empty state type | Single ContentUnavailableView with conditional content | Consistent structure, less code duplication, easier to maintain theme consistency |

**Key insight:** ContentUnavailableView was designed to standardize empty states across macOS apps—building custom layouts misses the benefits of consistent UX patterns, accessibility support, and automatic spacing adjustments.

## Common Pitfalls

### Pitfall 1: Using Simple Init Without Custom Styling
**What goes wrong:** `ContentUnavailableView("Title", systemImage: "icon")` renders with system default colors, not Gruvbox theme colors
**Why it happens:** Simple initializer doesn't expose Text views for custom styling
**How to avoid:** Use closure-based initializer with Label { Text().foregroundStyle() } pattern to apply theme colors
**Warning signs:** Empty state appears in system blue/gray instead of Gruvbox fg1/fg4

### Pitfall 2: Applying .foregroundStyle() to ContentUnavailableView Itself
**What goes wrong:** `.foregroundStyle()` modifier on ContentUnavailableView may not work as expected or may only affect some elements
**Why it happens:** ContentUnavailableView is a container view, not a single text element
**How to avoid:** Apply `.foregroundStyle()` to individual Text views inside the closure-based initializer
**Warning signs:** Colors don't change, or only icon color changes

### Pitfall 3: Generic Empty State Messaging
**What goes wrong:** Text like "No data available" doesn't explain the situation or guide action
**Why it happens:** Developers copy boilerplate empty state text without considering context
**How to avoid:** Follow UX best practices: explain what's happening (no projects discovered), why (GSD scans ~/Developer), what to do (wait for discovery or add manually)
**Warning signs:** Users confused about why the screen is empty or what to do next

### Pitfall 4: Duplicating Empty State Logic Across Views
**What goes wrong:** SidebarView and DetailView each implement their own styled ContentUnavailableView with repeated styling code
**Why it happens:** Each view independently implements empty states without extracting shared pattern
**How to avoid:** If styling patterns repeat (same color scheme for all empty states), consider extracting a ThemedContentUnavailableView helper or shared styling function
**Warning signs:** Theme color changes require updating multiple view files

### Pitfall 5: Choosing SF Symbols That Don't Match Context
**What goes wrong:** Using "exclamationmark.triangle" (warning) for "no projects" state suggests an error rather than normal first-run state
**Why it happens:** Developers pick visually interesting symbols without considering semantic meaning
**How to avoid:** Choose symbols that communicate the specific scenario: folder variants for file/project contexts, sidebar.left for "select something", doc/checklist for missing roadmap
**Warning signs:** User testing reveals confusion about whether empty state indicates an error or normal state

## Code Examples

Verified patterns from official sources and existing codebase:

### Existing Empty State Implementation (Before Phase 10)
```swift
// Source: GSDMonitor/Views/SidebarView.swift lines 69-75
private var emptyState: some View {
    ContentUnavailableView(
        "No Projects Found",
        systemImage: "folder.badge.questionmark",
        description: Text("GSD projects will appear here when discovered in ~/Developer")
    )
}

// Source: GSDMonitor/Views/DetailView.swift lines 106-110
ContentUnavailableView(
    "Select a Project",
    systemImage: "sidebar.left",
    description: Text("Choose a project from the sidebar to view its roadmap")
)
```
**Note:** These existing implementations use simple initializer—Phase 10 will enhance with Gruvbox colors.

### Themed ContentUnavailableView with Closure Init
```swift
// Source: Swift with Majid + Gruvbox Theme from Phase 6
private var emptyState: some View {
    ContentUnavailableView {
        Label {
            Text("No Projects Found")
                .foregroundStyle(Theme.fg1)  // Primary text color
        } icon: {
            Image(systemName: "folder.badge.questionmark")
                .foregroundStyle(Theme.textSecondary)  // Muted icon color
        }
    } description: {
        Text("GSD projects will appear here when discovered in ~/Developer")
            .foregroundStyle(Theme.fg4)  // Secondary text color
    }
}
```

### Context-Specific Empty States
```swift
// Sidebar: no projects discovered
private var noProjectsState: some View {
    ContentUnavailableView {
        Label {
            Text("No Projects Found")
                .foregroundStyle(Theme.fg1)
        } icon: {
            Image(systemName: "folder.badge.questionmark")
                .foregroundStyle(Theme.textSecondary)
        }
    } description: {
        Text("GSD projects will appear here when discovered in ~/Developer")
            .foregroundStyle(Theme.fg4)
    }
}

// Detail view: no project selected
private var noSelectionState: some View {
    ContentUnavailableView {
        Label {
            Text("Select a Project")
                .foregroundStyle(Theme.fg1)
        } icon: {
            Image(systemName: "sidebar.left")
                .foregroundStyle(Theme.textSecondary)
        }
    } description: {
        Text("Choose a project from the sidebar to view its roadmap")
            .foregroundStyle(Theme.fg4)
    }
}

// Detail view: project has no roadmap/phases
private var noRoadmapState: some View {
    ContentUnavailableView {
        Label {
            Text("No Roadmap Data")
                .foregroundStyle(Theme.fg1)
        } icon: {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
        }
    } description: {
        Text("This project doesn't have a ROADMAP.md file yet")
            .foregroundStyle(Theme.fg4)
    }
}
```

### Optional: Extracting Shared Pattern
```swift
// If multiple views need same styling pattern, extract helper
struct ThemedContentUnavailableView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .foregroundStyle(Theme.fg1)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(Theme.textSecondary)
            }
        } description: {
            Text(description)
                .foregroundStyle(Theme.fg4)
        }
    }
}

// Usage
ThemedContentUnavailableView(
    title: "No Projects Found",
    systemImage: "folder.badge.questionmark",
    description: "GSD projects will appear here when discovered in ~/Developer"
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom VStack layouts | ContentUnavailableView | iOS 17/macOS 14 (2023) | Standard empty state pattern, less boilerplate, consistent UX |
| Text("Title") | Label { Text() } icon: { Image() } | SwiftUI 2.0 (iOS 14/macOS 11) | Structured title + icon pattern, better accessibility |
| .foregroundColor() | .foregroundStyle() | SwiftUI 3.0 (iOS 15/macOS 12) | foregroundStyle() supports gradients, hierarchical rendering, semantic colors |

**Deprecated/outdated:**
- Custom centered VStack patterns — ContentUnavailableView replaces most custom empty state layouts
- .foregroundColor() — replaced by .foregroundStyle() with broader style support

## Open Questions

1. **Should "no roadmap" empty state include an action button?**
   - What we know: ContentUnavailableView supports actions { } closure for button placement
   - What's unclear: Whether GSD Monitor should provide "Create ROADMAP.md" action, or leave roadmap creation to external tools
   - Recommendation: Phase 10 scope is visual only—defer action buttons to future enhancement phase; just show instructional text for now

2. **Should empty states use Danish or English text?**
   - What we know: App UI uses Danish ("Vis i Finder", existing context menus are in Danish)
   - What's unclear: Whether empty state text should match existing Danish pattern or use English for clarity
   - Recommendation: Match existing app language (Danish) for consistency; existing empty states use English, so continue that pattern unless user prefers Danish

3. **Should "no matching projects" search state also be themed?**
   - What we know: SidebarView has separate `noMatchingProjectsState` for search filtering (line 77-82)
   - What's unclear: Whether search empty state should also get Gruvbox colors
   - Recommendation: Yes, apply same theming pattern for consistency across all empty states in the app

## Sources

### Primary (HIGH confidence)
- GSDMonitor/Views/SidebarView.swift lines 69-82 — Existing empty state implementations
- GSDMonitor/Views/DetailView.swift lines 106-110 — Existing detail view empty state
- GSDMonitor/Theme/Theme.swift — Gruvbox color definitions (fg1, fg4, textSecondary)
- [Apple Developer Documentation: ContentUnavailableView](https://developer.apple.com/documentation/swiftui/contentunavailableview) — Official API reference
- [Mastering ContentUnavailableView in SwiftUI - Swift with Majid](https://swiftwithmajid.com/2023/10/31/mastering-contentunavailableview-in-swiftui/) — Closure-based init patterns, custom styling
- [ContentUnavailableView: Handling Empty States - Antoine van der Lee](https://www.avanderlee.com/swiftui/contentunavailableview-handling-empty-states/) — Usage patterns, localization, trade-offs

### Secondary (MEDIUM confidence)
- [Showing empty states with ContentUnavailableView - Hacking with Swift](https://www.hackingwithswift.com/books/ios-swiftui/showing-empty-states-with-contentunavailableview) — Basic usage examples
- [Empty State UX Best Practices - Pencil & Paper](https://www.pencilandpaper.io/articles/empty-states) — Clear messaging, actionable guidance
- [Empty State UX Writing - Contentphilic](https://contentphilic.com/empty-state-ux-writing-examples/) — Writing patterns: explain what's happening, why, what to do next
- [Designing the Overlooked Empty States - UXPin](https://www.uxpin.com/studio/blog/ux-best-practices-designing-the-overlooked-empty-states/) — Context-specific messaging, encouraging tone
- [SF Symbols - Apple Developer](https://developer.apple.com/sf-symbols/) — Symbol library access and browsing

### Tertiary (LOW confidence)
- [Ways to customize text color in SwiftUI](https://nilcoalescing.com/blog/ForegroundColorStyleAndTintInSwiftUI/) — foregroundStyle() vs foregroundColor(), general styling approaches

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — ContentUnavailableView is native macOS 14+ API, existing codebase already uses it (SidebarView, DetailView)
- Architecture: HIGH — Closure-based init pattern verified in Swift with Majid guide, existing Theme colors documented in Theme.swift
- Pitfalls: MEDIUM-HIGH — foregroundStyle() application patterns verified in sources, generic messaging pitfall documented in UX best practices

**Research date:** 2026-02-16
**Valid until:** 60 days (stable SwiftUI APIs, UX best practices don't change rapidly)
