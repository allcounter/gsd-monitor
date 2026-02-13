# Phase 9: Colored Sidebar Icons - Research

**Researched:** 2026-02-16
**Domain:** SwiftUI SF Symbols, Colored Icon Rendering
**Confidence:** HIGH

## Summary

Phase 9 adds status-colored SF Symbol icons to sidebar project rows. The implementation leverages SwiftUI's built-in SF Symbols system with `foregroundStyle()` for coloring, derives project status from phase data (matching existing SidebarView filter logic), and uses the existing Gruvbox semantic status colors established in Phase 6.

SF Symbols provide native macOS icons that scale automatically with Dynamic Type and window resizing—no manual scaling code needed. The icon will be placed in ProjectRow's HStack, colored via `foregroundStyle()` with monochrome or hierarchical rendering mode for visual depth.

**Primary recommendation:** Use `folder.fill` or `folder.badge` variants as base symbols, apply status colors (Theme.statusActive/statusComplete/statusNotStarted) via `foregroundStyle()`, derive project status from roadmap.phases (active = any in-progress, complete = all done, not-started = default), position icon left of project name in existing ProjectRow.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VISL-02 | Sidebar projekt-ikoner bruger farvede SF Symbols med Gruvbox-palette baseret på projekt-status | foregroundStyle() applies Gruvbox colors; status derivation from Phase data; SF Symbols scale automatically |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SF Symbols | macOS 12.0+ | System icon library with 6,900+ symbols | Native Apple icon system, automatic scaling, accessible, maintains visual consistency with macOS |
| SwiftUI | macOS 12.0+ | UI framework with Image(systemName:) | Native rendering of SF Symbols, foregroundStyle() color application, automatic Dynamic Type support |

### Supporting
N/A — SF Symbols are built into the OS. No external dependencies needed.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SF Symbols | Custom PNG assets | SF Symbols scale perfectly at any size, custom assets require @1x/@2x/@3x variants and don't adapt to Dynamic Type |
| foregroundStyle() | Using .foregroundColor() | foregroundStyle() is newer API (iOS 15+/macOS 12+) with better gradient/multi-layer support, but functionally equivalent for single-color icons |
| Status derivation from phases | Separate project.status field | Deriving from phases matches existing sidebar filter logic (line 54-67 SidebarView.swift) and avoids state duplication |

**Installation:**
No installation needed — SF Symbols are part of macOS.

## Architecture Patterns

### Recommended Project Structure
Icons will be integrated into existing structure:
```
GSDMonitor/
├── Views/
│   ├── SidebarView.swift        # Add icon to ProjectRow HStack
│   └── Components/              # Optional: extract status logic to ProjectStatusView if needed
└── Theme/
    └── Theme.swift              # Already contains status colors (statusActive, statusComplete, statusNotStarted)
```

### Pattern 1: Status Derivation from Roadmap Phases
**What:** Compute project status by inspecting roadmap.phases, matching existing filter logic
**When to use:** Anywhere project status is needed (already used in SidebarView.matchesStatusFilter)
**Example:**
```swift
// Source: Existing pattern in GSDMonitor/Views/SidebarView.swift (lines 54-67)
private func projectStatus(for project: Project) -> ProjectStatus {
    guard let roadmap = project.roadmap else { return .notStarted }

    // All phases done -> complete
    if !roadmap.phases.isEmpty && roadmap.phases.allSatisfy { $0.status == .done } {
        return .complete
    }

    // Any phase in progress -> active
    if roadmap.phases.contains(where: { $0.status == .inProgress }) {
        return .active
    }

    return .notStarted
}
```

### Pattern 2: SF Symbol with Status Color
**What:** Image(systemName:) + foregroundStyle() + status-based color selection
**When to use:** Displaying status-colored icons in UI
**Example:**
```swift
// Source: HackingWithSwift guide + existing Theme pattern
Image(systemName: "folder.fill")
    .symbolRenderingMode(.hierarchical)  // Adds depth with opacity layers
    .foregroundStyle(statusColor)
    .font(.system(size: 16))
```

### Pattern 3: ProjectRow Icon Integration
**What:** Add icon to existing ProjectRow HStack before project name
**When to use:** Modifying ProjectRow layout in SidebarView.swift
**Example:**
```swift
// Current: Text(project.name) at line 153
// New pattern:
HStack(spacing: 6) {
    Image(systemName: symbolName)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(statusColor)
        .font(.system(size: 16))

    Text(project.name)
        .font(.body)
        .foregroundStyle(Theme.textPrimary)
}
```

