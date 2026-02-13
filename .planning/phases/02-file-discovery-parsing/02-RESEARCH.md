# Phase 2: File Discovery & Parsing - Research

**Researched:** 2026-02-13
**Domain:** macOS file system scanning, markdown parsing, security-scoped bookmarks
**Confidence:** HIGH

## Summary

Phase 2 requires scanning directories for `.planning/` folders, parsing markdown/JSON files into Swift models, and persisting file access with security-scoped bookmarks. The standard stack is Swift Markdown (official parser), FileManager DirectoryEnumerator (recursive scanning), and URL bookmarks API (persistent access). Key challenges are scan performance with deep hierarchies, symlink safety, and bookmark staleness monitoring.

Swift 6 concurrency enables background scanning without blocking the UI. Security-scoped bookmarks persist access across launches without re-prompting users. Markdown parsing should use MarkupWalker visitor pattern to extract structured data from heading hierarchies.

**Primary recommendation:** Use FileManager.enumerator with `.skipsHiddenFiles` and `.skipsPackageDescendants`, parse with swift-markdown's MarkupWalker, and store bookmarks in UserDefaults with staleness monitoring.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Scan ~/Developer recursively as default scan path
- Configurable scan list — user can add additional root directories to auto-scan (e.g., ~/Projects, ~/Work)
- Scan triggers only at app launch (no periodic or live rescanning in this phase)
- App starts with sidebar overview, does NOT restore last selected project
- File picker (standard macOS Open dialog) for adding projects outside scan paths
- Right-click context menu → "Remove" for removing manually added projects from sidebar
- No drag & drop — file picker only
- Projects show name + small progress bar in sidebar
- Projects grouped by scan source (e.g., "~/Developer", "Manually Added")

### Claude's Discretion
- Scan depth for recursive scanning (balance thoroughness vs performance)
- Symlink handling (safety-first approach)
- Handling of disappeared projects (removed from disk)
- Minimum file requirement for displaying a project
- Behavior when user adds a folder without .planning/
- Parsing depth for PLAN.md, REQUIREMENTS.md, and config.json
- Error handling for corrupt/unexpected markdown format
- Sorting order within sidebar groups
- node_modules/.git exclusion during scanning

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| swift-markdown | Latest (GitHub main) | Parse markdown files | Official Swift package, maintained by Swift team, thread-safe value types |
| FileManager (Foundation) | Built-in | Recursive directory scanning | Native macOS API, no dependencies, performant DirectoryEnumerator |
| JSONDecoder (Foundation) | Built-in | Parse config.json | Native Swift, built-in snake_case conversion |
| URL Bookmarks API | Built-in macOS | Persist file access | Only way to maintain access across launches without re-prompting |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| UserDefaults | Built-in | Store bookmark data | Simple persistence, adequate for bookmark Data blobs |
| NSOpenPanel | Built-in AppKit | Manual file picker | Only way to get security-scoped URLs for user-selected folders |
| Task (Swift Concurrency) | Swift 6 | Background scanning | Prevent UI blocking during deep scans |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| swift-markdown | Ink (John Sundell) | Ink is faster but less feature-complete. Swift-markdown is official and better documented |
| FileManager | FileKit wrapper | Unnecessary abstraction. FileManager API is already clean |
| UserDefaults | Keychain | Overkill for non-sensitive bookmark data. UserDefaults is simpler |

**Installation:**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.3.0")
]
```

## Architecture Patterns

### Recommended Project Structure
```
GSDMonitor/
├── Services/
│   ├── ProjectDiscoveryService.swift    # Scans directories for .planning/
│   ├── MarkdownParserService.swift      # Parses ROADMAP/STATE/REQUIREMENTS
│   ├── PlanParserService.swift          # Parses PLAN.md files
│   ├── BookmarkService.swift            # Manages security-scoped bookmarks
│   └── ProjectService.swift             # Coordinates discovery + parsing
└── Models/
    └── (existing from Phase 1)
