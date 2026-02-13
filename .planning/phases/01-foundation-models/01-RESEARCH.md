# Phase 1: Foundation & Models - Research

**Researched:** 2026-02-13
**Domain:** Swift 6 concurrency, SwiftUI NavigationSplitView, Codable models, macOS theme integration
**Confidence:** HIGH

## Summary

Phase 1 establishes the architectural foundation for GSD Monitor by implementing Swift 6 strict concurrency from the start, creating all domain models with proper Codable conformance, building an empty UI skeleton using NavigationSplitView, and ensuring automatic dark/light mode support.

The critical path involves enabling Swift 6 strict concurrency checking immediately (not later), structuring models to match the .planning directory structure exactly, and using NavigationSplitView with proper empty state handling through ContentUnavailableView.

**Primary recommendation:** Enable Swift 6 strict concurrency from Xcode project creation and test memory behavior with Instruments from day one. Use two-column NavigationSplitView (sidebar + detail) rather than three-column to match the app's simple navigation needs. Models should be simple value types (structs) conforming to Codable and Identifiable, avoiding SwiftData complexity for read-only monitoring.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift | 6.0+ | Language with strict concurrency | Compile-time data race prevention is mandatory for modern macOS apps. Swift 6 makes concurrency safety default. |
| SwiftUI | macOS 14+ | Declarative UI framework | Native macOS UI with NavigationSplitView for sidebar layouts, automatic theme support, first-class markdown rendering. |
| Foundation | Built-in | Codable, FileManager, AttributedString | Standard library for JSON parsing, file operations, and data structures. Zero external dependencies. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Instruments | Built-in (Xcode) | Memory profiling, leak detection | Phase 1 verification: test NavigationSplitView navigation for memory leaks using Leaks template |
| Xcode Previews | Xcode 15+ | SwiftUI preview with dark/light modes | Verify theme support by setting `.preferredColorScheme(.dark)` and `.preferredColorScheme(.light)` in previews |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Struct models + Codable | SwiftData with @Model | SwiftData adds persistence complexity unnecessary for read-only file monitoring. Codable structs are simpler, thread-safe by default. |
| Two-column NavigationSplitView | Three-column | Three columns (sidebar → content → detail) unnecessary for GSD Monitor. App navigation is simple: project list → roadmap view. |
| @Observable (iOS 17+) | ObservableObject + @Published | @Observable is simpler but has memory leak issues when used with @State in macOS 14 (see PITFALLS.md). For Phase 1 empty UI, prefer @State for simple value types only. |

**Installation:**
No external packages needed. All components are built into macOS 14+ and Xcode 15+.

## Architecture Patterns

### Recommended Project Structure
```
GSDMonitor/
├── App/
│   ├── GSDMonitorApp.swift           # @main entry point
│   └── Assets.xcassets               # App icon, no custom colors (use system)
├── Views/
│   ├── ContentView.swift             # Root NavigationSplitView
│   ├── EmptyStateView.swift          # ContentUnavailableView for empty sidebar
│   └── EmptyDetailView.swift         # ContentUnavailableView for "Select a project"
├── Models/
│   ├── Project.swift                 # Project model
│   ├── Roadmap.swift                 # ROADMAP.md structure
│   ├── Phase.swift                   # Phase with milestones
│   ├── State.swift                   # STATE.md structure
│   ├── Requirement.swift             # REQUIREMENTS.md structure
│   └── Plan.swift                    # PLAN.md structure
└── Utilities/
    └── PreviewData.swift             # Mock data for SwiftUI previews
```

### Pattern 1: Swift 6 Strict Concurrency from Day One

**What:** Enable Swift 6 language mode and strict concurrency checking at Xcode project creation.

**When to use:** Always for new projects in 2026. Strict concurrency prevents data races at compile time.

**Example Xcode configuration:**
```
Build Settings:
- Swift Language Version: Swift 6
- Strict Concurrency Checking: Complete (previously "Minimal")
```

**Why critical for Phase 1:** Retrofitting concurrency safety later is expensive. Swift 6 requires @MainActor annotations on UI code, and models must be Sendable. Starting with strict mode prevents accumulating warnings and ensures clean architecture.

