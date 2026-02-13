---
phase: quick-23
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
  - GSDMonitor/Views/DetailView.swift
autonomous: true
requirements: [QUICK-23]
must_haves:
  truths:
    - "Close button floats at top-right corner of the phase detail card"
    - "Close button is no longer in the header HStack"
    - "Phase detail card is truly centered in the overlay"
  artifacts:
    - path: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      provides: "ZStack overlay with close button at topTrailing"
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Full-frame centering container for PhaseDetailView"
  key_links:
    - from: "PhaseDetailView.swift"
      to: "onDismiss closure"
      via: "Close button tap in ZStack overlay"
      pattern: "ZStack.*alignment.*topTrailing"
---

<objective>
Move the Close button to a floating top-right overlay on the PhaseDetailView card, and fix centering by wrapping PhaseDetailView in a full-frame container in DetailView.swift.

Purpose: The Close button currently sits in the header HStack which wastes header space and looks cluttered. True centering requires the overlay container to stretch to fill, not the card itself.
Output: Two modified Swift files with correct overlay close button and proper centering.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@GSDMonitor/Views/Dashboard/PhaseDetailView.swift
@GSDMonitor/Views/DetailView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Move Close button to floating top-right overlay and fix centering container</name>
  <files>GSDMonitor/Views/Dashboard/PhaseDetailView.swift, GSDMonitor/Views/DetailView.swift</files>
  <action>
**PhaseDetailView.swift — Move Close button to ZStack overlay:**

1. Wrap the entire `body` content in a `ZStack(alignment: .topTrailing)`.
2. The first child of the ZStack is the existing `VStack(alignment: .leading, spacing: 0)` with all content.
3. The second child is the close button, positioned by the ZStack's .topTrailing alignment:
   ```swift
   Button {
       onDismiss()
   } label: {
       Image(systemName: "xmark.circle.fill")
           .font(.title2)
           .symbolRenderingMode(.hierarchical)
           .foregroundStyle(Theme.textSecondary)
   }
   .buttonStyle(.plain)
   .padding(12)
   .keyboardShortcut(.defaultAction)
   ```
4. Remove the old `Button("Close")` from the header HStack (lines 32-37 currently), including its `.buttonStyle(.borderedProminent)`, `.tint(Theme.blue)`, `.controlSize(.large)`, and `.keyboardShortcut(.defaultAction)` modifiers.
5. Keep the hidden Cancel button for Escape key dismissal — move it outside the header HStack, place it at the end of the ZStack (hidden, so position does not matter).
6. The `.frame(minWidth:..., maxHeight:800)`, `.clipShape(...)`, and `.shadow(...)` modifiers stay on the outermost ZStack (they were on the VStack, move them to the ZStack since it is now the root).

**DetailView.swift — Fix centering with full-frame container:**

In the phase detail overlay section (around lines 144-155), wrap PhaseDetailView in a centering container. Replace:
```swift
PhaseDetailView(phase: phase, project: project, onDismiss: { selectedPhase = nil })
    .background(Theme.bg0)
    .transition(.scale(scale: 0.95).combined(with: .opacity))
```

With:
```swift
VStack {
    Spacer()
    HStack {
        Spacer()
        PhaseDetailView(phase: phase, project: project, onDismiss: { selectedPhase = nil })
            .background(Theme.bg0)
        Spacer()
    }
    Spacer()
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
.transition(.scale(scale: 0.95).combined(with: .opacity))
```

This makes the container stretch to fill the entire ZStack area, and the Spacers center the card both horizontally and vertically. The `.frame(maxWidth/maxHeight: .infinity)` is on the container VStack, NOT on PhaseDetailView itself — the card retains its own bounded frame constraints.
  </action>
  <verify>
Run: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5`
Verify build succeeds.
Grep PhaseDetailView.swift for "ZStack(alignment: .topTrailing)" and "xmark.circle.fill".
Grep DetailView.swift for the centering container pattern.
Confirm no `Button("Close")` remains in PhaseDetailView header HStack.
  </verify>
  <done>
Close button renders as a floating "xmark.circle.fill" icon at top-right of the card with 12pt padding. Header HStack no longer contains any close button. Phase detail card is centered via a full-frame VStack/HStack/Spacer container in DetailView.swift. Build succeeds with zero errors.
  </done>
</task>

</tasks>

<verification>
- Build succeeds: `xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build`
- PhaseDetailView.swift: ZStack(alignment: .topTrailing) wraps body, xmark.circle.fill button present
- PhaseDetailView.swift: No Button("Close") in header HStack
- DetailView.swift: PhaseDetailView wrapped in centering container with .frame(maxWidth: .infinity, maxHeight: .infinity)
</verification>

<success_criteria>
- Close button is a floating xmark.circle.fill at top-right of card
- Card is truly centered in overlay via full-frame container
- Escape key still dismisses the card
- Build compiles without errors
</success_criteria>

<output>
After completion, create `.planning/quick/23-phase-card-close-topright-and-true-cente/23-SUMMARY.md`
</output>
