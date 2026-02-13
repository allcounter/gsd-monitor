---
phase: quick
plan: 24
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
  - GSDMonitor/Views/DetailView.swift
autonomous: true
requirements: [QUICK-24]
must_haves:
  truths:
    - "Close button is visually larger and easier to click"
    - "Close button is clearly visible with fg1 color instead of textSecondary"
    - "Phase detail card overlay covers entire window including sidebar area"
  artifacts:
    - path: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      provides: "Larger, more visible close button"
      contains: ".font(.title)"
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Full-window overlay positioning"
      contains: "ignoresSafeArea"
  key_links:
    - from: "GSDMonitor/Views/DetailView.swift"
      to: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      via: "PhaseDetailView instantiation inside overlay"
      pattern: "PhaseDetailView"
---

<objective>
Fix two issues with the PhaseDetailView overlay: (1) make the close button larger and more visible, (2) center the card over the entire window by restructuring the overlay ZStack.

Purpose: Improve usability of the phase detail popup — close button is currently too small and hard to see, and the overlay only covers the detail pane instead of the full window.
Output: Updated PhaseDetailView.swift and DetailView.swift
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/Dashboard/PhaseDetailView.swift
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Views/ContentView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix close button size and visibility in PhaseDetailView</name>
  <files>GSDMonitor/Views/Dashboard/PhaseDetailView.swift</files>
  <action>
In PhaseDetailView.swift, modify the floating close button (currently at line ~124-134):

1. Change `.font(.title2)` to `.font(.title)` on the xmark.circle.fill Image (line 128)
2. Add `.frame(width: 28, height: 28)` after the font modifier on the Image
3. Change `.foregroundStyle(Theme.textSecondary)` to `.foregroundStyle(Theme.fg1)` (line 130)

The close button block should look like:
```swift
Button {
    onDismiss()
} label: {
    Image(systemName: "xmark.circle.fill")
        .font(.title)
        .frame(width: 28, height: 28)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(Theme.fg1)
}
.buttonStyle(.plain)
.padding(12)
.keyboardShortcut(.defaultAction)
```

Do NOT change anything else in PhaseDetailView.swift.
  </action>
  <verify>Build succeeds: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5`</verify>
  <done>Close button uses .font(.title), has .frame(width: 28, height: 28), and uses Theme.fg1 foreground color</done>
</task>

<task type="auto">
  <name>Task 2: Move phase detail overlay to top-level ZStack in DetailView</name>
  <files>GSDMonitor/Views/DetailView.swift</files>
  <action>
In DetailView.swift, restructure the body so the phase detail overlay covers the ENTIRE view (not just the detail content area). Currently the overlay (lines 143-164) is inside the `if let project` ZStack. Move it outside.

The new structure of `body` should be:

```swift
var body: some View {
    ZStack {
        // Original content (if let project ... else ...)
        if let project = selectedProject {
            ZStack {
                VStack(spacing: 0) {
                    // ... existing pinned header, scrollable phases, etc (lines 14-135 unchanged)
                }
                .onAppear { ... }
                .onChange(of: selectedProject?.id) { ... }
            }
            .animation(.easeInOut(duration: 0.12), value: selectedPhase?.id)
        } else {
            // ... existing ContentUnavailableView (lines 168-180 unchanged)
        }

        // Phase detail overlay — NOW outside `if let project` so it covers entire view
        if let phase = selectedPhase, let project = selectedProject {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    selectedPhase = nil
                }
                .transition(.opacity)

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
            .ignoresSafeArea()
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }
    .animation(.easeInOut(duration: 0.12), value: selectedPhase?.id)
}
```

Key changes:
1. Wrap the ENTIRE body in a top-level `ZStack`
2. Remove the overlay code (old lines 143-164) from inside the inner `if let project` ZStack
3. Add the overlay as a sibling at the top-level ZStack, using `if let phase = selectedPhase, let project = selectedProject` (need both bindings since we're outside the `if let project` block)
4. Add `.ignoresSafeArea()` on BOTH the Color.black overlay AND the centering VStack
5. Move the `.animation` modifier to the outer ZStack (remove from inner ZStack)
6. The inner `if let project` ZStack no longer needs the overlay or the animation modifier for selectedPhase

IMPORTANT: Keep ALL existing code for the header, scroll area, milestones, etc. exactly as-is. Only move the overlay block and restructure the ZStack nesting.
  </action>
  <verify>Build succeeds: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5`</verify>
  <done>Phase detail overlay is in a top-level ZStack outside the `if let project` block, with .ignoresSafeArea() on both the backdrop and centering container, so the card floats centered over the entire view area</done>
</task>

</tasks>

<verification>
- App builds without errors
- Phase detail overlay backdrop covers full detail view area with .ignoresSafeArea()
- Close button is visibly larger (font .title, 28x28 frame) and uses Theme.fg1
- Clicking outside the card still dismisses it
- Escape key still dismisses the card
</verification>

<success_criteria>
- Close button uses .font(.title), .frame(width: 28, height: 28), Theme.fg1
- Overlay ZStack is at top level of DetailView body, outside `if let project`
- Both Color.black overlay and centering VStack have .ignoresSafeArea()
- App compiles and runs correctly
</success_criteria>

<output>
After completion, create `.planning/quick/24-fix-close-button-size-and-window-centeri/24-SUMMARY.md`
</output>