**Warning signs if skipped:**
- Compiler warnings about actor isolation pile up
- Thread Sanitizer shows data races in Instruments
- Crashes when navigating between views

### Pattern 2: Codable Models Matching File Structure

**What:** Create simple struct models with Codable conformance that mirror the exact structure of .planning directory files.

**When to use:** For all domain models representing file content (ROADMAP.md, STATE.md, config.json).

**Example:**
```swift
// Source: Codable best practices verified across multiple 2026 sources
struct Project: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let path: URL
    var roadmap: Roadmap?
    var state: State?
    var config: PlanningConfig?

    enum CodingKeys: String, CodingKey {
        case id, name, path, roadmap, state, config
    }

    // Custom init for URL decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        // URL requires custom decoding from string path
        let pathString = try container.decode(String.self, forKey: .path)
        path = URL(fileURLWithPath: pathString)

        // Optional properties use decodeIfPresent
        roadmap = try container.decodeIfPresent(Roadmap.self, forKey: .roadmap)
        state = try container.decodeIfPresent(State.self, forKey: .state)
        config = try container.decodeIfPresent(PlanningConfig.self, forKey: .config)
    }
}

struct Roadmap: Codable, Sendable {
    let phases: [Phase]
}

struct Phase: Identifiable, Codable, Sendable {
    let id: UUID
    let number: Int
    let name: String
    let goal: String
    let dependencies: [String]
    let requirements: [String]
    let milestones: [String]

    // Use decodeIfPresent for optional fields
    // Use CodingKeys for snake_case JSON if needed
}
```

**Key principles:**
- All models are `Sendable` (required for Swift 6 concurrency safety)
- Use `struct` not `class` for immutability and thread safety
- Use `UUID` for `Identifiable.id` to avoid collisions
- Use `decodeIfPresent` for optional fields to handle missing JSON keys gracefully
- Implement custom `init(from decoder:)` for complex types like `URL`

### Pattern 3: Two-Column NavigationSplitView with Empty States

**What:** NavigationSplitView with sidebar (project list) and detail (roadmap view), using ContentUnavailableView for empty states.

**When to use:** macOS apps with sidebar navigation pattern. Two columns are sufficient for GSD Monitor's simple navigation.

**Example:**
```swift
// Source: Apple Developer Documentation + 2026 NavigationSplitView patterns
struct ContentView: View {
    @State private var selectedProjectID: Project.ID?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects Found",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Scan ~/Developer for GSD projects")
                )
            } else {
                List(projects, selection: $selectedProjectID) { project in
                    NavigationLink(value: project.id) {
                        Text(project.name)
                    }
                }
                .navigationTitle("Projects")
            }
        } detail: {
            // Detail
            if let selectedProject = projects.first(where: { $0.id == selectedProjectID }) {
                RoadmapView(project: selectedProject)
            } else {
                ContentUnavailableView(
                    "Select a Project",
                    systemImage: "sidebar.left",
                    description: Text("Choose a project from the sidebar to view its roadmap")
                )
            }
        }
        .navigationSplitViewStyle(.balanced) // Equal column widths on macOS
    }

    // Mock data for Phase 1 skeleton
    private var projects: [Project] {
        // Return empty array to test empty states
        []
    }
}
```

**macOS-specific considerations:**
- `.navigationSplitViewStyle(.balanced)` provides proper macOS layout
- Sidebar is translucent by default on macOS (no customization needed)
- `ContentUnavailableView` is available macOS 14+, perfect for empty states
- Use `systemImage` icons for native macOS feel

### Pattern 4: Automatic Dark/Light Mode Support

**What:** SwiftUI automatically adapts to macOS system appearance. No custom code needed for Phase 1.

**When to use:** Always. Never override system appearance in Phase 1.

**Example:**
```swift
// Source: Apple Developer Documentation on Supporting Dark Mode
// NO CODE NEEDED for automatic theme support
// SwiftUI views automatically adapt to system appearance

// For previews, test both modes:
#Preview("Light Mode") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ContentView()
        .preferredColorScheme(.dark)
}
```

**How SwiftUI handles themes automatically:**
- Text views are black in light mode, white in dark mode automatically
- Background colors are inverted automatically
- System colors (Color.primary, Color.secondary) adapt automatically
- No need to detect `@Environment(\.colorScheme)` unless customizing behavior