```

### Pattern 1: DirectoryEnumerator with Options
**What:** Use `enumerator(at:includingPropertiesForKeys:options:errorHandler:)` with filtering options
**When to use:** Always, for performance and safety
**Example:**
```swift
// Source: https://developer.apple.com/documentation/foundation/filemanager/2765464-enumerator
let enumerator = FileManager.default.enumerator(
    at: rootURL,
    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
    options: [.skipsHiddenFiles, .skipsPackageDescendants]
) { url, error in
    // Log error but continue enumeration
    print("Error accessing \(url): \(error)")
    return true
}

for case let fileURL as URL in enumerator {
    if fileURL.lastPathComponent == ".planning" {
        // Found a GSD project
    }
}
```

### Pattern 2: Security-Scoped Bookmark Lifecycle
**What:** Create, persist, resolve, and monitor bookmark staleness
**When to use:** For all user-selected folders and discovered projects
**Example:**
```swift
// Source: https://www.avanderlee.com/swift/security-scoped-bookmarks-for-url-access/

// 1. Create bookmark after user selection
let bookmarkData = try url.bookmarkData(
    options: .withSecurityScope,
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)
UserDefaults.standard.set(bookmarkData, forKey: "project_\(projectID)")

// 2. Resolve on app restart
var isStale = false
let url = try URL(
    resolvingBookmarkData: storedBookmarkData,
    options: .withSecurityScope,
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)

if isStale {
    // Refresh bookmark immediately
    let newBookmarkData = try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
    )
    UserDefaults.standard.set(newBookmarkData, forKey: "project_\(projectID)")
}

// 3. Access scoped resource
guard url.startAccessingSecurityScopedResource() else {
    throw AccessError.denied
}
defer { url.stopAccessingSecurityScopedResource() }

// ... read files within scope ...
```

### Pattern 3: MarkupWalker for Structured Extraction
**What:** Walk markdown AST to extract headers, lists, and sections
**When to use:** Parsing ROADMAP.md, STATE.md, REQUIREMENTS.md
**Example:**
```swift
// Source: https://swiftinit.org/docs/swift-markdown/markdown/markupvisitor
import Markdown

class RoadmapWalker: MarkupWalker {
    var phases: [Phase] = []
    var currentPhase: Phase?

    override func visitHeading(_ heading: Heading) -> () {
        let text = heading.plainText

        // H2 headers are phase names
        if heading.level == 2 {
            if text.starts(with: "Phase") {
                // Parse "Phase 1: Foundation" -> number=1, name="Foundation"
                currentPhase = extractPhase(from: text)
            }
        }

        // H3 headers are phase metadata
        if heading.level == 3, let phase = currentPhase {
            if text == "Goal" {
                // Next paragraph is the goal text
            } else if text == "Success Criteria" {
                // Next list is success criteria items
            }
        }

        descendInto(heading)
    }

    override func visitListItem(_ listItem: ListItem) -> () {
        if let phase = currentPhase {
            // Extract bullet points for requirements, dependencies, etc.
            phase.requirements.append(listItem.plainText)
        }
        descendInto(listItem)
    }
}

// Usage
let document = Document(parsing: markdownString)
let walker = RoadmapWalker()
walker.visit(document)
let phases = walker.phases
```

### Pattern 4: Async Background Scanning
**What:** Use Task.detached for directory scanning to avoid blocking UI
**When to use:** App launch scanning, manual scan trigger
**Example:**
```swift
// Source: https://forums.swift.org/t/do-async-operations-always-run-on-a-background-thread/80484
@MainActor
class ProjectDiscoveryService {
    @Published var discoveredProjects: [Project] = []

    func scanDirectories(_ rootPaths: [URL]) async {
        // Detached task runs on background thread pool
        let projects = await Task.detached {
            var found: [Project] = []

            for rootPath in rootPaths {
                let enumerator = FileManager.default.enumerator(
                    at: rootPath,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )

                for case let url as URL in enumerator ?? [] {
                    if url.lastPathComponent == ".planning" {
                        let project = try? self.loadProject(at: url)
                        if let project { found.append(project) }
                    }
                }
            }

            return found
        }.value

        // Update on main thread
        self.discoveredProjects = projects
    }
}
```

### Pattern 5: JSONDecoder with Snake Case
**What:** Use `.convertFromSnakeCase` for config.json parsing
**When to use:** Parsing config.json with workflow_version, auto_commit keys
**Example:**
```swift
// Source: https://developer.apple.com/documentation/foundation/jsondecoder/keydecodingstrategy-swift.enum/convertfromsnakecase
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

