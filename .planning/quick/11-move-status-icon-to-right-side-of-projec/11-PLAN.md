---
phase: quick-11
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/SidebarView.swift
autonomous: true
requirements: [QUICK-11]
must_haves:
  truths:
    - "Status icon appears to the right of the project name, after the Spacer"
    - "Phase count text remains at the far right"
  artifacts:
    - path: "GSDMonitor/Views/SidebarView.swift"
      provides: "ProjectRow with repositioned status icon"
      contains: "Spacer()"
  key_links:
    - from: "ProjectRow.body HStack"
      to: "Image(systemName: statusSymbol)"
      via: "placed between Spacer and phase count text"
      pattern: "Spacer.*Image.*statusSymbol"
---

<objective>
Move the status icon from the left side of the project name to the right side, between the Spacer and the phase count text.

Purpose: Cleaner sidebar layout with name-first reading order.
Output: Updated ProjectRow in SidebarView.swift
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
  <name>Task 1: Reorder status icon in ProjectRow HStack</name>
  <files>GSDMonitor/Views/SidebarView.swift</files>
  <action>
In ProjectRow body (around lines 211-228), rearrange the HStack children from:

```
Image(statusSymbol) | Text(name) | Spacer | PhaseCount
```

To:

```
Text(name) | Spacer | Image(statusSymbol) | PhaseCount
```

Specifically:
1. Remove the Image block (lines 212-215) from its current position before Text(project.name)
2. Place it after Spacer() and before the `if let roadmap` block
3. Keep all modifiers on the Image unchanged (.symbolRenderingMode, .foregroundStyle, .font)
4. Keep all other elements unchanged
  </action>
  <verify>Build the project with `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5` — should succeed with BUILD SUCCEEDED</verify>
  <done>Status icon renders to the right of the project name, between Spacer and phase count text. Build succeeds.</done>
</task>

</tasks>

<verification>
Build succeeds. The HStack order in ProjectRow is: Text(name), Spacer, Image(statusSymbol), optional PhaseCount.
</verification>

<success_criteria>
- Status icon moved from left of project name to right side (after Spacer)
- Phase count text remains rightmost element
- Project builds without errors
</success_criteria>

<output>
After completion, create `.planning/quick/11-move-status-icon-to-right-side-of-projec/11-SUMMARY.md`
</output>
