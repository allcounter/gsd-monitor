# Phase 7: Animated Progress Rings - Research

**Researched:** 2026-02-15
**Domain:** SwiftUI circular progress visualization with animations
**Confidence:** HIGH

## Summary

SwiftUI provides excellent native support for creating animated circular progress rings using the `Circle()` shape with `trim(from:to:)` and `stroke()` modifiers. The standard pattern involves a ZStack with a background ring and an animated foreground ring, where animation is triggered via `onAppear()` and controlled with `.animation(_:value:)` to prevent unwanted re-animations on every state change.

The key challenge for this phase is ensuring progress rings animate smoothly on first appearance but do NOT re-animate on every FSEvents-triggered data reload. The codebase already uses debouncing (1 second) in `ProjectService.swift` to coalesce rapid file changes, which helps but doesn't prevent animation re-triggering when the view's progress value updates.

**Primary recommendation:** Create a reusable `CircularProgressRing` view with size variants (full and mini), use `.animation(_:value:)` with a dedicated animation trigger flag that's set only on view appearance (not on progress updates), and leverage `Equatable` conformance to minimize unnecessary view updates.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | Built-in | UI framework with Shape protocol, trim(), stroke() | Native framework, zero dependencies |
| Circle() | Built-in | Foundation shape for circular progress | Built-in Shape conforming to Animatable protocol |
| @Observable | Swift 6 | State management replacing @ObservableObject | Modern Swift 6 pattern, more efficient |
| AsyncAlgorithms | Already in project | Provides debounce for FSEvents | Already used in ProjectService for file monitoring |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| .animation(_:value:) | SwiftUI | Control when animations trigger | Prevent re-animation on every state change |
| Equatable | Swift stdlib | Minimize view updates | Optimize performance with multiple rings |
| .drawingGroup() | SwiftUI | GPU-accelerated rendering | If performance degrades with 10+ rings |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom Shape | Third-party library (UICircularProgressRing, etc.) | Custom = zero dependencies, full control, macOS-native styling |
| Circle() trim() | CircularProgressViewStyle | Native ProgressView style only renders determinate gauge on macOS, not iOS; custom gives consistent look |
| onAppear trigger | Timer-based animation | onAppear is standard SwiftUI pattern, no extra state management |

**Installation:**
No installation needed - all native SwiftUI components.

## Architecture Patterns

### Recommended Component Structure
```
GSDMonitor/
├── Views/
│   └── Components/
│       └── CircularProgressRing.swift    # Reusable component with size variants
├── Views/Dashboard/
│   └── PhaseCardView.swift                # Uses full-size ring
└── Views/
    └── SidebarView.swift                  # Uses mini ring in ProjectRow
```

### Pattern 1: Reusable CircularProgressRing Component
**What:** Single reusable view with size/styling parameters
**When to use:** For both phase cards and sidebar (different sizes, same logic)
**Example:**
```swift
// Based on: https://cindori.com/developer/swiftui-animation-rings
// and https://www.hackingwithswift.com/quick-start/swiftui/how-to-draw-part-of-a-solid-shape-using-trim

struct CircularProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let ringColor: Color
    let backgroundColor: Color
    let lineWidth: CGFloat

    @State private var animateProgress = false

    var body: some View {
        Circle()
            .stroke(backgroundColor, lineWidth: lineWidth)
            .overlay {
                Circle()
                    .trim(from: 0, to: animateProgress ? progress : 0)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            .rotationEffect(.degrees(-90)) // Start at top, not right
            .animation(.easeOut(duration: 0.6), value: animateProgress)
            .onAppear {
                animateProgress = true
            }
    }
}
```