struct PlanningConfig: Codable {
    let workflowVersion: String?  // Maps from "workflow_version"
    let autoCommit: Bool?          // Maps from "auto_commit"
}

let config = try decoder.decode(PlanningConfig.self, from: jsonData)
```

### Anti-Patterns to Avoid
- **Blocking main thread with deep scans:** FileManager enumeration can take seconds on large directories. Always use async/await.
- **Ignoring bookmark staleness:** If `bookmarkDataIsStale` returns true and you don't refresh, you'll lose access permanently and need to re-prompt user.
- **Manual URL path construction:** Use FileManager and URL methods, not string concatenation. Handles special characters correctly.
- **Storing full file contents in memory:** Parse markdown files on-demand, don't cache entire file contents for all projects.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown parsing | Custom regex parser | swift-markdown | Handles edge cases: nested lists, code blocks, inline formatting, escaped characters, invalid syntax |
| Recursive scanning | Custom directory walker | FileManager.DirectoryEnumerator | Handles symlinks, permissions, hidden files, packages correctly. Optimized by Apple |
| File access persistence | Custom permission system | Security-scoped bookmarks | Only Apple-approved way to maintain access. Custom solutions will fail with sandboxing |
| JSON snake_case conversion | Manual CodingKey mappings | JSONDecoder.keyDecodingStrategy | Handles nested objects, arrays, optional fields automatically |

**Key insight:** File system operations have countless edge cases (permissions, symlinks, hidden files, package bundles, special characters). Use Foundation APIs that handle these, don't reinvent them.

## Common Pitfalls

### Pitfall 1: Symlink Infinite Loops
**What goes wrong:** Following symlinks can create infinite loops if a symlink points to a parent directory.
**Why it happens:** Default FileManager behavior resolves symlinks, which can cause circular references.
**How to avoid:** Check `.isSymbolicLinkKey` resource value and either skip symlinks entirely or track visited paths.
**Warning signs:** Scan never completes, memory usage grows unbounded.
```swift
// Solution: Skip symlinks entirely (safest)
let resourceValues = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
if resourceValues.isSymbolicLink == true {
    enumerator.skipDescendants()
}
```

### Pitfall 2: Bookmark Staleness Ignored
**What goes wrong:** App loses file access after system restart or file moves, requires user to re-select folders.
**Why it happens:** Bookmark data becomes stale when files move or permissions change, must be refreshed.
**How to avoid:** Always check `bookmarkDataIsStale` flag and refresh immediately if true.
**Warning signs:** App works once, then fails on next launch with permission errors.
```swift
// WRONG: Ignoring staleness
let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope)

// RIGHT: Check and refresh
var isStale = false
let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
if isStale {
    let fresh = try url.bookmarkData(options: .withSecurityScope)
    UserDefaults.standard.set(fresh, forKey: key)
}
```

### Pitfall 3: Forgetting startAccessingSecurityScopedResource
**What goes wrong:** File access denied error even with valid bookmark.
**Why it happens:** Security-scoped URLs require explicit start/stop access calls.
**How to avoid:** Always call `startAccessingSecurityScopedResource()` before reading files, `stopAccessingSecurityScopedResource()` after.
**Warning signs:** "Operation not permitted" errors when reading project files.
```swift
// CRITICAL: Must call before accessing files
guard url.startAccessingSecurityScopedResource() else {
    throw AccessError.denied
}
defer { url.stopAccessingSecurityScopedResource() }

// Now safe to read files within url hierarchy
let contents = try String(contentsOf: url.appendingPathComponent("ROADMAP.md"))
```

### Pitfall 4: Deep Scan Performance
**What goes wrong:** Scanning ~/Developer with many projects takes 5-10 seconds, UI freezes.
**Why it happens:** Large directories with deep nesting (node_modules, .git, build folders) cause excessive filesystem operations.
**How to avoid:** Use `.skipsHiddenFiles` and `.skipsPackageDescendants` options, implement depth limit, use async scanning.
**Warning signs:** App hangs on launch, Instruments shows FileManager dominating CPU.
```swift
// Solution: Options + depth limit
let enumerator = FileManager.default.enumerator(
    at: rootURL,
    includingPropertiesForKeys: [.isDirectoryKey],
    options: [.skipsHiddenFiles, .skipsPackageDescendants]
)