**Phase 1 verification:**
- Run app and toggle macOS System Settings → Appearance
- App should switch between light/dark mode instantly with no code changes

### Pattern 5: Memory-Safe Navigation with Instruments

**What:** Verify NavigationSplitView navigation doesn't leak memory using Instruments Leaks template.

**When to use:** Phase 1 verification before moving to Phase 2.

**Example workflow:**
```
1. Product → Profile (⌘I) in Xcode
2. Select "Leaks" template
3. Run app
4. Navigate between projects in sidebar repeatedly
5. Check for:
   - No "Leaked allocation" entries in Instruments
   - Memory graph shows views deallocate when navigating away
   - deinit called on view models (if any exist)
```

**Warning signs of memory leaks:**
- Memory usage grows continuously when navigating
- Instruments shows "Leaked allocation" for SwiftUI views
- `deinit` never called on objects that should be deallocated

**Phase 1 specific concern:** @Observable + @State memory leak on macOS 14 (documented in PITFALLS.md). For empty skeleton, use @State only for simple value types like `selectedProjectID: UUID?`, never for complex reference types.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Empty state UI | Custom "no data" views with VStack/Image/Text | `ContentUnavailableView` (macOS 14+) | System-standard design, accessibility built-in, matches macOS native apps like Photos/Files. Custom empty states require more code and won't match system conventions. |
| Dark/light mode switching | Manual theme detection with @Environment(\.colorScheme) | Automatic SwiftUI behavior | SwiftUI adapts to system appearance automatically. Manual switching adds complexity and can break system integration (Focus modes, auto-switching). |
| UUID generation for models | Custom ID generation logic | `UUID()` initializer | Foundation's UUID is collision-resistant, Codable-compatible, and Sendable. Custom IDs risk collisions and require extra Codable implementation. |
| JSON parsing | Manual JSONSerialization + dictionaries | Codable protocol | Codable is type-safe, handles nested objects, throws descriptive errors. Manual parsing is brittle and loses compile-time safety. |
| Model validation | Throwing errors in model init | Custom `init(from decoder:)` with fallback defaults | Codable init can provide sensible defaults for missing/malformed data, improving resilience. Throwing errors causes blank screens; graceful degradation is better UX. |

**Key insight:** SwiftUI provides high-quality built-in components for common patterns (empty states, themes). Custom implementations add code without improving UX. For Phase 1 foundation, prefer zero-code solutions (automatic theming) over custom logic.

## Common Pitfalls

### Pitfall 1: Enabling Swift 6 Too Late

**What goes wrong:** Developers start with Swift 5, plan to "add concurrency later", and accumulate hundreds of actor isolation warnings that become overwhelming to fix.

**Why it happens:** Swift 6 strict concurrency requires @MainActor annotations on SwiftUI views and Sendable conformance on models. Retrofitting this into an existing codebase is expensive.

**How to avoid:**
1. Set Swift Language Version to 6.0 in Xcode project settings immediately
2. Enable "Complete" strict concurrency checking (not "Minimal")
3. Fix all warnings before writing business logic
4. Mark all models as `Sendable` from the start

**Warning signs:**
- Compiler warnings about "Main actor-isolated property accessed from different context"
- Thread Sanitizer showing data races
- App works in debug but crashes randomly in release

**Phase 1 verification:** Build project with zero concurrency warnings. If warnings exist, fix before moving to Phase 2.

### Pitfall 2: @Observable Memory Leaks with @State

**What goes wrong:** Using `@State` to store reference types conforming to `@Observable` causes memory leaks on macOS 14. Objects are never deallocated when views are dismissed.

**Why it happens:** @Observable + @State creates retention cycles in macOS 14 (iOS 17 regression). This is documented in PITFALLS.md with HIGH confidence.

**How to avoid for Phase 1:**
- Use `@State` ONLY for value types (Int, String, UUID?, etc.)
- For empty skeleton, `@State private var selectedProjectID: UUID?` is safe (value type)
- Avoid creating ViewModels in Phase 1 (not needed for empty UI)
- If ViewModels are needed later, use `ObservableObject + @StateObject` pattern instead of `@Observable + @State`

