# Phase 6: Theme Foundation - Research

**Researched:** 2026-02-15
**Domain:** SwiftUI theming, macOS appearance control, Gruvbox color palette
**Confidence:** HIGH

## Summary

Phase 6 implements a centralized Gruvbox Dark theme system for the GSD Monitor macOS app. The implementation requires three core components: (1) a Color extension with all 27 Gruvbox Dark colors defined via hex initializers, (2) forced dark mode via NSApp.appearance in AppDelegate, and (3) refactoring all hardcoded system colors (.blue, .green, .gray, .orange) to use themed colors from a centralized system.

The Gruvbox Dark palette by Pavel Pertsev provides excellent terminal-inspired aesthetics with 7 background variants (dark0_hard through dark4), 7 foreground variants (light0_hard through light4), and 16 accent colors (8 neutral + 8 bright variants). User decisions lock in specific color mappings: yellow for active status, green for complete, gray for not started, and red for blocked.

**Primary recommendation:** Use code-based Color extension with hex initializers (not asset catalog) for the two-layer naming system (raw Gruvbox names + semantic aliases). Force dark mode via NSApp.appearance = NSAppearance(named: .darkAqua) in AppDelegate rather than preferredColorScheme. Create a single parametrized StatusBadge component with Capsule shape to replace all existing badge variants.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Color palette scope
- Full Gruvbox Dark palette: all bg0-bg4, fg0-fg4, and all 8 accent colors (red, green, yellow, blue, purple, aqua, orange, gray)
- Original Pavel Pertsev variant (not Material)
- Main app background: bg0 (#282828)
- Two naming layers: raw Gruvbox names (Theme.bg0, Theme.aqua) + semantic aliases (Theme.statusActive = Theme.yellow)

#### Status color mapping
- In progress / active: Yellow (#d79921)
- Complete: Green (#98971a)
- Not started: Gray (fg4 #a89984)
- Blocked: Red (#cc241d)

#### Interactive element styling
- Sidebar list selection: Gruvbox accent highlight using bg2 (#504945) background
- Buttons: Custom Gruvbox-styled with themed colors, rounded corners, hover states
- Window title bar and toolbar: Themed to blend with bg0 — immersive look, not native title bar

#### Badge component design
- Shape: Rounded pill (capsule like GitHub labels)
- Color style: Filled background with solid Gruvbox accent color and contrasting text
- Text style: Lowercase ("in progress", "complete", "blocked")
- One parametrised component for all status badges

### Claude's Discretion
- Badge size relative to surrounding text (pick what looks balanced)
- Exact hover/press states for buttons
- Font weights and spacing within the theme system
- How to handle the forced dark mode (preferredColorScheme vs Info.plist)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope

</user_constraints>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 14+ | UI framework | Native Apple framework, already in use |
| AppKit | macOS 14+ | NSApp.appearance for dark mode | Only reliable way to force dark mode on macOS |

### Supporting
None required — built-in SwiftUI and AppKit APIs are sufficient.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Code-based Color extension | Asset catalog color sets | Asset catalog better for light/dark variants, but Gruvbox Dark is single-theme only. Code approach enables two-layer naming (raw + semantic). |
| NSApp.appearance | .preferredColorScheme() modifier | preferredColorScheme has reliability issues on macOS — once set to .dark, cannot unset to follow system. NSApp.appearance more reliable. |
| Hex initializer | RGB initializer | Hex matches Gruvbox documentation format, easier to verify against official palette. |

**Installation:**
No external dependencies required.

## Architecture Patterns

### Recommended Project Structure
```
GSDMonitor/
├── Theme/
│   ├── GruvboxTheme.swift       # Color extensions with hex values
│   └── SemanticColors.swift     # Semantic aliases (optional separate file)
└── App/
    └── AppDelegate.swift        # NSApp.appearance configuration
```

### Pattern 1: Two-Layer Color Naming
**What:** Define raw Gruvbox colors as static properties on Color, then create semantic aliases that map to those colors.

**When to use:** When you need both flexibility (access to full palette) and consistency (semantic names enforce correct usage).

**Example:**
```swift
extension Color {
    // Layer 1: Raw Gruvbox palette
    static let gruvboxBg0 = Color(hex: "#282828")
    static let gruvboxBg1 = Color(hex: "#3c3836")
    static let gruvboxBg2 = Color(hex: "#504945")
    static let gruvboxYellow = Color(hex: "#d79921")
    static let gruvboxGreen = Color(hex: "#98971a")

    // Layer 2: Semantic aliases
    static let appBackground = gruvboxBg0
    static let listSelectionBackground = gruvboxBg2
    static let statusActive = gruvboxYellow
    static let statusComplete = gruvboxGreen
}
```

### Pattern 2: Hex Color Initializer
**What:** Extension on Color to accept hex strings and convert to RGB values.

**When to use:** When defining colors from hex values (like Gruvbox palette).

**Example:**
```swift
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

### Pattern 3: Forced Dark Mode via AppDelegate
**What:** Set NSApp.appearance in applicationDidFinishLaunching to force dark mode.

**When to use:** When app should always use dark mode regardless of system setting.

**Example:**
```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}
```

### Pattern 4: Parametrized Badge Component
**What:** Single reusable badge component that accepts status/color as parameters.

**When to use:** When multiple badge types share the same visual structure but differ in content/color.

**Example:**
```swift
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .foregroundColor(.gruvboxBg0) // Dark text on bright background
            .clipShape(Capsule())
    }
}

// Usage:
StatusBadge(text: "in progress", color: .statusActive)
StatusBadge(text: "complete", color: .statusComplete)
```

### Pattern 5: List Selection Styling
**What:** Use .listRowBackground() modifier to customize List row selection appearance.

**When to use:** When customizing macOS List selection colors to match theme.

**Example:**
```swift
List(selection: $selectedItem) {
    ForEach(items) { item in
        ItemRow(item: item)
            .listRowBackground(
                selectedItem == item.id
                    ? Color.listSelectionBackground
                    : Color.clear
            )
    }
}
```

### Pattern 6: Custom Button Style
**What:** Conform to ButtonStyle protocol to create themed button appearances.

**When to use:** When buttons need consistent Gruvbox styling with hover states.

**Example:**
```swift
struct GruvboxButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                configuration.isPressed
                    ? Color.gruvboxBg3
                    : Color.gruvboxBg2
            )
            .foregroundColor(.gruvboxFg1)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// Usage:
Button("Action") { ... }
    .buttonStyle(GruvboxButtonStyle())
```

### Anti-Patterns to Avoid
- **Mixing system colors with theme colors:** Don't use .blue in some places and .gruvboxBlue in others. Commit fully to themed colors.
- **Hardcoding colors at call site:** Don't use Color(hex: "#282828") directly in views. Always reference named colors from the theme extension.
- **Using .preferredColorScheme() for forced dark mode on macOS:** It has reliability issues. Use NSApp.appearance instead.
- **Creating multiple badge components:** Don't create StatusBadge, RequirementBadge, PlanBadge separately. One parametrized component handles all cases.
- **Skipping semantic layer:** Don't force downstream code to use .gruvboxYellow directly. Provide .statusActive alias so intent is clear.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hex to Color conversion | Manual bit shifting and parsing | Standard hex initializer pattern | Edge cases (3-digit hex, 8-digit ARGB), well-tested pattern exists |
| Dark mode forcing | Custom AppStorage + .preferredColorScheme on every view | NSApp.appearance in AppDelegate | System-level control, more reliable, works with all components |
| Color asset management | Custom JSON/plist parser | SwiftUI Color extension with static properties | Type-safe, autocomplete-friendly, no runtime parsing |
| Button hover states | Custom gesture recognizers | ButtonStyle protocol with configuration.isPressed | Native SwiftUI API, handles accessibility, keyboard navigation |

**Key insight:** SwiftUI and AppKit provide robust APIs for theming. Custom solutions introduce bugs around edge cases (accessibility, keyboard nav, state restoration). Use built-in APIs.

## Common Pitfalls

### Pitfall 1: Incomplete Hardcoded Color Removal
**What goes wrong:** After adding theme system, some views still use .blue, .green, etc., creating visual inconsistency.

**Why it happens:** Easy to miss colors used in computed properties, extensions, or conditionally rendered views that don't appear in common use cases.

**How to avoid:**
1. Use global search (grep) to find all instances of `.blue`, `.green`, `.gray`, `.orange`, `.red`, `.purple` in Swift files
2. Check both direct Color usage and .foregroundStyle()/.tint() modifiers
3. Test all UI states (empty state, error state, loading state) to reveal conditionally shown colors

**Warning signs:**
- System accent blue appearing in buttons/links
- Inconsistent color saturation (system colors brighter than Gruvbox)
- Light mode colors appearing in specific UI states

### Pitfall 2: preferredColorScheme Propagation Issues
**What goes wrong:** Setting .preferredColorScheme(.dark) doesn't affect all components (DatePicker, confirmationDialog, sheets).

**Why it happens:** Some SwiftUI components on macOS ignore preferredColorScheme and respect only system appearance.

**How to avoid:** Use NSApp.appearance = NSAppearance(named: .darkAqua) in AppDelegate instead of .preferredColorScheme().

**Warning signs:**
- Sheets/popovers appear in light mode while main window is dark
- System pickers (date, color) don't match app theme
- Cannot revert to system appearance once preferredColorScheme is set

### Pitfall 3: Wrong Gruvbox Variant
**What goes wrong:** Using Gruvbox Material or other variants instead of original Pavel Pertsev colors, causing hex values to mismatch.

**Why it happens:** Many Gruvbox implementations exist (Material, Mix, original). Documentation often doesn't specify variant.

**How to avoid:**
1. Verify hex values against official source: https://github.com/morhetz/gruvbox-contrib/blob/master/color.table
2. Check bg0 is exactly #282828 (original) not #1d2021 (hard) or #32302f (soft)
3. Use neutral accent colors (#cc241d, #98971a, #d79921) not bright (#fb4934, #b8bb26, #fabd2f) for primary status indicators

**Warning signs:**
- Colors look more saturated/vibrant than expected (Material variant)
- Background is too dark (#1d2021) or too light (#32302f)
- Community says "that doesn't look like Gruvbox"

### Pitfall 4: Semantic Color Naming Confusion
**What goes wrong:** Downstream code uses raw Gruvbox names (.gruvboxYellow) instead of semantic names (.statusActive), making future palette changes difficult.

**Why it happens:** Both naming layers are available, and raw names are shorter to type.

**How to avoid:**
1. Document that semantic names are preferred for feature code
2. Consider making raw Gruvbox colors internal/fileprivate if strict enforcement needed
3. Code review should flag usage of .gruvboxYellow where .statusActive is appropriate

**Warning signs:**
- Status badges use .gruvboxYellow instead of .statusActive
- Changing status color mapping requires searching entire codebase
- Color usage doesn't clearly communicate intent

### Pitfall 5: Badge Text Contrast Issues
**What goes wrong:** Filled badge backgrounds with wrong text color create readability problems (low contrast).

**Why it happens:** Gruvbox has 7 background and 7 foreground variants. Picking wrong combination fails WCAG contrast requirements.

**How to avoid:**
1. Use dark background colors (bg0, bg1) for text on light backgrounds
2. Use light foreground colors (fg0, fg1) for text on dark backgrounds
3. For filled badges with bright accent backgrounds, use bg0 (#282828) for text
4. Test contrast ratio: aim for 4.5:1 minimum (WCAG AA standard)

**Warning signs:**
- Text is hard to read on badges
- Low vision users report accessibility issues
- Colors look muddy or washed out

### Pitfall 6: Window Title Bar Theming Limitations
**What goes wrong:** Title bar doesn't blend seamlessly with app background, retains native macOS appearance.

**Why it happens:** SwiftUI's window styling APIs are limited. .containerBackground() and .toolbarBackground() don't provide full control.

**How to avoid:**
1. Use .containerBackground(.gruvboxBg0, for: .window) modifier
2. Consider unified toolbar style (.windowStyle(.unified)) to merge title bar and toolbar
3. For advanced customization, may need to access NSWindow directly via NSViewRepresentable

**Warning signs:**
- Visible seam between title bar and content area
- Title bar has default gradient instead of flat bg0 color
- Toolbar buttons use system colors instead of themed colors

## Code Examples

Verified patterns from search results and official documentation:

### Complete Gruvbox Dark Palette Extension
```swift
// Source: https://github.com/morhetz/gruvbox-contrib/blob/master/color.table
import SwiftUI

extension Color {
    // MARK: - Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }

    // MARK: - Gruvbox Dark Backgrounds
    static let gruvboxBg0Hard = Color(hex: "#1d2021")
    static let gruvboxBg0 = Color(hex: "#282828")
    static let gruvboxBg0Soft = Color(hex: "#32302f")
    static let gruvboxBg1 = Color(hex: "#3c3836")
    static let gruvboxBg2 = Color(hex: "#504945")
    static let gruvboxBg3 = Color(hex: "#665c54")
    static let gruvboxBg4 = Color(hex: "#7c6f64")

    // MARK: - Gruvbox Dark Foregrounds
    static let gruvboxFg0Hard = Color(hex: "#f9f5d7")
    static let gruvboxFg0 = Color(hex: "#fbf1c7")
    static let gruvboxFg0Soft = Color(hex: "#f2e5bc")
    static let gruvboxFg1 = Color(hex: "#ebdbb2")
    static let gruvboxFg2 = Color(hex: "#d5c4a1")
    static let gruvboxFg3 = Color(hex: "#bdae93")
    static let gruvboxFg4 = Color(hex: "#a89984")

    // MARK: - Gruvbox Neutral Accents
    static let gruvboxRed = Color(hex: "#cc241d")
    static let gruvboxGreen = Color(hex: "#98971a")
    static let gruvboxYellow = Color(hex: "#d79921")
    static let gruvboxBlue = Color(hex: "#458588")
    static let gruvboxPurple = Color(hex: "#b16286")
    static let gruvboxAqua = Color(hex: "#689d6a")
    static let gruvboxOrange = Color(hex: "#d65d0e")
    static let gruvboxGray = Color(hex: "#928374")

    // MARK: - Gruvbox Bright Accents
    static let gruvboxBrightRed = Color(hex: "#fb4934")
    static let gruvboxBrightGreen = Color(hex: "#b8bb26")
    static let gruvboxBrightYellow = Color(hex: "#fabd2f")
    static let gruvboxBrightBlue = Color(hex: "#83a598")
    static let gruvboxBrightPurple = Color(hex: "#d3869b")
    static let gruvboxBrightAqua = Color(hex: "#8ec07c")
    static let gruvboxBrightOrange = Color(hex: "#fe8019")

    // MARK: - Semantic Aliases
    static let appBackground = gruvboxBg0
    static let surfaceBackground = gruvboxBg1
    static let listSelectionBackground = gruvboxBg2

    static let primaryText = gruvboxFg1
    static let secondaryText = gruvboxFg2

    static let statusActive = gruvboxYellow       // #d79921
    static let statusComplete = gruvboxGreen      // #98971a
    static let statusNotStarted = gruvboxFg4      // #a89984 (gray)
    static let statusBlocked = gruvboxRed         // #cc241d
}
```

### Parametrized Badge Component
```swift
import SwiftUI

struct ThemedBadge: View {
    let text: String
    let backgroundColor: Color
    let textColor: Color

    init(text: String, backgroundColor: Color, textColor: Color = .gruvboxBg0) {
        self.text = text.lowercased()
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .clipShape(Capsule())
    }
}

// Usage examples:
ThemedBadge(text: "in progress", backgroundColor: .statusActive)
ThemedBadge(text: "complete", backgroundColor: .statusComplete)
ThemedBadge(text: "blocked", backgroundColor: .statusBlocked)
```

### Force Dark Mode in AppDelegate
```swift
// Source: Multiple community sources on NSApp.appearance reliability
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force dark mode - more reliable than .preferredColorScheme on macOS
        NSApp.appearance = NSAppearance(named: .darkAqua)

        // Existing notification setup
        UNUserNotificationCenter.current().delegate = self
    }
}
```

### Custom Button Style with Hover States
```swift
import SwiftUI