for case let url as URL in enumerator ?? [] {
    // Skip known problem directories
    let lastComponent = url.lastPathComponent
    if lastComponent == "node_modules" || lastComponent == ".git" || lastComponent == "build" {
        enumerator.skipDescendants()
        continue
    }

    // Depth limit (optional, for safety)
    if enumerator.level > 5 {
        enumerator.skipDescendants()
    }
}
```

### Pitfall 5: Markdown Parsing Assumptions
**What goes wrong:** Parser crashes or returns wrong data when markdown doesn't match expected format.
**Why it happens:** Real GSD projects may have formatting variations, missing sections, or unexpected content.
**How to avoid:** Use defensive parsing with optional values, validate structure before extracting data.
**Warning signs:** Parse failures on valid markdown files, incorrect phase numbers, missing requirements.
```swift
// WRONG: Assumes exact structure
let phaseNumber = Int(heading.plainText.split(separator: " ")[1])!

// RIGHT: Defensive parsing
guard let phaseMatch = heading.plainText.firstMatch(of: /Phase (\d+):/) else {
    return nil  // Not a phase header
}
let phaseNumber = Int(phaseMatch.1) ?? 0
```

### Pitfall 6: NSOpenPanel on Background Thread
**What goes wrong:** App crashes with "AppKit must be called from main thread" error.
**Why it happens:** NSOpenPanel is AppKit UI, must run on main thread.
**How to avoid:** Always wrap NSOpenPanel in `@MainActor` function or call from main thread.
**Warning signs:** Random crashes when user clicks "Add Project" button.
```swift
// RIGHT: Main actor ensures main thread
@MainActor
func selectFolder() async -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false

    let response = await panel.beginSheetModal(for: window)
    return response == .OK ? panel.url : nil
}
```

## Code Examples

Verified patterns from official sources:

### Scanning for .planning Directories
```swift
// Source: https://developer.apple.com/documentation/foundation/filemanager/2765464-enumerator
func scanForProjects(at rootURL: URL) async throws -> [URL] {
    var projectURLs: [URL] = []

    let enumerator = FileManager.default.enumerator(
        at: rootURL,
        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
    ) { url, error in
        print("⚠️ Error accessing \(url.path): \(error.localizedDescription)")
        return true  // Continue enumeration despite errors
    }

    for case let url as URL in enumerator ?? [] {
        // Skip symlinks (safety)
        let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values?.isSymbolicLink == true {
            enumerator.skipDescendants()
            continue
        }

        // Skip known problematic directories
        let name = url.lastPathComponent
        if name == "node_modules" || name == ".git" || name == "build" {
            enumerator.skipDescendants()
            continue
        }

        // Found .planning directory
        if name == ".planning" {
            projectURLs.append(url.deletingLastPathComponent())
            enumerator.skipDescendants()  // Don't scan inside .planning/
        }
    }

    return projectURLs
}
```

### Creating and Resolving Bookmarks
```swift
// Source: https://www.avanderlee.com/swift/security-scoped-bookmarks-for-url-access/
class BookmarkService {
    private let defaults = UserDefaults.standard

    func saveBookmark(for projectURL: URL, projectID: UUID) throws {
        let bookmarkData = try projectURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(bookmarkData, forKey: "bookmark_\(projectID.uuidString)")
    }

    func resolveBookmark(for projectID: UUID) throws -> URL? {
        guard let data = defaults.data(forKey: "bookmark_\(projectID.uuidString)") else {
            return nil
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            // Refresh stale bookmark
            let freshData = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(freshData, forKey: "bookmark_\(projectID.uuidString)")
        }

        return url
    }

    func accessProject<T>(_ projectURL: URL, _ operation: () throws -> T) throws -> T {
        guard projectURL.startAccessingSecurityScopedResource() else {
            throw BookmarkError.accessDenied
        }
        defer { projectURL.stopAccessingSecurityScopedResource() }

        return try operation()
    }
}
```

### Parsing ROADMAP.md with MarkupWalker
```swift
// Source: https://swiftinit.org/docs/swift-markdown/markdown/markupvisitor
import Markdown

