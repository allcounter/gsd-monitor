---
phase: quick-25
plan: 25
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
autonomous: true
requirements: [QUICK-25]
must_haves:
  truths:
    - "Close button floats outside the card at top-right corner, not overlapping header content"
    - "Close button has adequate touch target with 16pt padding"
  artifacts:
    - path: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      provides: "PhaseDetailView with offset close button"
      contains: ".offset(x: 12, y: -12)"
  key_links: []
---

<objective>
Fix close button overlapping StatusBadge and Open in Editor button in PhaseDetailView by offsetting the button outside the card boundary.

Purpose: The floating xmark.circle.fill button at .topTrailing currently sits inside the card, overlapping header content (StatusBadge, Open in Editor button). Moving it outside the card corner eliminates the overlap.
Output: Updated PhaseDetailView.swift with offset close button.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/Dashboard/PhaseDetailView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Offset close button outside card and increase padding</name>
  <files>GSDMonitor/Views/Dashboard/PhaseDetailView.swift</files>
  <action>
In PhaseDetailView.swift, find the floating close button section (around line 123-135). Make two changes:

1. Change `.padding(12)` to `.padding(16)` for better touch target.
2. Add `.offset(x: 12, y: -12)` AFTER the `.padding(16)` modifier (before `.keyboardShortcut`). This pushes the button 12pt right and 12pt up, placing it at the card's top-right corner edge rather than inside the card overlapping content.

The button block should look like:
```swift
.buttonStyle(.plain)
.padding(16)
.offset(x: 12, y: -12)
.keyboardShortcut(.defaultAction)
```

Do NOT change anything else in the file.
  </action>
  <verify>Build succeeds: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5` shows BUILD SUCCEEDED.</verify>
  <done>Close button has .padding(16) and .offset(x: 12, y: -12), no longer overlaps header content, build succeeds.</done>
</task>

</tasks>

<verification>
- Build succeeds with no errors
- Close button modifier chain includes .padding(16) and .offset(x: 12, y: -12)
</verification>

<success_criteria>
PhaseDetailView close button floats at the card's top-right corner edge without overlapping StatusBadge or Open in Editor button.
</success_criteria>

<output>
After completion, create `.planning/quick/25-fix-close-button-overlap-offset/25-SUMMARY.md`
</output>