### Anti-Patterns to Avoid
- **Hardcoded status colors:** Use Theme.statusActive/statusComplete/statusNotStarted, not Color.yellow/Color.green
- **Manual icon scaling:** Don't use fixed frame sizes — SF Symbols scale automatically with .font() modifier
- **Palette rendering mode for single-color icons:** Use .monochrome or .hierarchical, not .palette (which requires 2-3 colors per layer)
- **Separate project.status field:** Derive from phases to avoid state duplication and sync issues

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Icon scaling | Custom geometry calculations for window resize | SF Symbols + .font() modifier | SF Symbols automatically scale with Dynamic Type and window size changes |
| Project status enum | New `project.status` field in model | Computed from `roadmap.phases` | Avoids state duplication; existing filter logic already implements this (lines 54-67 SidebarView.swift) |
| Icon color mapping | Custom color-per-status dictionary | Theme.statusActive/statusComplete/statusNotStarted | Semantic aliases already established in Phase 6, used throughout app (StatusBadge, PhaseDetailView) |
| Icon asset management | PNG/SVG custom icon sets | SF Symbols library (6,900+ icons) | Native to macOS, automatic light/dark variants, accessibility support, zero maintenance |

**Key insight:** SF Symbols were designed to solve icon scaling, color theming, and accessibility—building custom solutions duplicates work Apple already did and tested at scale.

## Common Pitfalls

### Pitfall 1: Using .frame() Instead of .font() for Icon Sizing
**What goes wrong:** `.frame(width: 16, height: 16)` clips symbol without actually scaling it, causing blurry or cut-off icons
**Why it happens:** Developers assume frame controls size like with images, but SF Symbols scale via font size
**How to avoid:** Use `.font(.system(size: 16))` or `.imageScale(.small/medium/large)` to size SF Symbols
**Warning signs:** Icons look blurry, cut off at edges, or don't scale proportionally

### Pitfall 2: Overusing Palette Rendering Mode
**What goes wrong:** Applying `.symbolRenderingMode(.palette)` with `foregroundStyle(color1, color2)` to simple single-layer symbols has no effect, or looks wrong
**Why it happens:** Not all symbols have multiple layers; palette mode only works with multi-layer symbols like `person.3.sequence.fill`
**How to avoid:** Use `.hierarchical` for depth on single-color icons, `.palette` only when intentionally applying 2-3 distinct colors to multi-layer symbols
**Warning signs:** Colors don't apply as expected, icon looks identical to monochrome mode

### Pitfall 3: Duplicating Status Logic
**What goes wrong:** Creating a new `projectStatus()` function when one already exists (SidebarView.matchesStatusFilter lines 54-67)
**Why it happens:** Planner doesn't see the existing filter logic implements identical status derivation
**How to avoid:** Extract existing status derivation from `matchesStatusFilter()` into reusable helper, or inline the same logic in ProjectRow
**Warning signs:** Two different functions returning "active" status with slightly different criteria, causing UI inconsistency

### Pitfall 4: Forgetting symbolRenderingMode
**What goes wrong:** Icon looks flat compared to other macOS UI elements
**Why it happens:** Default monochrome mode renders solid color without depth
**How to avoid:** Always specify `.symbolRenderingMode(.hierarchical)` for subtle depth, or `.palette`/`.multicolor` when appropriate
**Warning signs:** Icon feels "un-macOS-like", lacks visual polish of system icons in Finder/Settings

## Code Examples

Verified patterns from existing codebase and official sources:

### Status Derivation (Extracted from Existing Filter Logic)
```swift
// Source: GSDMonitor/Views/SidebarView.swift lines 54-67 (existing code)
enum ProjectStatus {
    case notStarted
    case active
    case complete
}

private func projectStatus(for project: Project) -> ProjectStatus {
    guard let roadmap = project.roadmap else { return .notStarted }

    // Completed = ALL phases are done
    if !roadmap.phases.isEmpty && roadmap.phases.allSatisfy { $0.status == .done } {
        return .complete
    }

    // Active = at least one phase in progress
    if roadmap.phases.contains(where: { $0.status == .inProgress }) {
        return .active
    }

    return .notStarted
}
```

### Status Color and Symbol Mapping
```swift
// Source: GSDMonitor/Theme/Theme.swift + existing status badge patterns
private func statusColor(for status: ProjectStatus) -> Color {
    switch status {
    case .notStarted: return Theme.statusNotStarted  // fg4 (gray)
    case .active: return Theme.statusActive          // yellow
    case .complete: return Theme.statusComplete      // green
    }
}

private func symbolName(for status: ProjectStatus) -> String {
    switch status {
    case .notStarted: return "folder"
    case .active: return "arrow.clockwise"
    case .complete: return "checkmark.circle.fill"
    }
}
```

