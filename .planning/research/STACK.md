# Stack Research — GSD Command Runner (v1.2)

**Domain:** Process execution, PTY, ANSI output rendering, command palette — embedded in SwiftUI macOS app
**Researched:** 2026-02-17
**Confidence:** HIGH (process/async), MEDIUM (PTY/ANSI rendering approach)

**Context:** This is an ADDITIVE stack document. It covers ONLY what is new for v1.2. The base stack (Swift 6 / SwiftUI / FSEvents / swift-markdown / Gruvbox / macOS 14+ / UserNotifications / security-scoped bookmarks / NavigationSplitView) is validated and unchanged.

**Critical pre-existing project fact:** `com.apple.security.app-sandbox = false` in GSDMonitor.entitlements. The app is already non-sandboxed. Process spawning works without restriction.

---

## New Capabilities Required for v1.2

| Capability | What's Needed |
|------------|---------------|
| Process spawning | Launch `claude` CLI with GSD slash commands |
| PTY allocation | Make `claude` think it's in a terminal (enables ANSI output) |
| Live output streaming | Stream stdout/stderr to SwiftUI as lines arrive |
| ANSI color parsing | Convert escape sequences to colored text in SwiftUI |
| Environment setup | Pass correct PATH, env vars to child process |
| Command palette extension | Add GSD command items to existing `CommandPaletteView` |
| Output view | Scrollable, live-updating output panel in SwiftUI |

---

## Recommended Stack — New Additions Only

### Core: Process Execution

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Foundation.Process** | Built-in (macOS 14+) | Spawn `claude` CLI | Native, no dependencies. Already part of the project's runtime. PTY attachment works via `openpty`. Do NOT use `swift-subprocess` — requires Swift 6.1 minimum and doesn't add PTY support. |
| **Foundation.Pipe** | Built-in (macOS 14+) | Capture stdout/stderr | Standard paired-with-Process approach. Used to bridge to FileHandle for async reading. |
| **Darwin.openpty** | Built-in (Darwin/POSIX) | Allocate pseudo-terminal | Enables `claude` to detect it's running in a terminal and emit ANSI color codes. Without PTY, claude outputs plain text without colors. `forkpty` is unsafe from Swift — use `openpty` + manual fd attachment instead. |

**PTY pattern (verified from community):**

```swift
import Darwin

var master: Int32 = 0
var slave: Int32 = 0
Darwin.openpty(&master, &slave, nil, nil, nil)

let process = Process()
// Attach slave fd to process stdin/stdout/stderr
process.standardInput = FileHandle(fileDescriptor: slave)
process.standardOutput = FileHandle(fileDescriptor: slave)
process.standardError = FileHandle(fileDescriptor: slave)

// Read from master fd (parent side)
let masterHandle = FileHandle(fileDescriptor: master)
// ... stream masterHandle.availableData in a Task loop
```

**WARNING — `forkpty` is unsafe from Swift.** Apple engineer Quinn confirmed this. `forkpty` does `fork()` without `exec()`, which is unsafe in Swift's runtime. Use `openpty` + `posix_spawn` (which `Process.launch()` uses internally).

### Core: Async Output Streaming

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **AsyncStream<String>** | Built-in Swift 5.9+ | Bridge FileHandle callbacks to SwiftUI | Clean async/await bridge from `readabilityHandler` callbacks to `@Observable` state. Standard pattern for streaming Process output in Swift 6. |
| **Actor (custom)** | Built-in Swift 6 | Thread-safe output accumulation | Swift 6 strict concurrency: `readabilityHandler` closure is `Sendable`. Direct mutation of `@Observable` state from it causes data races. Solution: dedicated actor with `appendLine()` method, called via `Task { await actor.appendLine(...) }` inside handler. |

**Streaming pattern (Swift 6 safe):**

```swift
actor OutputBuffer {
    private(set) var lines: [AttributedString] = []

    func appendLine(_ line: AttributedString) {
        lines.append(line)
    }
}

// In Process setup:
let pipe = Pipe()
process.standardOutput = pipe
pipe.fileHandleForReading.readabilityHandler = { handle in
    let data = handle.availableData
    guard !data.isEmpty else { return }
    if let text = String(data: data, encoding: .utf8) {
        let attributed = ANSIParser.parse(text)
        Task {
            await outputBuffer.appendLine(attributed)
        }
    }
}
```

**Why NOT `FileHandle.readabilityHandler` alone without actor:** Swift 6 strict concurrency treats the closure as `Sendable`. Capturing `@Observable` model properties directly causes compile errors. The actor wrapper is the correct fix, verified from Swift Forums thread on this exact issue.