### Pattern 2: Animation Trigger Separation
**What:** Use separate `@State` variable for animation trigger, distinct from progress value
**When to use:** When data updates frequently (FSEvents) but animation should only happen once
**Example:**
```swift
struct CircularProgressRing: View {
    let progress: Double

    @State private var animateProgress = false  // Animation trigger flag

    var body: some View {
        Circle()
            .trim(from: 0, to: animateProgress ? progress : 0)
            .stroke(...)
            .animation(.easeOut(duration: 0.6), value: animateProgress)  // Animate based on FLAG, not progress
            .onAppear {
                animateProgress = true  // Set flag ONCE on appearance
            }
    }
}
```

**Key insight:** By animating `animateProgress` instead of `progress`, the ring animates only when the flag changes (once, on appear), not when progress updates from FSEvents reloads.

### Pattern 3: Size Variants via Parameters
**What:** Use frame() and lineWidth parameter for different sizes
**When to use:** Same component for phase cards (large) and sidebar (mini)
**Example:**
```swift
// Phase card - full size
CircularProgressRing(progress: 0.75, ringColor: Theme.statusActive,
                     backgroundColor: Theme.bg2, lineWidth: 8)
    .frame(width: 80, height: 80)

// Sidebar - mini
CircularProgressRing(progress: 0.75, ringColor: Theme.accent,
                     backgroundColor: Theme.bg2, lineWidth: 4)
    .frame(width: 24, height: 24)
```

### Pattern 4: Progress Value Computation
**What:** Keep progress calculation in parent view, pass computed value to ring
**When to use:** Different progress calculations (phase vs project overall)
**Example:**
```swift
// PhaseCardView.swift
private var phaseProgress: Double {
    if phase.status == .done { return 1.0 }
    guard totalPlans > 0 else { return 0.0 }
    return Double(completedPlans) / Double(totalPlans)
}

var body: some View {
    VStack {
        // ... other content
        CircularProgressRing(progress: phaseProgress, ...)
    }
}
```

### Anti-Patterns to Avoid
- **Animating progress value directly:** Using `.animation(_:value: progress)` causes re-animation on every data update (FSEvents reload)
- **Recreating view on data change:** Using `.id(progress)` forces view recreation and re-animation
- **Layout-based animations:** Changing frame size instead of using scaleEffect causes expensive layout recalculations
- **Multiple @State variables for same progress:** Keep single source of truth (computed property), one animation trigger

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Circular shape | Custom path drawing with Bezier curves | Circle() with trim() and stroke() | Built-in, Animatable protocol support, perfect circles guaranteed |
| Animation timing | Manual Timer-based interpolation | withAnimation() or .animation(_:value:) | SwiftUI handles timing curves, cancelation, interruption |
| Debouncing file events | Custom timer-based coalescing | AsyncAlgorithms debounce | Already in project, handles edge cases (rapid changes, cancelation) |
| Equatable conformance | Manual diffing logic | Automatic synthesis or standard impl | Swift compiler handles it correctly, fewer bugs |

**Key insight:** SwiftUI's Shape protocol + Animatable + trim() was designed specifically for progress indicators. Custom Bezier paths add complexity without benefit and lose built-in animation support.

## Common Pitfalls

### Pitfall 1: Progress Ring Re-animates on Every Data Update
**What goes wrong:** Ring animates from 0→progress every time FSEvents triggers project reload (every file save)
**Why it happens:** Using `.animation(_:value: progress)` or implicit animation causes animation whenever progress value changes, even if it's the same value being re-set
**How to avoid:** Use separate `@State` animation trigger flag, animate flag (not progress), set flag only in `onAppear()`
**Warning signs:** Ring "flashes" or restarts animation when saving files in watched project

### Pitfall 2: Trim Must Come Before Stroke
**What goes wrong:** Applying trim() after stroke() doesn't compile or produces unexpected results
**Why it happens:** `trim()` modifier only works on Shape types, `stroke()` returns a View
**How to avoid:** Always chain: `Circle().trim(...).stroke(...)`
**Warning signs:** Compiler error "value of type 'some View' has no member 'trim'"