### ProjectRow with Status Icon
```swift
// Source: Pattern combining SidebarView.ProjectRow + HackingWithSwift foregroundStyle guide
private struct ProjectRow: View {
    let project: Project
    let projectName: String
    let isSelected: Bool
    let isManuallyAdded: Bool
    let onRemove: () -> Void

    private var status: ProjectStatus {
        projectStatus(for: project)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Status icon
                Image(systemName: symbolName(for: status))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(statusColor(for: status))
                    .font(.system(size: 16))

                // Project name
                Text(project.name)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                // Phase count badge (existing)
                if let roadmap = project.roadmap {
                    Text(phaseCountText(roadmap: roadmap))
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                }
            }

            // ... rest of existing ProjectRow code
        }
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| .foregroundColor() | .foregroundStyle() | SwiftUI 3.0 (iOS 15/macOS 12) | foregroundStyle() supports gradients, multi-layer palette mode, semantic styles |
| Fixed-size PNG assets | SF Symbols | macOS 11+ (2020) | Symbols scale perfectly, support Dynamic Type, automatic light/dark variants |
| Custom status enums in models | Computed from domain data | Swift best practices (ongoing) | Avoids state synchronization bugs, single source of truth |

**Deprecated/outdated:**
- `.renderingMode(.template)` for UIImage — replaced by `.symbolRenderingMode()` for SF Symbols in SwiftUI
- Custom icon fonts (Font Awesome, etc.) — SF Symbols provide native alternative with better macOS integration

## Open Questions

1. **Which SF Symbol best represents "active project"?**
   - What we know: Existing icons in codebase use "arrow.right" for in-progress (PhaseDetailView line 151), "checkmark.circle.fill" for done (line 153)
   - What's unclear: Whether to match those patterns (arrow for active) or use project-specific symbols (folder variants)
   - Recommendation: Use "folder.badge.checkmark" for complete, "folder" for not started, "arrow.triangle.2.circlepath" or "folder.badge.gearshape" for active — maintains folder metaphor while indicating status

2. **Should blocked projects have a distinct icon?**
   - What we know: Requirements mention "blocked" status, but existing sidebar filter only has "all/active/completed" (SidebarView line 10-14)
   - What's unclear: How to detect blocked status — does a phase with status .blocked exist?
   - Recommendation: Defer blocked status until Phase data model includes it; current research found no .blocked PhaseStatus enum (only .notStarted, .inProgress, .done in Phase.swift)

## Sources

### Primary (HIGH confidence)
- GSDMonitor/Views/SidebarView.swift lines 54-67 — Existing project status filter logic
- GSDMonitor/Theme/Theme.swift lines 98-109 — Semantic status color definitions
- GSDMonitor/Models/Phase.swift lines 31-35 — PhaseStatus enum (notStarted, inProgress, done)
- Apple Human Interface Guidelines: SF Symbols — https://developer.apple.com/design/human-interface-guidelines/sf-symbols

### Secondary (MEDIUM confidence)
- [SF Symbols Mastery: Icons That Scale Perfectly in SwiftUI](https://21zerixpm.medium.com/sf-symbols-mastery-icons-that-scale-perfectly-in-swiftui-63488887e0d0) — January 2026 guide on foregroundStyle() patterns
- [How to get custom colors and transparency with SF Symbols - Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-get-custom-colors-and-transparency-with-sf-symbols) — Code examples for hierarchical/palette modes
- [SF Symbols: How to find SwiftUI System Images - swiftyplace](https://www.swiftyplace.com/blog/sf-symbols-swiftui-system-icons) — Recommendation to use SF Symbols app for browsing

### Tertiary (LOW confidence)
- [The Complete Guide to SF Symbols – Hacking with Swift](https://www.hackingwithswift.com/articles/237/complete-guide-to-sf-symbols) — General overview, recommends using SF Symbols app for specific symbol names (guide does not list folder/status symbol names)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — SF Symbols are native macOS, used throughout existing codebase (SidebarView, CommandPaletteView, PhaseDetailView)
- Architecture: HIGH — Status derivation pattern already exists in SidebarView (lines 54-67), foregroundStyle() pattern verified in Apple docs
- Pitfalls: MEDIUM-HIGH — Common SF Symbol mistakes documented in multiple sources, status duplication risk identified from existing codebase patterns

**Research date:** 2026-02-16
**Valid until:** 60 days (stable Apple APIs, not fast-moving)