### ANSI Color Parsing

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Custom ANSI parser (built-in)** | N/A | Parse ANSI → AttributedString | The GSD runner is NOT a full terminal emulator. It only needs to handle basic ANSI SGR sequences (colors, bold, reset). A custom regex-based parser is ~50 lines, zero dependencies, and maps perfectly to Gruvbox theme colors. Third-party ANSI libs are over-engineered for this scope. |
| **Swift Regex (`#/\e\[(\d+(?:;\d+)*)m/#`)** | Swift 5.7+ (macOS 14+) | Match ANSI escape sequences | New Swift Regex literal syntax (iOS 16+, macOS 13+, stable on macOS 14+). Fast, readable, works in Swift 6 strict concurrency. |
| **AttributedString** | Swift 5.5+ / macOS 12+ | Carry color/style attributes | Native Swift type for styled text. SwiftUI `Text` view accepts `AttributedString` directly — no NSAttributedString bridging needed. |

**ANSI → AttributedString conversion pattern:**

```swift
// Regex matches: ESC [ 31 m, ESC [ 0 m, ESC [ 1;32 m etc.
let ansiPattern = #/\e\[(\d+(?:;\d+)*)m/#

func parse(_ raw: String) -> AttributedString {
    var result = AttributedString()
    var currentForeground: Color = .gruvboxFg0
    var isBold = false

    // Split on ANSI codes, process each segment
    // Map SGR codes to Gruvbox colors:
    // 31 → gruvboxRed, 32 → gruvboxGreen, 33 → gruvboxYellow,
    // 34 → gruvboxBlue, 35 → gruvboxPurple, 36 → gruvboxAqua,
    // 0 → reset to fg0, 1 → bold
    // ...
    return result
}
```

**Why NOT SwiftTerm for this use case:**
- SwiftTerm is a full VT100/XTerm terminal emulator (6,900+ lines). Massive scope mismatch — GSD runner only needs basic SGR color codes, not cursor positioning, alternate screen buffers, mouse events, sixel graphics.
- SwiftTerm is AppKit (`NSView`). Bridging via `NSViewRepresentable` adds indirection and fights with SwiftUI layout system.
- SwiftTerm requires you to disable sandbox (already done) but also restricts input to its own TTY — doesn't fit a "output panel" UX.
- Latest v1.10.1 (Feb 3, 2026) has no Swift 6 concurrency annotations — will produce warnings in Swift 6 strict mode.

**Why NOT third-party ANSI packages (ANSIEscapeCode, swift-ansi-style):**
- Both are output-generation libraries (add ANSI codes to strings), not parsers.
- Neither produces `AttributedString` from raw ANSI input.

### Output Rendering in SwiftUI

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **SwiftUI Text (AttributedString)** | macOS 12+ | Render ANSI-colored output lines | Native SwiftUI. Accepts `AttributedString` directly. Renders foreground color, bold, italic. Zero bridging. Performant for hundreds of lines. |
| **ScrollView + LazyVStack** | Built-in SwiftUI | Live-scrolling output panel | `LazyVStack` only renders visible rows — critical for long-running commands that produce thousands of lines. Pair with `.scrollPosition(id:)` (macOS 14+) to auto-scroll to bottom. |
| **scrollPosition(id:)** | macOS 14+ | Auto-scroll to latest output | Introduced iOS 17 / macOS 14. Attach `.id()` to last line and use `scrollPosition` binding to stay at bottom during streaming. |

**Output panel pattern:**

```swift
struct CommandOutputView: View {
    let lines: [AttributedString]
    @State private var scrollTarget: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(lines.indices, id: \.self) { i in
                        Text(lines[i])
                            .font(.system(.body, design: .monospaced))
                            .id(i)
                    }
                }
                .padding(8)
            }
            .onChange(of: lines.count) { _, _ in
                proxy.scrollTo(lines.count - 1, anchor: .bottom)
            }
        }
        .background(Color.gruvboxBg0)
    }
}
```

**Why NOT NSTextView for output:** NSTextView with `NSViewRepresentable` is the "full rich text editor" approach. For append-only terminal output, `LazyVStack` + `Text(AttributedString)` is simpler, more SwiftUI-idiomatic, and avoids AppKit bridging complexity.

### Environment Setup for `claude` CLI

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Process.environment** | Built-in | Pass PATH and env to child | GUI apps launched via Spotlight/Finder inherit launchd's PATH, not shell PATH. Homebrew tools (`claude` installed via npm/brew) are at `/opt/homebrew/bin` or `~/.local/bin`. Must be explicitly set. |

**Environment construction pattern:**