struct GruvboxButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                configuration.isPressed
                    ? Color.gruvboxBg3
                    : Color.gruvboxBg2
            )
            .foregroundColor(.gruvboxFg1)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// Apply to individual button:
Button("Action") { ... }
    .buttonStyle(GruvboxButtonStyle())

// Or set as default for all buttons in a view:
VStack {
    Button("Save") { ... }
    Button("Cancel") { ... }
}
.buttonStyle(GruvboxButtonStyle())
```

### List Row Selection Styling
```swift
List(selection: $selectedProjectID) {
    ForEach(projects) { project in
        ProjectRow(project: project)
            .tag(project.id)
            .listRowBackground(
                selectedProjectID == project.id
                    ? Color.listSelectionBackground
                    : Color.clear
            )
    }
}
```

### Window and Toolbar Theming
```swift
WindowGroup {
    ContentView()
        .containerBackground(.appBackground, for: .window)
        .toolbarBackground(.appBackground, for: .windowToolbar)
}
.windowStyle(.hiddenTitleBar) // For immersive look
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Asset catalog for all colors | Code-based Color extensions for single-theme apps | Ongoing | Asset catalogs better for light/dark variants, but code better for single theme with semantic layering |
| .preferredColorScheme for dark mode | NSApp.appearance for forced dark mode on macOS | iOS 14+ / macOS 11+ | preferredColorScheme has reliability issues on macOS (can't unset, doesn't affect all components) |
| Multiple badge components | Single parametrized component | SwiftUI 2.0+ | Reduces code duplication, enforces visual consistency |
| String-based asset names | Xcode 15 static property generation | Xcode 15 (2023) | Type-safe access to assets, but doesn't apply to code-based colors |
| RGB color definitions | Hex color initializers | Community pattern | Matches design documentation format (Gruvbox published as hex) |