### Pitfall 3: Circle Draws from Right (0°), Not Top
**What goes wrong:** Progress ring fills from right side (3 o'clock) instead of top (12 o'clock)
**Why it happens:** SwiftUI's coordinate system starts at 0° on the right
**How to avoid:** Apply `.rotationEffect(.degrees(-90))` to rotate -90° (top becomes 0°)
**Warning signs:** Ring visually starts at right edge instead of top

### Pitfall 4: Performance Degradation with Many Rings
**What goes wrong:** Scrolling becomes janky with 10+ animated rings on screen
**Why it happens:** Complex view hierarchies with nested animations compound layout cost
**How to avoid:**
  1. Use `.animation(_:value:)` with specific dependencies (not implicit animation)
  2. Make parent views conform to Equatable to reduce unnecessary re-renders
  3. If still slow: apply `.drawingGroup()` to use GPU rendering
**Warning signs:** Frame drops when scrolling list with many projects, Energy Impact spike in Activity Monitor

### Pitfall 5: Animation Curve Feels Wrong
**What goes wrong:** Progress ring animation feels too slow, too fast, or robotic
**Why it happens:** Default `.linear` animation has no easing
**How to avoid:** Use `.easeOut(duration: 0.6)` for natural "slow-in, fast-out" feel matching macOS UI patterns
**Warning signs:** Animation doesn't feel "smooth" or "natural"

### Pitfall 6: Mini Rings Invisible Due to Line Width
**What goes wrong:** Sidebar mini rings (24×24) appear as solid dots or invisible
**Why it happens:** Line width too thick relative to circle diameter (e.g., 8px line on 24px circle)
**How to avoid:** Scale lineWidth proportionally: full size (80px) = 8px, mini (24px) = 3-4px
**Warning signs:** Small rings look like filled circles instead of rings

## Code Examples

Verified patterns from research sources:

### Minimal Animated Ring (Core Pattern)
```swift
// Source: https://cindori.com/developer/swiftui-animation-rings
struct AnimatedRing: View {
    let progress: Double
    let color: Color

    @State private var drawingStroke = false

    var body: some View {
        Circle()
            .stroke(style: StrokeStyle(lineWidth: 16))
            .foregroundStyle(.tertiary)
            .overlay {
                Circle()
                    .trim(from: 0, to: drawingStroke ? progress : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
            }
            .rotationEffect(.degrees(-90))
            .animation(.easeOut(duration: 0.6), value: drawingStroke)
            .onAppear {
                drawingStroke = true
            }
    }
}
```

### Preventing Re-animation on Data Updates
```swift
// Source: Research synthesis from multiple sources
struct CircularProgressRing: View {
    let progress: Double
    let color: Color

    @State private var hasAppeared = false  // Animation trigger, NOT tied to progress

    var body: some View {
        Circle()
            .trim(from: 0, to: hasAppeared ? progress : 0)  // Use progress when flag is true
            .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .animation(.easeOut(duration: 0.6), value: hasAppeared)  // Animate FLAG only
            .onAppear {
                hasAppeared = true  // Set once, never changes
            }
    }
}

// When progress updates from FSEvents reload:
// - progress value changes: 0.5 → 0.6
// - hasAppeared stays true (no change)
// - .animation(_:value: hasAppeared) sees no change
// - No animation triggered ✓
```

### Size Variants with Parameters
```swift
// Source: Research synthesis
struct CircularProgressRing: View {
    let progress: Double
    let color: Color
    let backgroundColor: Color
    let lineWidth: CGFloat

    @State private var animationTrigger = false

    var body: some View {
        Circle()
            .stroke(backgroundColor, lineWidth: lineWidth)
            .overlay {
                Circle()
                    .trim(from: 0, to: animationTrigger ? progress : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            .rotationEffect(.degrees(-90))
            .animation(.easeOut(duration: 0.6), value: animationTrigger)
            .onAppear {
                animationTrigger = true
            }
    }
}

// Usage - Phase Card (large)
CircularProgressRing(
    progress: phaseProgress,
    color: Theme.statusActive,
    backgroundColor: Theme.bg2,
    lineWidth: 8
)
.frame(width: 80, height: 80)

// Usage - Sidebar (mini)
CircularProgressRing(
    progress: projectProgress,
    color: Theme.accent,
    backgroundColor: Theme.bg2,
    lineWidth: 3
)
.frame(width: 24, height: 24)
```

