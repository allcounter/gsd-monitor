---
phase: quick-27
plan: 27
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/DetailView.swift
  - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
autonomous: true
requirements: []
must_haves:
  truths:
    - "Clicking a phase card opens PhaseDetailView in a native macOS sheet"
    - "Sheet can be dismissed via Close button or Escape key"
    - "No custom overlay, backdrop, or centering wrappers remain in DetailView"
  artifacts:
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Sheet-based phase detail presentation"
      contains: ".sheet(item:"
    - path: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      provides: "Self-dismissing detail view using @Environment dismiss"
      contains: "@Environment(\\.dismiss)"
  key_links:
    - from: "GSDMonitor/Views/DetailView.swift"
      to: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      via: ".sheet(item: $selectedPhase)"
      pattern: "\\.sheet\\(item:"
---

<objective>
Revert PhaseDetailView from custom overlay presentation back to native macOS .sheet() presentation.

Purpose: The custom overlay approach (ZStack + backdrop + centering) has been iterated on many times (quick tasks 19-26) without satisfactory results. Native .sheet() gives proper macOS chrome, keyboard handling, and centering for free.
Output: Two modified Swift files using native sheet presentation.
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
  <name>Task 1: Revert DetailView to use .sheet(item:) and remove overlay infrastructure</name>
  <files>GSDMonitor/Views/DetailView.swift</files>
  <action>
In DetailView.swift, restructure the body property:

1. Remove the outermost ZStack wrapper (line 12). The body should start directly with `if let project = selectedProject`.

2. Inside the `if let project` block, keep the existing inner ZStack (line 14) that contains the VStack with header + scrollable phases. This inner ZStack is actually just wrapping the main content VStack — replace it with the VStack directly (remove the redundant ZStack layer).

3. Remove the entire overlay block (lines 159-181): the `if let phase = selectedPhase` block containing:
   - Color.black.opacity(0.3) backdrop with ignoresSafeArea and onTapGesture
   - The VStack > Spacer > HStack > Spacer centering container
   - The PhaseDetailView instantiation within the overlay
   - The .transition modifiers

4. Remove the `.animation(.easeInOut(duration: 0.12), value: selectedPhase?.id)` modifier (line 183).

5. Add `.sheet(item: $selectedPhase)` modifier on the main content VStack (the one containing header + scrollable phases, after the .onChange modifier around line 142). The sheet content closure:
   ```swift
   .sheet(item: $selectedPhase) { phase in
       PhaseDetailView(phase: phase, project: project)
   }
   ```

6. Keep everything else exactly as-is: the header section, stats grid, milestone timeline, scrollable phases list, filteredPhases, the ContentUnavailableView for no selection, onAppear, onChange, all helper functions, and all previews.
  </action>
  <verify>Project builds without errors: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5`</verify>
  <done>DetailView.swift has no ZStack overlay, no Color.black backdrop, no centering VStack/Spacer wrappers, no .animation on selectedPhase. Uses .sheet(item: $selectedPhase) to present PhaseDetailView.</done>
</task>

<task type="auto">
  <name>Task 2: Update PhaseDetailView to use @Environment dismiss instead of onDismiss closure</name>
  <files>GSDMonitor/Views/Dashboard/PhaseDetailView.swift</files>
  <action>
In PhaseDetailView.swift:

1. Remove the `let onDismiss: () -> Void` property (line 6).

2. Add `@Environment(\.dismiss) var dismiss` after the `let project: Project` line.

3. Change the "Close" button action from `onDismiss()` to `dismiss()` (line 33). Keep .buttonStyle(.borderedProminent), .controlSize(.regular), and .keyboardShortcut(.defaultAction).

4. Change the hidden Cancel button action from `onDismiss()` to `dismiss()` (line 134). Keep .keyboardShortcut(.cancelAction) and .hidden().

5. Remove `.clipShape(RoundedRectangle(cornerRadius: 12))` (line 129) — the sheet provides its own chrome.

6. Remove `.shadow(color: .black.opacity(0.3), radius: 20, y: 10)` (line 130) — the sheet provides its own shadow.

7. Keep the .frame(minWidth: 580, idealWidth: 620, minHeight: 500, idealHeight: 700, maxHeight: 800) constraint as-is.

8. Keep everything else unchanged: header layout, ScrollView content, all sections (Goal, Dependencies, Requirements, Success Criteria, Plans), PlanCard struct, computed properties.
  </action>
  <verify>Project builds without errors: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5`</verify>
  <done>PhaseDetailView has no onDismiss closure parameter. Uses @Environment(\.dismiss). No .clipShape or .shadow. Close button and hidden Cancel button both call dismiss().</done>
</task>

</tasks>

<verification>
- `xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build` succeeds
- DetailView.swift contains `.sheet(item: $selectedPhase)`
- DetailView.swift does NOT contain `Color.black.opacity` or `.animation(.easeInOut`
- PhaseDetailView.swift contains `@Environment(\.dismiss)`
- PhaseDetailView.swift does NOT contain `onDismiss` or `.clipShape` or `.shadow`
</verification>

<success_criteria>
PhaseDetailView presents as a native macOS sheet when clicking a phase card. Dismisses via Close button or Escape key. No custom overlay remnants in DetailView.
</success_criteria>

<output>
After completion, create `.planning/quick/27-revert-to-sheet-presentation/27-SUMMARY.md`
</output>