**Warning signs:**
- Instruments shows "Leaked allocation" for views
- `deinit` never called on ViewModels
- Memory growth with repeated navigation

**Phase 1 specific test:** Navigate between sidebar items 50+ times, verify memory is stable in Instruments.

### Pitfall 3: Three-Column NavigationSplitView Overengineering

**What goes wrong:** Developers use three-column layout (sidebar → content → detail) when two columns (sidebar → detail) suffice, adding unnecessary complexity.

**Why it happens:** Examples show three columns, developers assume more columns = better. Three columns make sense for Mail.app (mailboxes → message list → message detail), but GSD Monitor has simple navigation (projects → roadmap).

**How to avoid:**
- Use two-column `NavigationSplitView(sidebar:detail:)` for Phase 1
- Three columns would be: projects → phases → phase detail, but app shows roadmap as single view
- Simpler navigation = fewer state management bugs

**Warning signs:**
- Extra state variables for "selected phase in content column"
- Confusion about which column shows what
- Users asking "why do I need to click twice?"

**Phase 1 verification:** Two-column layout should feel natural. If you're managing `selectedContentItem` and `selectedDetailItem`, you've overengineered.

### Pitfall 4: Missing ContentUnavailableView for Empty States

**What goes wrong:** Developers show blank views when no data exists, leaving users confused about whether the app is broken or just empty.

**Why it happens:** Forgetting to handle the empty state case. Views assume data exists.

**How to avoid:**
```swift
// WRONG: Blank screen when projects.isEmpty
List(projects) { project in
    Text(project.name)
}

// CORRECT: Clear empty state
if projects.isEmpty {
    ContentUnavailableView(
        "No Projects Found",
        systemImage: "folder.badge.questionmark",
        description: Text("Scan ~/Developer for GSD projects")
    )
} else {
    List(projects) { project in
        Text(project.name)
    }
}
```

**Warning signs:**
- Blank white/dark rectangles when app launches
- Users reporting "app doesn't work" when they just have no projects
- No visual feedback about why sidebar is empty

**Phase 1 verification:** Launch app with no data, verify both sidebar and detail show ContentUnavailableView with helpful messages.

### Pitfall 5: Codable URL Parsing Failures

**What goes wrong:** Storing URLs in models fails Codable encoding/decoding because URL requires custom implementation.

**Why it happens:** URL is not Codable by default. Developers assume all Foundation types conform.

**How to avoid:**
```swift
// WRONG: URL is not automatically Codable
struct Project: Codable {
    let path: URL // Compile error: URL does not conform to Codable
}

// CORRECT: Custom encoding/decoding for URL
struct Project: Codable {
    let path: URL

    enum CodingKeys: String, CodingKey {
        case path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pathString = try container.decode(String.self, forKey: .path)
        path = URL(fileURLWithPath: pathString)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(path.path, forKey: .path)
    }
}
```

**Warning signs:**
- Compiler error: "Type 'Project' does not conform to protocol 'Decodable'"
- Runtime crash: "No value associated with key CodingKeys.path"

**Phase 1 verification:** Models with URL properties compile and decode from JSON without errors.

## Code Examples

Verified patterns from official sources and 2026 best practices:

### Basic Model Structure

```swift
// Source: Swift Codable best practices 2026, Swift 6 Sendable requirements
import Foundation

struct Project: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let path: URL

    // Optional relationships to other models
    var roadmap: Roadmap?
    var state: State?

    // Custom decoding for URL
    enum CodingKeys: String, CodingKey {
        case id, name, path, roadmap, state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        let pathString = try container.decode(String.self, forKey: .path)
        path = URL(fileURLWithPath: pathString)

        roadmap = try container.decodeIfPresent(Roadmap.self, forKey: .roadmap)
        state = try container.decodeIfPresent(State.self, forKey: .state)
    }
}

struct Roadmap: Codable, Sendable {
    let projectName: String
    let phases: [Phase]
}

struct Phase: Identifiable, Codable, Sendable {
    let id: UUID
    let number: Int
    let name: String
    let goal: String
    let status: String // "not-started", "in-progress", "done"
}
```

### NavigationSplitView Skeleton