class RoadmapParser {
    func parse(_ markdownURL: URL) throws -> Roadmap {
        let content = try String(contentsOf: markdownURL)
        let document = Document(parsing: content)

        let walker = RoadmapWalker()
        walker.visit(document)

        return Roadmap(
            projectName: walker.projectName ?? "Unknown",
            phases: walker.phases
        )
    }
}

class RoadmapWalker: MarkupWalker {
    var projectName: String?
    var phases: [Phase] = []

    private var currentPhase: PhaseBuilder?
    private var parsingContext: ParsingContext = .none

    enum ParsingContext {
        case none, goal, dependencies, requirements, successCriteria
    }

    override func visitHeading(_ heading: Heading) -> () {
        let text = heading.plainText

        // H1: Project name
        if heading.level == 1, text.starts(with: "Roadmap:") {
            projectName = text.replacingOccurrences(of: "Roadmap: ", with: "")
        }

        // H2: Phase headers
        if heading.level == 2 {
            // Save previous phase
            if let phase = currentPhase?.build() {
                phases.append(phase)
            }

            // Parse "Phase 2: File Discovery & Parsing"
            if let match = text.firstMatch(of: /Phase (\d+): (.+)/) {
                currentPhase = PhaseBuilder(
                    number: Int(match.1) ?? 0,
                    name: String(match.2)
                )
            }
        }

        // H3: Phase metadata sections
        if heading.level == 3, currentPhase != nil {
            switch text {
            case "Goal": parsingContext = .goal
            case "Depends on": parsingContext = .dependencies
            case "Requirements": parsingContext = .requirements
            case "Success Criteria": parsingContext = .successCriteria
            default: parsingContext = .none
            }
        }

        descendInto(heading)
    }

    override func visitParagraph(_ paragraph: Paragraph) -> () {
        if parsingContext == .goal {
            currentPhase?.goal = paragraph.plainText
        }
        descendInto(paragraph)
    }

    override func visitListItem(_ listItem: ListItem) -> () {
        guard let phase = currentPhase else { return }

        switch parsingContext {
        case .dependencies:
            phase.dependencies.append(listItem.plainText)
        case .requirements:
            // Extract "NAV-01, NAV-02" format
            let reqIDs = listItem.plainText.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            phase.requirements.append(contentsOf: reqIDs)
        case .successCriteria:
            phase.successCriteria.append(listItem.plainText)
        default:
            break
        }

        descendInto(listItem)
    }
}

class PhaseBuilder {
    let number: Int
    let name: String
    var goal: String = ""
    var dependencies: [String] = []
    var requirements: [String] = []
    var successCriteria: [String] = []

    init(number: Int, name: String) {
        self.number = number
        self.name = name
    }

    func build() -> Phase {
        Phase(
            id: UUID(),
            number: number,
            name: name,
            goal: goal,
            dependencies: dependencies,
            requirements: requirements,
            milestones: successCriteria,
            status: .notStarted
        )
    }
}
```

### Parsing config.json
```swift
// Source: https://developer.apple.com/documentation/foundation/jsondecoder/keydecodingstrategy-swift.enum/convertfromsnakecase
func parseConfig(at url: URL) throws -> PlanningConfig {
    let data = try Data(contentsOf: url)

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    return try decoder.decode(PlanningConfig.self, from: data)
}

// PlanningConfig model already defined in Phase 1:
// struct PlanningConfig: Codable, Sendable {
//     let workflowVersion: String?  // from "workflow_version"
//     let autoCommit: Bool?          // from "auto_commit"
// }
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual CodingKeys for snake_case | JSONDecoder.keyDecodingStrategy | Swift 4.1 (2018) | Eliminates boilerplate for every JSON model |
| Closure-based FileManager.enumerateDirectory | DirectoryEnumerator with options | macOS 10.6+ | More control, better error handling, performance options |
| NSRegularExpression for markdown | swift-markdown AST parsing | 2021 (swift-markdown release) | Type-safe, handles edge cases, official support |
| Manual bookmark refresh logic | bookmarkDataIsStale flag | macOS 10.6+ | System tells you when refresh needed, prevents guessing |
| SwiftUI .fileImporter | NSOpenPanel with .withSecurityScope | Current (2026) | .fileImporter doesn't give bookmark-compatible URLs on macOS |

