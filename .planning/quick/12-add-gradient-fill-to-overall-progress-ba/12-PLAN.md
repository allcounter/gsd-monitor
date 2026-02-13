---
phase: quick
plan: 12
type: execute
wave: 1
depends_on: []
files_modified: [GSDMonitor/Views/DetailView.swift]
autonomous: true
requirements: [QUICK-12]
must_haves:
  truths:
    - "Overall progress bar in DetailView shows a gradient fill from dark to bright project color"
  artifacts:
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Gradient-filled progress bar using AnimatedProgressBar"
      contains: "AnimatedProgressBar"
  key_links:
    - from: "GSDMonitor/Views/DetailView.swift"
      to: "GSDMonitor/Views/Components/CircularProgressRing.swift"
      via: "AnimatedProgressBar component"
      pattern: "AnimatedProgressBar"
---

<objective>
Replace the stock ProgressView in DetailView with the existing AnimatedProgressBar component, adding a gradient fill from the project's dark color to bright color.

Purpose: Visual consistency with the sidebar gradient pattern and richer progress indication.
Output: Updated DetailView.swift using AnimatedProgressBar with gradient.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Views/Components/CircularProgressRing.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace ProgressView with gradient AnimatedProgressBar</name>
  <files>GSDMonitor/Views/DetailView.swift</files>
  <action>
In DetailView.swift around lines 54-56, replace:

```swift
ProgressView(value: overallProgress(for: project))
    .progressViewStyle(.linear)
    .tint(ProjectColors.forName(projectName).bright)
```

With:

```swift
AnimatedProgressBar(
    progress: overallProgress(for: project),
    barColor: ProjectColors.forName(projectName).bright,
    height: 8,
    gradient: LinearGradient(
        colors: [ProjectColors.forName(projectName).dark, ProjectColors.forName(projectName).bright],
        startPoint: .leading,
        endPoint: .trailing
    )
)
```

This uses the existing AnimatedProgressBar component from CircularProgressRing.swift. The gradient goes from the project's dark color to bright color (leading to trailing), matching the sidebar gradient pattern.
  </action>
  <verify>Build the project with `cd . && xcodebuild build -scheme GSDMonitor -destination 'platform=macOS' -quiet 2>&1 | tail -5` — must compile without errors.</verify>
  <done>DetailView shows AnimatedProgressBar with gradient fill instead of stock ProgressView. Build succeeds.</done>
</task>

</tasks>

<verification>
- Project builds without errors
- AnimatedProgressBar is used in DetailView with gradient parameter
- No remaining references to the old ProgressView for overall progress in DetailView
</verification>

<success_criteria>
- DetailView.swift uses AnimatedProgressBar with LinearGradient from dark to bright project color
- Clean build
</success_criteria>

<output>
After completion, create `.planning/quick/12-add-gradient-fill-to-overall-progress-ba/12-SUMMARY.md`
</output>
