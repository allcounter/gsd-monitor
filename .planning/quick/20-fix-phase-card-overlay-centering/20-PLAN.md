---
phase: quick
plan: 20
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/DetailView.swift
autonomous: true
requirements: []
must_haves:
  truths:
    - "PhaseDetailView card appears centered both vertically and horizontally in the window"
    - "Clicking outside the card on the dimmed overlay dismisses the card"
    - "Card retains its current size constraints (idealHeight 700, min/max)"
  artifacts:
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Centered modal overlay for PhaseDetailView"
  key_links:
    - from: "ZStack overlay"
      to: "PhaseDetailView"
      via: "frame maxWidth/maxHeight .infinity with centered alignment"
---

<objective>
Fix PhaseDetailView overlay so the card appears centered in the window like a proper modal dialog.

Purpose: Currently the card placement is not reliably centered. The fix ensures the PhaseDetailView is explicitly framed to fill the ZStack and center its content.
Output: PhaseDetailView card centered vertically and horizontally over the dimmed overlay.
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
  <name>Task 1: Center PhaseDetailView as modal dialog in ZStack overlay</name>
  <files>GSDMonitor/Views/DetailView.swift</files>
  <action>
In DetailView.swift, modify the phase detail overlay section (currently lines ~137-148) to explicitly center the PhaseDetailView within the full ZStack area.

Current code places PhaseDetailView directly in the ZStack without explicit centering frame. Fix by wrapping the PhaseDetailView in a container that fills the available space and centers the card:

Replace the PhaseDetailView placement (line 145-147) with:

```swift
PhaseDetailView(phase: phase, project: project, onDismiss: { selectedPhase = nil })
    .background(Theme.bg0)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .transition(.scale(scale: 0.95).combined(with: .opacity))
```

The key change is adding `.frame(maxWidth: .infinity, maxHeight: .infinity)` BEFORE the transition. This makes the PhaseDetailView's outer frame expand to fill the ZStack, while the card's own internal `frame(minWidth: 580, idealWidth: 620, minHeight: 500, idealHeight: 700, maxHeight: 800)` in PhaseDetailView.swift constrains the visible card size. SwiftUI's default center alignment on the expanded frame centers the card.

Do NOT modify PhaseDetailView.swift — only DetailView.swift needs changes.
  </action>
  <verify>Build the project with `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5` — should compile without errors.</verify>
  <done>PhaseDetailView card renders centered horizontally and vertically in the overlay. Click-to-dismiss still works. Card size unchanged.</done>
</task>

</tasks>

<verification>
- Build succeeds without errors
- PhaseDetailView appears centered in window when clicking a phase card
- Clicking the dimmed area outside the card dismisses it
- Card size matches previous behavior (idealHeight 700)
- Escape key still dismisses the card
</verification>

<success_criteria>
PhaseDetailView overlay card is visually centered both vertically and horizontally in the window, functioning as a proper modal dialog.
</success_criteria>

<output>
After completion, create `.planning/quick/20-fix-phase-card-overlay-centering/20-SUMMARY.md`
</output>