**Deprecated/outdated:**
- **UIColor for SwiftUI**: Use SwiftUI's Color type directly, not NSColor/UIColor wrappers (SwiftUI 1.0+)
- **.accentColor modifier**: Deprecated in favor of .tint in SwiftUI 3.0+ (macOS 12+)
- **ColorScheme environment for forcing dark mode**: Use NSApp.appearance on macOS for reliability

## Open Questions

1. **Window title bar immersive blending**
   - What we know: .containerBackground() and .toolbarBackground() provide some control, .windowStyle(.hiddenTitleBar) removes native title bar
   - What's unclear: Whether fully immersive blend (zero visible seam) achievable with pure SwiftUI or requires NSWindow access
   - Recommendation: Start with .containerBackground() + .windowStyle(.hiddenTitleBar). If seam persists, investigate NSWindow.titlebarAppearsTransparent via NSViewRepresentable

2. **Badge size optimization**
   - What we know: .caption font + 8px horizontal, 4px vertical padding is standard
   - What's unclear: Whether this scales well with Dynamic Type or needs adjustment
   - Recommendation: Use .caption with .fontWeight(.medium), test with Accessibility Inspector for Dynamic Type scaling

3. **Semantic color completeness**
   - What we know: Status colors (active, complete, notStarted, blocked) defined
   - What's unclear: Whether additional semantic categories needed (error, warning, info, success for non-status contexts)
   - Recommendation: Start with status-only semantics, add categories as needed when implementing downstream features