```swift
// Source: Apple NavigationSplitView documentation, ContentUnavailableView patterns
import SwiftUI

struct ContentView: View {
    @State private var selectedProjectID: Project.ID?

    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView(
                projects: mockProjects,
                selectedProjectID: $selectedProjectID
            )
        } detail: {
            // Detail
            DetailView(
                selectedProject: mockProjects.first { $0.id == selectedProjectID }
            )
        }
        .navigationSplitViewStyle(.balanced)
    }

    // Phase 1: Empty array to test ContentUnavailableView
    private var mockProjects: [Project] {
        []
    }
}

struct SidebarView: View {
    let projects: [Project]
    @Binding var selectedProjectID: Project.ID?

    var body: some View {
        if projects.isEmpty {
            ContentUnavailableView(
                "No Projects Found",
                systemImage: "folder.badge.questionmark",
                description: Text("Scan ~/Developer to find GSD projects")
            )
        } else {
            List(projects, selection: $selectedProjectID) { project in
                NavigationLink(value: project.id) {
                    Text(project.name)
                }
            }
            .navigationTitle("Projects")
        }
    }
}

struct DetailView: View {
    let selectedProject: Project?

    var body: some View {
        if let project = selectedProject {
            // Phase 1: Empty roadmap view
            Text("Roadmap for \(project.name)")
                .font(.largeTitle)
        } else {
            ContentUnavailableView(
                "Select a Project",
                systemImage: "sidebar.left",
                description: Text("Choose a project from the sidebar to view its roadmap")
            )
        }
    }
}
```

### SwiftUI Preview with Mock Data

