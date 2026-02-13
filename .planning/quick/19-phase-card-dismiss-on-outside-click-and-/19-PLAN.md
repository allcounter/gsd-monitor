---
phase: quick-19
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/DetailView.swift
  - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
autonomous: true
requirements: [QUICK-19]
must_haves:
  truths:
    - "Clicking outside the phase detail card dismisses it"
    - "Phase detail card is taller, showing more content without scrolling"
    - "Escape key still dismisses the card"
    - "Done button still dismisses the card"
  artifacts:
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Overlay-based phase detail presentation with background tap dismiss"
    - path: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      provides: "Taller phase detail card with updated frame constraints"
  key_links:
    - from: "DetailView.swift"
      to: "PhaseDetailView.swift"
      via: "overlay presentation triggered by selectedPhase binding"
---

<objective>
Replace the `.sheet` presentation of PhaseDetailView with a custom overlay approach, enabling dismiss-on-background-tap, and increase the card height for more visible content.

Purpose: Better UX — users can quickly dismiss the phase popup by clicking anywhere outside it, and see more content without scrolling.
Output: Updated DetailView.swift and PhaseDetailView.swift
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Views/Dashboard/PhaseDetailView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace sheet with overlay presentation and make card taller</name>
  <files>GSDMonitor/Views/DetailView.swift, GSDMonitor/Views/Dashboard/PhaseDetailView.swift</files>
  <action>
In DetailView.swift:
1. Remove the `.sheet(item: $selectedPhase)` modifier (line ~128-130).
2. Wrap the existing main content VStack in a ZStack so we can layer the overlay on top.
3. When `selectedPhase` is non-nil, show an overlay consisting of:
   - A full-screen semi-transparent black background (`Color.black.opacity(0.3)`) with an `onTapGesture` that sets `selectedPhase = nil` to dismiss.
   - The `PhaseDetailView` centered on top, wrapped in a container with rounded corners, shadow, and background (`Theme.background` or `.background(.regularMaterial)`).
   - Add a transition animation: `.opacity` on the overlay, and `.scale.combined(with: .opacity)` on the card, using `.animation(.easeInOut(duration: 0.2), value: selectedPhase)`.
4. Add `.onKeyPress(.escape) { selectedPhase = nil; return .handled }` or use a local `onExitCommand` to handle Escape key dismissal since we're no longer using a sheet. Alternatively, wrap the overlay in a Group and add `.keyboardShortcut(.escape, modifiers: [])` on a hidden button.

In PhaseDetailView.swift:
1. Change the frame modifier from `.frame(minWidth: 500, idealWidth: 600, minHeight: 400, idealHeight: 500)` to `.frame(width: 620, minHeight: 500, idealHeight: 700, maxHeight: 800)`.
2. Add `.clipShape(RoundedRectangle(cornerRadius: 12))` and `.shadow(color: .black.opacity(0.3), radius: 20, y: 10)` to give the card a floating appearance.
3. The `dismiss()` call in the Done button will no longer work since we're not in a sheet. Instead, accept an `onDismiss: () -> Void` closure parameter. Update the Done button to call `onDismiss()` instead of `dismiss()`. Remove the `@Environment(\.dismiss)` property.
4. Update the DetailView overlay to pass `onDismiss: { selectedPhase = nil }` to PhaseDetailView.

Important: Keep the `.keyboardShortcut(.defaultAction)` on the Done button so Enter still dismisses. For Escape key support, add a hidden button with `.keyboardShortcut(.cancelAction)` that also calls `onDismiss()` — this is the standard macOS pattern for cancel/escape in non-sheet contexts.
  </action>
  <verify>Build with `cd . && xcodebuild -scheme GSDMonitor -configuration Debug build 2>&1 | tail -5` — expect BUILD SUCCEEDED.</verify>
  <done>Phase detail card appears as a floating overlay. Clicking the dark background dismisses it. Pressing Escape dismisses it. Done button dismisses it. Card is visibly taller (700px ideal vs 500px before).</done>
</task>

</tasks>

<verification>
- Build succeeds without warnings related to changed files
- PhaseDetailView accepts onDismiss closure
- DetailView no longer uses .sheet for phase detail
- Background tap, Escape key, and Done button all dismiss the overlay
</verification>

<success_criteria>
- Phase detail displays as floating overlay card instead of sheet
- Clicking outside the card (on dark overlay) dismisses it
- Card is taller (idealHeight 700 vs previous 500)
- All existing dismiss mechanisms still work (Done button, Escape)
</success_criteria>

<output>
After completion, create `.planning/quick/19-phase-card-dismiss-on-outside-click-and-/19-SUMMARY.md`
</output>
