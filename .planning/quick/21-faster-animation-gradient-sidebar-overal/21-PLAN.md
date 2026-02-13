---
phase: quick-21
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/DetailView.swift
  - GSDMonitor/Views/SidebarView.swift
autonomous: true
---

<objective>
Three UI polish tweaks: faster PhaseDetailView overlay animation, gradient fill on sidebar project rows, and replace system ProgressView with AnimatedProgressBar for overall progress in DetailView.

Purpose: Visual consistency and snappier feel — the overlay animation is sluggish at 0.2s, the sidebar rows lack the gradient treatment used elsewhere, and the overall progress bar is the last remaining system ProgressView (tech debt from v1.1 audit).
Output: Updated DetailView.swift and SidebarView.swift
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Views/SidebarView.swift
@GSDMonitor/Views/Components/CircularProgressRing.swift
@GSDMonitor/Theme/Theme.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Faster overlay animation and gradient overall progress bar in DetailView</name>
  <files>GSDMonitor/Views/DetailView.swift</files>
  <action>
Two changes in DetailView.swift:

1. **Faster overlay animation:** On line 151, change `.animation(.easeInOut(duration: 0.2), value: selectedPhase?.id)` to `.animation(.easeInOut(duration: 0.12), value: selectedPhase?.id)` for a snappier feel.

2. **Replace system ProgressView with AnimatedProgressBar:** In the "Overall project progress" section (around lines 56-58), replace:
```swift
ProgressView(value: overallProgress(for: project))
    .progressViewStyle(.linear)
    .tint(ProjectColors.forName(projectName).bright)
```
with:
```swift
AnimatedProgressBar(
    progress: overallProgress(for: project),
    barColor: ProjectColors.forName(projectName).bright,
    height: 6,
    gradient: LinearGradient(
        colors: [ProjectColors.forName(projectName).dark, ProjectColors.forName(projectName).bright],
        startPoint: .leading,
        endPoint: .trailing
    )
)
```
This uses the same AnimatedProgressBar component already used in sidebar ProjectRow and PhaseCardView, with the gradient parameter for the gradient fill effect. Height 6 matches the default AnimatedProgressBar height.
  </action>
  <verify>Build succeeds: `cd . && swift build 2>&1 | tail -5`</verify>
  <done>PhaseDetailView overlay animates at 0.12s duration. Overall progress bar in DetailView uses AnimatedProgressBar with gradient fill instead of system ProgressView.</done>
</task>

<task type="auto">
  <name>Task 2: Add gradient background to sidebar project row elements</name>
  <files>GSDMonitor/Views/SidebarView.swift</files>
  <action>
In the ProjectRow struct, update the `.background(...)` modifier (around lines 255-268) to add a subtle gradient fill to the row background. Replace the plain `.fill(isSelected ? Theme.bg2 : Theme.bg1)` with a gradient that incorporates the project's color:

Replace:
```swift
.background(
    RoundedRectangle(cornerRadius: 8)
        .fill(isSelected ? Theme.bg2 : Theme.bg1)
        .overlay(alignment: .leading) {
```

With:
```swift
.background(
    RoundedRectangle(cornerRadius: 8)
        .fill(
            LinearGradient(
                colors: [
                    isSelected ? Theme.bg2 : Theme.bg1,
                    isSelected ? colorPair.dark.opacity(0.15) : Theme.bg1
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(alignment: .leading) {
```

This adds a very subtle gradient that fades from the normal background to a hint of the project color on the right side — only visible when selected, keeping the unselected state clean. The 0.15 opacity keeps it subtle and consistent with the Gruvbox dark palette.
  </action>
  <verify>Build succeeds: `cd . && swift build 2>&1 | tail -5`</verify>
  <done>Sidebar project rows show a subtle gradient fill incorporating the project's assigned color when selected.</done>
</task>

</tasks>

<verification>
- `swift build` compiles without errors
- PhaseDetailView overlay animation is noticeably snappier (0.12s vs 0.2s)
- Overall progress bar in DetailView shows gradient fill with animated appearance (not system ProgressView)
- Sidebar project rows have subtle gradient background when selected
</verification>

<success_criteria>
All three UI tweaks applied: faster overlay animation (0.12s), gradient AnimatedProgressBar replacing system ProgressView in DetailView, and gradient fill on sidebar project rows. Build succeeds with no warnings related to these changes.
</success_criteria>

<output>
After completion, create `.planning/quick/21-faster-animation-gradient-sidebar-overal/21-SUMMARY.md`
</output>