### Integration with Theme Colors
```swift
// Using existing Theme.swift colors
private var ringColor: Color {
    switch phase.status {
    case .notStarted: return Theme.statusNotStarted  // gray
    case .inProgress: return Theme.statusActive      // yellow
    case .done: return Theme.statusComplete          // green
    }
}

// In view body
CircularProgressRing(
    progress: phaseProgress,
    color: ringColor,
    backgroundColor: Theme.bg2,
    lineWidth: 8
)
```

### Performance Optimization for Lists
```swift
// Source: https://www.swiftdifferently.com/blog/swiftui/swiftui-animations-deep-dive
// If performance degrades with many rings:

struct ProjectRow: View, Equatable {
    let project: Project

    static func == (lhs: ProjectRow, rhs: ProjectRow) -> Bool {
        lhs.project.id == rhs.project.id &&
        lhs.project.roadmap?.phases.map(\.status) == rhs.project.roadmap?.phases.map(\.status)
    }

    var body: some View {
        HStack {
            // ... content
            CircularProgressRing(...)
        }
    }
}

// In parent list:
List {
    ForEach(projects) { project in
        ProjectRow(project: project)
            .equatable()  // Use custom equality check
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| .animation() without value | .animation(_:value:) | SwiftUI 3.0 (iOS 15, macOS 12) | Explicit control over animation triggers, deprecated implicit form |
| @ObservedObject + @Published | @Observable (Swift 6) | Swift 5.9 (2023) | More efficient, less boilerplate, better concurrency |
| Combine debounce | AsyncAlgorithms debounce | Swift 5.9 (2023) | Structured concurrency, simpler async/await patterns |
| UIKit UICircularProgressBar | SwiftUI Circle + trim | SwiftUI 1.0 (2019) | Declarative, animatable by default, composable |

**Deprecated/outdated:**
- `.animation(_:)` without value parameter: Deprecated in SwiftUI 3.0, causes animation on every state change
- Timer-based manual interpolation for progress: Use withAnimation() or .animation(_:value:)
- Third-party circular progress libraries (for basic use cases): SwiftUI built-ins are sufficient

**Current best practices (2026):**
- Use `.animation(_:value:)` with explicit Equatable value
- Separate animation trigger state from data state
- Swift 6 @Observable for state management
- AsyncAlgorithms for debouncing/throttling

## Open Questions

1. **Should progress rings in sidebar show percentage text overlay?**
   - What we know: Phase cards show "X%" text label separate from ring
   - What's unclear: Sidebar mini rings (24×24) may be too small for readable text
   - Recommendation: No text in mini rings (sidebar), only in full-size (phase cards). Rely on visual fill + hover tooltip if needed.

2. **Should animation duration vary by progress delta?**
   - What we know: Static 0.6s duration works for most cases
   - What's unclear: Large progress jumps (0.1 → 0.9) might look odd with same duration as small (0.1 → 0.2)
   - Recommendation: Start with fixed 0.6s (simple, predictable). Only add dynamic duration if user feedback indicates it's jarring.

3. **Should rings animate on status change (notStarted → inProgress)?**
   - What we know: Color changes via `ringColor` computed property
   - What's unclear: Should color transition be animated, or instant?
   - Recommendation: Instant color change (no animation), only progress fill animates. Color indicates state, fill indicates progress - different semantics.

## Performance Validation Strategy

Given success criterion: "Ingen performance-degradation med 10+ synlige ringe på skærmen"

**Test scenario:**
1. Create test project with 15+ phases (or 10+ projects in sidebar)
2. Trigger FSEvents reload by editing .planning/STATE.md
3. Monitor:
   - Frame rate during scroll (should maintain 60fps on macOS)
   - Energy Impact in Activity Monitor
   - Animation smoothness (no stuttering)

**Optimization sequence if performance issues:**
1. Add `.animation(_:value:)` with specific trigger (not implicit)
2. Add Equatable conformance to parent views (PhaseCardView, ProjectRow)
3. Add `.drawingGroup()` to CircularProgressRing (GPU rendering)

## Sources

### Primary (HIGH confidence)
- [Animating a Circular Progress Bar in SwiftUI - Cindori](https://cindori.com/developer/swiftui-animation-rings) - Complete code example, trim/stroke pattern
- [How to draw part of a solid shape using trim() - Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-draw-part-of-a-solid-shape-using-trim) - Official trim() documentation and examples
- [How to start an animation immediately after a view appears - Hacking with Swift](https://www.hackingwithswift.com/quick-start/swiftui/how-to-start-an-animation-immediately-after-a-view-appears) - onAppear + withAnimation pattern
- [How Your Views Actually Move - SwiftDifferently](https://www.swiftdifferently.com/blog/swiftui/swiftui-animations-deep-dive) - Performance optimization, transform vs layout animations
- [Demystifying SwiftUI Animation - Fat Bao Man](https://fatbobman.com/en/posts/the_animation_mechanism_of_swiftui/) - Animation mechanism deep dive, .animation(_:value:) best practices

### Secondary (MEDIUM confidence)
- [SwiftUI Scroll Performance: The 120FPS Challenge](https://blog.jacobstechtavern.com/p/swiftui-scroll-performance-the-120fps) - List performance with animations (iOS 18+, macOS 15+)
- [Building a Customizable Ring Progress View in SwiftUI](https://swiftuisnippets.wordpress.com/2024/08/03/building-a-customizable-ring-progress-view-in-swiftui/) - Config-based reusability pattern
- [How to Avoid Repeating SwiftUI View Updates - Fat Bao Man](https://fatbobman.com/en/posts/avoid_repeated_calculations_of_swiftui_views/) - Equatable conformance for performance
- [Throttling and Debouncing in SwiftUI - Carmine Porricelli](https://medium.com/@carmineporricelli96/throttling-and-debouncing-in-swiftui-4f3cea9ffec5) - Debouncing patterns (already implemented in ProjectService)

### Tertiary (LOW confidence - flagged for validation)
- Apple Developer Documentation for CircularProgressViewStyle: Could not access (JavaScript-required page), but WebSearch confirms it's macOS-only for determinate progress, iOS shows indeterminate spinner. Custom solution better for cross-platform consistency.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All built-in SwiftUI components, well-documented patterns
- Architecture: HIGH - Multiple verified sources demonstrate same patterns (Circle + trim + stroke)
- Pitfalls: HIGH - Specific issues identified with solutions from authoritative sources
- Performance: MEDIUM - General principles verified, specific 10+ rings test needs validation in Phase 7 execution

**Research date:** 2026-02-15
**Valid until:** ~45 days (SwiftUI animation patterns stable, macOS 14 target unchanged)

**Key implementation insights:**
1. **Animation trigger separation is critical** - Most important finding for avoiding re-animation on FSEvents
2. **ProjectService already has debouncing** - 1 second debounce reduces FSEvents noise but doesn't prevent animation trigger
3. **No existing animation code** - Clean slate, no legacy patterns to refactor
4. **Theme colors ready** - Phase 6 completed, all semantic colors available (statusActive, statusComplete, etc.)
5. **Equatable optimization available** - Swift 6 @Observable + Equatable for performance if needed