**Deprecated/outdated:**
- `.fileImporter` for directory selection: Works on iOS, but macOS version doesn't provide security-scoped bookmarks. Use NSOpenPanel.
- `enumerator(atPath:)`: String-based API is error-prone. Use `enumerator(at:)` with URL.
- Manual Task creation for background work: Swift 6 concurrency with `async let` is cleaner than Task.detached for parallel operations.

## Open Questions

1. **Scan depth limit recommendation**
   - What we know: Deep scans (10+ levels) can take seconds. Most GSD projects are 2-3 levels deep.
   - What's unclear: What depth limit balances thoroughness vs performance for typical ~/Developer?
   - Recommendation: Start with no depth limit but skipDescendants() on node_modules/.git/build. Monitor performance in Phase 2 testing.

2. **Disappeared project behavior**
   - What we know: User may delete project folder while app is running or between sessions.
   - What's unclear: Should we keep ghost entry in sidebar? Auto-remove? Show warning?
   - Recommendation: Auto-remove from sidebar on next launch, log warning. User can re-add if folder returns.

3. **Minimum file requirement**
   - What we know: Some GSD projects may have incomplete .planning/ (missing ROADMAP.md, etc).
   - What's unclear: Require ROADMAP.md only? Or show project even with just .planning/ folder?
   - Recommendation: Require .planning/ROADMAP.md at minimum. Show parse errors for other missing files but still list project.

4. **User adds folder without .planning/**
   - What we know: User can manually select any folder via file picker.
   - What's unclear: Show error immediately? Add anyway and show "Not a GSD project" state?
   - Recommendation: Validate on selection, show alert "No .planning/ folder found. Select a GSD project root." Don't add to sidebar.

## Sources

### Primary (HIGH confidence)
- [FileManager | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/filemanager) - Official API reference
- [swift-markdown GitHub](https://github.com/swiftlang/swift-markdown) - Official parser, usage patterns
- [Security-scoped bookmarks - SwiftLee](https://www.avanderlee.com/swift/security-scoped-bookmarks-for-url-access/) - Verified bookmark lifecycle
- [JSONDecoder.KeyDecodingStrategy | Apple](https://developer.apple.com/documentation/foundation/jsondecoder/keydecodingstrategy-swift.enum/convertfromsnakecase) - Official snake_case docs
- [Accessing files from macOS App Sandbox | Apple](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox) - Sandbox entitlements

### Secondary (MEDIUM confidence)
- [How to Persist File Access on macOS - Delasign](https://www.delasign.com/blog/how-to-persist-file-access-on-macos-using-swift-and-scoped-url-bookmarks/) - Practical examples
- [MarkupVisitor - swift-markdown docs](https://swiftinit.org/docs/swift-markdown/markdown/markupvisitor) - Visitor pattern details
- [Swift async/await concurrency 2026](https://forums.swift.org/t/questions-about-swift-6-concurrency/82045) - Swift 6 patterns
- [SwiftUI Open and Save Panels](https://www.swiftdevjournal.com/swiftui-open-and-save-panels/) - NSOpenPanel in SwiftUI
- [FileManager DirectoryEnumerator](https://developer.apple.com/documentation/foundation/filemanager/directoryenumerator) - Enumeration options

### Tertiary (LOW confidence)
- [A review of Markdown parsers for Swift - Loopwerk](https://www.loopwerk.io/articles/2021/review-markdown-parsers/) - Library comparison (2021, may be dated)
- [FileManager enumeration problems - Swift Forums](https://forums.swift.org/t/filemanager-enumeration-problems/31682) - Community troubleshooting

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All built-in Foundation/AppKit APIs with official Apple documentation
- Architecture: HIGH - Verified patterns from swift-markdown examples and Apple developer docs
- Pitfalls: HIGH - Documented in Apple forums, SwiftLee articles, and official warnings

**Research date:** 2026-02-13
**Valid until:** 90 days (stable domain - file system APIs rarely change)