```swift
// Source: Xcode Previews best practices, dark/light mode testing
import SwiftUI

#Preview("Light Mode - Empty") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode - Empty") {
    ContentView()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode - With Data") {
    ContentView()
        .preferredColorScheme(.light)
        // TODO Phase 1: Add mock projects when models are complete
}

// Preview data helper
extension Project {
    static let mock = Project(
        id: UUID(),
        name: "gsd-monitor",
        path: URL(fileURLWithPath: "/Users/username/Developer/gsd-monitor"),
        roadmap: Roadmap.mock,
        state: nil
    )
}

extension Roadmap {
    static let mock = Roadmap(
        projectName: "gsd-monitor",
        phases: [
            Phase(
                id: UUID(),
                number: 1,
                name: "Foundation & Models",
                goal: "Establish Swift 6 patterns and create all models",
                status: "in-progress"
            )
        ]
    )
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Swift 5 with minimal concurrency | Swift 6 with strict concurrency by default | Swift 6.0 release (2024) | New projects must handle actor isolation from start. Data race prevention is compile-time, not runtime. |
| ObservableObject + @Published | @Observable macro | iOS 17 / macOS 14 (2023) | Simpler syntax, but has memory leak issues with @State. For Phase 1, avoid complex ViewModels. |
| Custom empty state views | ContentUnavailableView | iOS 17 / macOS 14 (2023) | System-standard empty states. Replaces custom VStack/Image/Text patterns. |
| NavigationView (deprecated) | NavigationSplitView | iOS 16 / macOS 13 (2022) | NavigationView doesn't work properly on macOS. NavigationSplitView is macOS-first design. |
| Manual Codable implementations | Automatic Codable synthesis | Swift 4.0 (2017) | Compiler generates Codable conformance for simple structs automatically. Custom init only needed for URL, Date, complex mappings. |

**Deprecated/outdated:**
- `NavigationView`: Deprecated in favor of NavigationSplitView and NavigationStack. Don't use for new macOS apps.
- `NSUserNotificationCenter`: Deprecated since macOS 10.14. Use UserNotifications framework instead (relevant for Phase 3, not Phase 1).
- Manual JSON parsing with JSONSerialization: Use Codable unless dealing with dynamic/unknown JSON structures.

## Open Questions

1. **Should models include computed properties for derived state?**
   - What we know: Phase model has milestones and requirements
   - What's unclear: Should Phase have `var isComplete: Bool { milestones.allSatisfy(\.isComplete) }`?
   - Recommendation: Add computed properties in Phase 1 models. They're useful for UI logic and don't affect Codable conformance.

2. **How should model relationships be structured?**
   - What we know: Project has Roadmap, Roadmap has Phases, Phases reference Requirements
   - What's unclear: Should Phase have `[Requirement]` or `[String]` (requirement IDs)?
   - Recommendation: Use value types directly (nested Codable structs) for Phase 1. No need for ID references when all data loads from files.

3. **Should we validate model data after Codable decoding?**
   - What we know: Codable can produce valid Swift objects from invalid semantic data (e.g., Phase with negative number)
   - What's unclear: Where to validate? Custom init? Separate validation function?
   - Recommendation: Add `validate()` throws method to models in Phase 1. Call after decoding in Phase 2 file parsing. Better error messages than relying on Codable errors alone.

## Sources

### Primary (HIGH confidence)

- [Adopting strict concurrency in Swift 6 apps - Apple Developer Documentation](https://developer.apple.com/documentation/swift/adoptingswift6) - Swift 6 concurrency patterns
- [NavigationSplitView - Apple Developer Documentation](https://developer.apple.com/documentation/swiftui/navigationsplitview) - NavigationSplitView layout and usage
- [Supporting Dark Mode in your interface - Apple Developer Documentation](https://developer.apple.com/documentation/uikit/supporting-dark-mode-in-your-interface) - Theme support
- [Identifiable - Apple Developer Documentation](https://developer.apple.com/documentation/swift/identifiable) - Model identification
- [Enabling Complete Concurrency Checking - Swift.org](https://www.swift.org/documentation/concurrency/) - Official Swift concurrency guide

### Secondary (MEDIUM confidence)

- [How to Handle JSON Parsing with Codable in Swift - OneUpTime (2026-02-02)](https://oneuptime.com/blog/post/2026-02-02-swift-codable-json/view) - Codable best practices verified 2026
- [Mastering ContentUnavailableView in SwiftUI - Swift with Majid](https://swiftwithmajid.com/2023/10/31/mastering-contentunavailableview-in-swiftui/) - Empty state patterns
- [Approachable Concurrency in Swift 6.2 - Antoine van der Lee](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/) - Swift 6 practical guide 2026
- [Mastering Actor Isolation and Swift 6 Concurrency 2026 - Stackademic (Feb 2026)](https://blog.stackademic.com/mastering-actor-isolation-and-swift-6-concurrency-2026-34e27c208b51) - @MainActor patterns
- [SwiftUI Profiling Guide: Instruments, Time Profiler & Leaks - Medium](https://medium.com/@bhumibhuva18/swiftui-profiling-guide-instruments-time-profiler-leaks-7dd86560ce0e) - Memory leak detection
- [Flattening a nested JSON response into a single struct with Codable - Donny Wals](https://www.donnywals.com/flattening-a-nested-json-response-into-a-single-struct-with-codable/) - Nested Codable patterns
- [How to create a two-column or three-column layout with NavigationSplitView - Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-a-two-column-or-three-column-layout-with-navigationsplitview) - NavigationSplitView layout options
- [Three Column Editors in SwiftUI on macOS - Michael Sena](https://msena.com/posts/three-column-swiftui-macos/) - macOS column layout patterns

## Metadata

**Confidence breakdown:**
- Swift 6 concurrency: HIGH - Official Apple documentation and Swift.org verification
- NavigationSplitView: HIGH - Apple Developer Documentation with macOS examples
- Codable patterns: HIGH - Multiple verified 2026 sources including official Swift guidelines
- Theme support: HIGH - Built-in SwiftUI behavior, verified in Apple docs
- Memory profiling: MEDIUM - Community best practices, Instruments usage is standard but specific leak scenarios require testing

**Research date:** 2026-02-13
**Valid until:** 2026-08-13 (6 months - Swift/SwiftUI stable, but Swift 6.x updates may add features)

**Phase 1 readiness:** Research complete. Planner can create PLAN.md with concrete tasks:
1. Create Xcode project with Swift 6 strict concurrency enabled
2. Define all models (Project, Roadmap, Phase, State, Requirement, Plan) with Codable + Sendable
3. Build NavigationSplitView skeleton with ContentUnavailableView empty states
4. Verify dark/light mode switching works automatically
5. Test navigation with Instruments Leaks template for memory safety
