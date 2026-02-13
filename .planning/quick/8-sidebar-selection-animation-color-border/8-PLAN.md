---
phase: 08-visual-overhaul
plan: sidebar-selection-border
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/SidebarView.swift
autonomous: true
must_haves:
  truths:
    - "Selected sidebar card shows a full colored border around it"
    - "Deselected sidebar card shows only the 4px left color strip"
    - "Transition between selected/deselected animates smoothly (~0.3s)"
  artifacts:
    - path: "GSDMonitor/Views/SidebarView.swift"
      provides: "Animated selection border on ProjectRow"
      contains: "RoundedRectangle.*stroke.*colorPair"
  key_links:
    - from: "ProjectRow.isSelected"
      to: "border overlay opacity/visibility"
      via: "SwiftUI animation modifier"
      pattern: "animation.*easeInOut.*isSelected"
---

<objective>
Add an animated color border that appears around the sidebar ProjectRow card when selected.

Purpose: Visual polish — the selection state becomes more prominent with a full border expanding from the existing left color strip.
Output: Updated SidebarView.swift with animated selection border.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/SidebarView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add animated selection border to ProjectRow</name>
  <files>GSDMonitor/Views/SidebarView.swift</files>
  <action>
In the ProjectRow struct, modify the `.background(...)` block (lines 183-196) to add a full border overlay when selected:

1. Keep the existing background structure with the left color strip (UnevenRoundedRectangle) — it stays visible always.

2. Add a NEW `.overlay` modifier AFTER the `.background(...)` block (not nested inside it) that draws a full `RoundedRectangle(cornerRadius: 8).stroke(colorPair.dark, lineWidth: 2)` border.

3. Control the border visibility with `.opacity(isSelected ? 1 : 0)`.

4. Add `.animation(.easeInOut(duration: 0.3), value: isSelected)` on the ProjectRow body (or on the overlay) to animate the transition.

The resulting code structure should look like:

```swift
.background(
    RoundedRectangle(cornerRadius: 8)
        .fill(isSelected ? Theme.bg2 : Theme.bg1)
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: 8,
                bottomLeadingRadius: 8,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
            .fill(colorPair.dark)
            .frame(width: 4)
        }
)
.overlay(
    RoundedRectangle(cornerRadius: 8)
        .stroke(colorPair.dark, lineWidth: 2)
        .opacity(isSelected ? 1 : 0)
)
.animation(.easeInOut(duration: 0.3), value: isSelected)
```

This keeps the left strip always visible as the "origin" of the color, and the full border fades in smoothly on selection.
  </action>
  <verify>Build succeeds: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5` shows BUILD SUCCEEDED.</verify>
  <done>Selected ProjectRow shows full colorPair.dark border (2pt stroke) with 0.3s ease-in-out animation. Deselected ProjectRow shows only the 4px left color strip. Build succeeds.</done>
</task>

</tasks>

<verification>
- App builds without errors
- Visual: selecting a project in sidebar shows border animating in
- Visual: switching projects shows border animating out on old, in on new
</verification>

<success_criteria>
- Animated border visible on selected sidebar card
- Smooth 0.3s transition
- Left color strip remains visible in both states
- No build warnings or errors introduced
</success_criteria>

<output>
After completion, create `.planning/quick/8-sidebar-selection-animation-color-border/8-SUMMARY.md`
</output>