## Sources

### Primary (HIGH confidence)
- [Gruvbox official color table](https://github.com/morhetz/gruvbox-contrib/blob/master/color.table) - Complete hex palette verified
- [Apple SwiftUI Color documentation](https://developer.apple.com/documentation/swiftui/color) - Official API reference
- [Apple ButtonStyle documentation](https://developer.apple.com/documentation/swiftui/buttonstyle) - Official protocol reference
- [Apple preferredColorScheme documentation](https://developer.apple.com/documentation/swiftui/view/preferredcolorscheme(_:)) - Official modifier reference

### Secondary (MEDIUM confidence)
- [Creating hex-based colors in SwiftUI](https://danielsaidi.com/blog/2022/05/06/creating-hex-based-colors-in-uikit-appkit-and-swiftui) - Verified hex initializer pattern
- [Semantic Colors and Styles by Chris Eidhof](https://chris.eidhof.nl/post/semantic-colors/) - Semantic naming philosophy
- [SwiftUI Design System: Semantic Colors](https://www.magnuskahr.dk/posts/2025/06/swiftui-design-system-considerations-semantic-colors/) - Two-layer naming pattern
- [Customizing macOS window background in SwiftUI](https://nilcoalescing.com/blog/CustomizingMacOSWindowBackgroundInSwiftUI/) - Window theming approach
- [SwiftUI List row background customization](https://sarunw.com/posts/swiftui-list-row-background-color/) - List selection styling
- [NSApp.appearance vs preferredColorScheme](https://write.as/angelo/workarounds-or-how-to-get-reliable-color-scheme-switching-in-swiftui-apps) - Dark mode forcing comparison
- [Custom Button Styles in SwiftUI](https://fatbobman.com/en/posts/custom-button-style-in-swiftui/) - ButtonStyle patterns
- [SwiftUI Badge Component Design](https://medium.com/@jpmtech/create-a-custom-badge-for-any-view-in-swiftui-647957cdf7ba) - Capsule badge pattern

### Tertiary (LOW confidence)
- [SwiftUI theming common mistakes](https://www.hackingwithswift.com/articles/224/common-swiftui-mistakes-and-how-to-fix-them) - General pitfalls, not theme-specific
- [Gruvbox color palette listings](https://www.color-hex.com/color-palette/1026676) - Community palette, verify against official source

## Metadata

**Confidence breakdown:**
- Gruvbox color palette: HIGH - Verified against official Pavel Pertsev repository color table
- Standard stack (SwiftUI/AppKit): HIGH - Official Apple frameworks, already in use
- Architecture patterns: HIGH - Verified with official documentation and multiple community sources
- Dark mode forcing: HIGH - NSApp.appearance approach verified across multiple sources as more reliable than preferredColorScheme
- Badge component design: MEDIUM - Capsule shape standard, specific sizing/padding needs testing
- Window title bar theming: MEDIUM - containerBackground documented, but immersive blending limits unclear
- List selection styling: MEDIUM - listRowBackground modifier documented, selection state handling needs verification

**Research date:** 2026-02-15
**Valid until:** 2026-03-15 (30 days — SwiftUI/AppKit stable APIs, Gruvbox palette unchanging)
