---
phase: quick-7
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Theme/Theme.swift
  - GSDMonitor/Views/SidebarView.swift
  - GSDMonitor/Views/ContentView.swift
  - GSDMonitor/Views/DetailView.swift
  - GSDMonitor/Views/Dashboard/PhaseCardView.swift
autonomous: true
must_haves:
  truths:
    - "Project sidebar color is deterministic based on project name, not list position"
    - "Same project always gets the same color regardless of sort order or filtering"
    - "All color accents (sidebar border, progress bars, phase cards) use name-based color"
  artifacts:
    - path: "GSDMonitor/Theme/Theme.swift"
      provides: "ProjectColors.forName(_:) static method"
      contains: "forName"
    - path: "GSDMonitor/Views/SidebarView.swift"
      provides: "Name-based coloring, no index tracking"
    - path: "GSDMonitor/Views/ContentView.swift"
      provides: "Passes project name instead of color index"
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Receives projectName: String"
    - path: "GSDMonitor/Views/Dashboard/PhaseCardView.swift"
      provides: "Receives projectName: String"
  key_links:
    - from: "ProjectColors.forName"
      to: "All views"
      via: "project.name passed through view hierarchy"
      pattern: "ProjectColors\\.forName"
---

<objective>
Replace index-based project color assignment with deterministic name-based coloring.

Purpose: Projects should always have the same color regardless of list position, filtering, or sort order.
Output: All views use `ProjectColors.forName(projectName)` instead of `ProjectColors.forIndex(index)`.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Theme/Theme.swift
@GSDMonitor/Views/SidebarView.swift
@GSDMonitor/Views/ContentView.swift
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Views/Dashboard/PhaseCardView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add ProjectColors.forName and refactor all call sites</name>
  <files>
    GSDMonitor/Theme/Theme.swift
    GSDMonitor/Views/SidebarView.swift
    GSDMonitor/Views/ContentView.swift
    GSDMonitor/Views/DetailView.swift
    GSDMonitor/Views/Dashboard/PhaseCardView.swift
  </files>
  <action>
1. In `Theme.swift`, add a new static method to `ProjectColors`:
   ```swift
   static func forName(_ name: String) -> (dark: Color, bright: Color) {
       let index = Int(name.lowercased().first?.asciiValue ?? 0) % palette.count
       return palette[index]
   }
   ```
   Keep `forIndex` for backward compat but it can be removed later.

2. In `SidebarView.swift`:
   - Remove the `flatIndexOffset` computed property entirely (lines 85-93)
   - In `projectSection(for:startIndex:)`: remove `startIndex` parameter, change to `projectSection(for:)`. Remove the enumerated iteration — just use `ForEach(group.projects)`. Pass `projectName: project.name` instead of `colorIndex: startIndex + offset`.
   - In `projectList`, update the call: `projectSection(for: group)` (remove `startIndex` arg).
   - In `ProjectRow`: replace `let colorIndex: Int` with `let projectName: String`. Update `colorPair` to use `ProjectColors.forName(projectName)`.

3. In `ContentView.swift`:
   - Remove the `selectedProjectColorIndex` computed property entirely (lines 10-13).
   - Change `DetailView` call: replace `projectColorIndex: selectedProjectColorIndex` with `projectName: projectService.projects.first { $0.id == selectedProjectID }?.name ?? ""`.

4. In `DetailView.swift`:
   - Replace `var projectColorIndex: Int = 0` with `var projectName: String = ""`.
   - Line 56: change `ProjectColors.forIndex(projectColorIndex).bright` to `ProjectColors.forName(projectName).bright`.
   - Line 74: change `projectColorIndex: projectColorIndex` to `projectName: projectName`.

5. In `PhaseCardView.swift`:
   - Replace `var projectColorIndex: Int = 0` with `var projectName: String = ""`.
   - In `progressTintColor`: use `ProjectColors.forName(projectName).bright`.
   - In `progressGradient`: use `let colors = ProjectColors.forName(projectName)`.
  </action>
  <verify>Build the project with `xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -20` and confirm zero errors. Grep for `forIndex` in Views/ to confirm no remaining index-based calls. Grep for `colorIndex` to confirm no remaining references.</verify>
  <done>All project colors are derived from project name via `ProjectColors.forName(_:)`. No index-based color assignment remains in any view. Project builds successfully.</done>
</task>

</tasks>

<verification>
- `grep -r "forIndex" GSDMonitor/Views/` returns no matches
- `grep -r "colorIndex" GSDMonitor/Views/` returns no matches
- `grep -r "flatIndexOffset" GSDMonitor/` returns no matches
- `grep -r "forName" GSDMonitor/Theme/Theme.swift` returns the new method
- Project compiles without errors
</verification>

<success_criteria>
- ProjectColors.forName(_:) exists and hashes first character to palette index
- All 5 files updated: no colorIndex parameters remain
- flatIndexOffset removed from SidebarView
- selectedProjectColorIndex removed from ContentView
- App builds successfully
</success_criteria>

<output>
After completion, create `.planning/quick/7-sidebar-colors-by-first-letter-determini/7-SUMMARY.md`
</output>