```swift
var env = ProcessInfo.processInfo.environment
// Augment with common tool paths:
let extraPaths = [
    "/opt/homebrew/bin",       // Homebrew (Apple Silicon)
    "/usr/local/bin",          // Homebrew (Intel) / nvm
    "/usr/bin",
    "/bin",
    (env["HOME"] ?? "") + "/.local/bin",  // npm global installs
    (env["HOME"] ?? "") + "/.bun/bin",    // bun installs
]
let existingPath = env["PATH"] ?? ""
env["PATH"] = (extraPaths + [existingPath])
    .filter { !$0.isEmpty }
    .joined(separator: ":")

process.environment = env
```

**Why this matters:** The `claude` CLI is installed globally via npm, Homebrew, or bun. Without augmenting PATH, `Process` will fail to find it even though it's on the user's shell PATH. This is the #1 "why doesn't it work" issue for macOS app-to-CLI integration.

### Command Palette Extension

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Existing CommandPaletteView** | Project v1.1 | Already has search/select UI | Extend CommandResult enum to add `.gsdCommand(GSDCommand)` case. Existing infrastructure (FocusState, dismiss, List) is reused. No new UI framework needed. |
| **Keyboard shortcut (⌘K)** | SwiftUI `.keyboardShortcut` | Invoke command palette | Standard pattern for command palettes (VS Code, Linear, etc.). Already likely wired — verify and extend. |

**GSDCommand model addition:**

```swift
struct GSDCommand: Identifiable, Hashable {
    let id: String         // e.g. "gsd:quick"
    let displayName: String // e.g. "Quick Fix"
    let description: String
    let requiresProject: Bool
}

// Extend existing enum:
enum CommandResult: Identifiable, Hashable {
    // ...existing cases...
    case gsdCommand(GSDCommand, projectID: UUID?)
}
```

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **SwiftTerm** | Full VT100 emulator — massive scope mismatch. AppKit NSView bridging fights SwiftUI layout. No Swift 6 annotations. | Custom ANSI parser + LazyVStack + AttributedString |
| **swift-subprocess** | Requires Swift 6.1 (project targets Swift 6.0 strict). No PTY support. Doesn't add value over Foundation.Process for this use case. | Foundation.Process + Pipe + AsyncStream |
| **forkpty** | Unsafe from Swift runtime (fork without exec). Apple explicitly warns against this. | Darwin.openpty + Process.launch() |
| **ANSIEscapeCode / swift-ansi-style** | Output-generation libs, not parsers. Wrong direction. | Custom regex ANSI parser → AttributedString |
| **NSTextView for output panel** | AppKit bridging overkill for append-only output. Complex coordinator pattern. | LazyVStack + Text(AttributedString) |
| **Sandboxing removal** | Already disabled. Do NOT re-enable. | Keep `com.apple.security.app-sandbox = false` |
| **Third-party command palette** | Existing CommandPaletteView is sufficient — extend it | Extend existing CommandResult enum |
| **DispatchQueue for Process I/O** | Swift 6 strict concurrency makes DispatchQueue + mutation error-prone. | Actor + AsyncStream pattern |

---

## Installation — New Dependencies

**Zero new SPM packages required.**

All new capabilities use:
- `Foundation.Process` — already available
- `Darwin.openpty` — available via `import Darwin`
- `AsyncStream` — Swift standard library
- `AttributedString` — Swift standard library
- `Swift Regex` — Swift 5.7+ standard library
- `ScrollViewReader`, `LazyVStack`, `scrollPosition` — SwiftUI built-in (macOS 14+)

**Xcode project changes:**
- No new SPM dependencies
- No new entitlements (already non-sandboxed)
- No new capabilities

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| Foundation.Process + openpty | swift-subprocess | Requires Swift 6.1. No PTY. In-development. Overkill for known CLI invocation. |
| Foundation.Process + openpty | SwiftTerm LocalProcessTerminalView | Full terminal emulator scope. AppKit NSView bridging. Overkill. v1.10.1 lacks Swift 6 concurrency annotations. |
| Custom ANSI parser | Third-party ANSI libs | Available libs are output-generators, not parsers. No AttributedString output. |
| LazyVStack + Text(AttributedString) | NSTextView NSViewRepresentable | AppKit bridging complexity for append-only use case. Overkill. |
| Actor + Task | DispatchQueue.main.async | Swift 6 strict mode requires structured concurrency. Actor pattern is the correct abstraction. |

---

## Stack Patterns by Variant

**If the claude CLI is not found:**
- Detect via `Process` with `which claude` pre-check
- Show inline error in command palette: "claude not found at [paths tried]"
- Link to installation instructions

**If ANSI output is sparse (mostly plain text):**
- Custom parser handles gracefully — plain text between ANSI codes renders as `Color.gruvboxFg0`
- No special case needed

**If output is very long (thousands of lines):**
- `LazyVStack` renders only visible rows — handles this correctly
- Cap buffer at 10,000 lines, drop oldest when exceeded

