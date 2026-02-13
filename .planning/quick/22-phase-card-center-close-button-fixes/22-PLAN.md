---
phase: quick-22
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
  - GSDMonitor/Views/DetailView.swift
autonomous: true
requirements: [QUICK-22]
must_haves:
  truths:
    - "Phase detail card is visually centered (horizontally and vertically) within the window"
    - "Card does not stretch to fill the full window — it has a bounded size"
    - "Close button reads 'Close' not 'Done'"
    - "Close button is prominent and clearly visible in the header"
  artifacts:
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Centered overlay layout for PhaseDetailView"
    - path: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      provides: "Updated header with renamed and larger Close button"
  key_links:
    - from: "GSDMonitor/Views/DetailView.swift"
      to: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      via: "ZStack overlay centering"
      pattern: "PhaseDetailView.*onDismiss"
---

<objective>
Fix PhaseDetailView card: center it as a floating overlay in the window, rename "Done" to "Close", and make the Close button larger/more prominent.

Purpose: The card currently stretches to fill the window due to `.frame(maxWidth: .infinity, maxHeight: .infinity)`. It should float centered as a card overlay. The dismiss button should be clearly labeled "Close" and be visually prominent.
Output: Updated PhaseDetailView.swift and DetailView.swift
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/Dashboard/PhaseDetailView.swift
@GSDMonitor/Views/DetailView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Center card overlay and fix Close button</name>
  <files>GSDMonitor/Views/DetailView.swift, GSDMonitor/Views/Dashboard/PhaseDetailView.swift</files>
  <action>
In DetailView.swift around line 152-155, fix the PhaseDetailView overlay centering:
- REMOVE `.frame(maxWidth: .infinity, maxHeight: .infinity)` from the PhaseDetailView — this is what causes it to stretch and fill the entire window instead of being centered.
- The PhaseDetailView already has its own `.frame(minWidth: 580, idealWidth: 620, minHeight: 500, idealHeight: 700, maxHeight: 800)` constraint (line 135 of PhaseDetailView.swift). The ZStack in DetailView already centers its children by default. By removing the maxWidth/maxHeight infinity frame, the card will naturally center within the ZStack.
- Keep the `.background(Theme.bg0)` and `.transition(...)` modifiers on PhaseDetailView.

In PhaseDetailView.swift, update the header section (lines 32-37):
1. Rename "Done" to "Close": change `Button("Done")` to `Button("Close")`
2. Make the Close button larger and more prominent: increase the button by using `.controlSize(.large)` and keep the existing `.buttonStyle(.borderedProminent)` and `.tint(Theme.blue)`.
3. The button is already positioned after Spacer() in the HStack, so it is already on the right side of the header — no repositional change needed.
  </action>
  <verify>Build with `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5` — should show BUILD SUCCEEDED. Grep PhaseDetailView.swift for "Close" (not "Done") and ".controlSize(.large)".</verify>
  <done>Card floats centered in the window as a bounded overlay (not stretched to fill). Button reads "Close" with controlSize(.large) for prominence. Build succeeds.</done>
</task>

</tasks>

<verification>
- `xcodebuild` build succeeds
- PhaseDetailView.swift contains `Button("Close")` not `Button("Done")`
- PhaseDetailView.swift contains `.controlSize(.large)`
- DetailView.swift no longer has `.frame(maxWidth: .infinity, maxHeight: .infinity)` on the PhaseDetailView
</verification>

<success_criteria>
Phase detail card is visually centered as a floating overlay in the window, Close button is renamed from Done and is larger/more prominent, app builds successfully.
</success_criteria>

<output>
After completion, create `.planning/quick/22-phase-card-center-close-button-fixes/22-SUMMARY.md`
</output>