**If claude CLI requires interactive input:**
- GSD commands (`/gsd:quick`, `/gsd:new-project`) are non-interactive by design (they spawn sub-agents)
- If prompt appears unexpectedly, surface as error state in output panel

---

## Version Compatibility

| Technology | Minimum | Project Target | Status |
|------------|---------|----------------|--------|
| Foundation.Process | macOS 10.13+ | macOS 14+ | Compatible |
| Darwin.openpty | macOS 10.10+ | macOS 14+ | Compatible |
| AsyncStream | Swift 5.5 / macOS 12+ | Swift 6 / macOS 14+ | Compatible |
| AttributedString | macOS 12+ | macOS 14+ | Compatible |
| Swift Regex literals | Swift 5.7 / macOS 13+ | Swift 6 / macOS 14+ | Compatible |
| LazyVStack | macOS 11+ | macOS 14+ | Compatible |
| ScrollViewReader | macOS 11+ | macOS 14+ | Compatible |
| scrollPosition(id:) | macOS 14+ | macOS 14+ | Compatible |
| Actor | Swift 5.5+ | Swift 6 | Compatible |

---

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Foundation.Process for CLI | HIGH | Mature API, in production use across macOS apps. Official Apple docs. |
| openpty over forkpty | HIGH | Apple engineer (Quinn) explicitly warned against forkpty in Swift. openpty pattern verified from Apple Developer Forums thread. |
| Actor + AsyncStream for streaming | HIGH | Verified pattern from Swift Forums thread on exactly this Swift 6 concurrency issue with NSPipe readability handlers. |
| Custom ANSI parser over library | HIGH | Investigated available Swift ANSI libs — all are generators not parsers. Custom 50-line parser is the correct choice. |
| SwiftTerm rejection | HIGH | v1.10.1 confirmed from Swift Package Index. No Swift 6 annotations confirmed. Scope mismatch confirmed from library docs. |
| swift-subprocess rejection | HIGH | Swift 6.1 minimum requirement confirmed from official repo. No PTY support confirmed from repo README. |
| PATH augmentation pattern | HIGH | macOS GUI app environment isolation is well-documented Apple behavior. Pattern is standard across macOS CLI-invoking apps. |
| LazyVStack for output panel | MEDIUM | Correct for performance, but scrollPosition(id:) + append-only pattern needs validation — scrollTo behavior with dynamic content can be tricky in practice. |

---

## Sources

### Official Apple Documentation
- [Foundation.Process](https://developer.apple.com/documentation/foundation/process) — Process API
- [NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable) — AppKit bridging (referenced, rejected for this use case)
- [AsyncStream](https://developer.apple.com/documentation/swift/asyncstream) — Async sequence creation
- [FileHandle.readabilityHandler](https://developer.apple.com/documentation/foundation/filehandle/1412413-readabilityhandler) — Pipe reading

### Swift Forums (authoritative community discussions)
- [Swift 6 Concurrency + NSPipe Readability Handlers](https://forums.swift.org/t/swift-6-concurrency-nspipe-readability-handlers/59834) — Actor pattern solution (HIGH confidence)
- [Swift Process with Pseudo Terminal](https://forums.swift.org/t/swift-process-with-psuedo-terminal/51457) — openpty vs forkpty (HIGH confidence)
- [Pitch: Swift Subprocess](https://forums.swift.org/t/pitch-swift-subprocess/69805) — swift-subprocess status

### Apple Developer Forums
- [Swift Process with Pseudo Terminal](https://developer.apple.com/forums/thread/688534) — Quinn's warning about forkpty (HIGH confidence)
- [Running a Child Process with Standard I/O](https://developer.apple.com/forums/thread/690310) — Process/Pipe patterns

### Library Pages
- [SwiftTerm — GitHub](https://github.com/migueldeicaza/SwiftTerm) — v1.10.1 (Feb 3, 2026), scope assessment
- [swift-subprocess — GitHub (swiftlang)](https://github.com/swiftlang/swift-subprocess) — Swift 6.1 minimum requirement verified
- [SwiftTerm — Capturing shell output discussion](https://github.com/migueldeicaza/SwiftTerm/discussions/308) — dataReceived override pattern

### Articles
- [Build a macOS App to Run Shell Commands Part 2](https://scriptingosx.com/2023/08/build-a-macos-application-to-run-a-shell-command-with-xcode-and-swiftui-part-2/) — Pipe+Process+sandbox pitfalls (MEDIUM confidence — 2023)
- [Automate with swift-subprocess](https://blog.jacobstechtavern.com/p/swift-subprocess) — swift-subprocess scope assessment

---

*Stack research for: GSD Monitor v1.2 — Embedded GSD Command Runner*
*Researched: 2026-02-17*
*Zero new SPM dependencies required. All capabilities from Foundation, Darwin, and Swift standard library.*
