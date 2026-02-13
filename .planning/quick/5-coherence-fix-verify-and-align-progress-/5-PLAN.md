---
phase: quick-5
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/DetailView.swift
  - GSDMonitor/Views/SidebarView.swift
autonomous: true
must_haves:
  truths:
    - "Overall project progress reflects partial phase completion via plan data"
    - "Sidebar progress bar matches DetailView overall progress calculation"
    - "PhaseCardView plan-level progress remains unchanged"
  artifacts:
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Weighted overall progress using plan completion data"
    - path: "GSDMonitor/Views/SidebarView.swift"
      provides: "Sidebar progress matching DetailView calculation"
  key_links:
    - from: "DetailView.swift"
      to: "project.plans"
      via: "Plan-based weighted progress calculation"
      pattern: "project\\.plans"
    - from: "SidebarView.swift"
      to: "project.plans"
      via: "Same plan-based weighted calculation"
      pattern: "project\\.plans"
---

<objective>
Make overall project progress calculations use plan-level completion data for smooth, accurate progress reporting.

Purpose: Currently DetailView and SidebarView count only fully-done phases, so a project at phase 8/12 with the current phase 80% complete shows 58% (7/12) instead of ~65%. Using plan completion data gives continuous, accurate progress.

Output: Updated DetailView.swift and SidebarView.swift with weighted progress calculations.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Views/SidebarView.swift
@GSDMonitor/Views/Dashboard/PhaseCardView.swift
@GSDMonitor/Models/Phase.swift
@GSDMonitor/Models/Plan.swift
@GSDMonitor/Models/Project.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Implement weighted overall progress in DetailView and SidebarView</name>
  <files>GSDMonitor/Views/DetailView.swift, GSDMonitor/Views/SidebarView.swift</files>
  <action>
Update overall project progress in both views to use plan-level data for smooth progress reporting. The calculation logic:

For each phase:
- If phase.status == .done: contributes 1.0 (full weight)
- If phase has plans (project.plans filtered by phaseNumber): contributes (donePlans / totalPlans) for that phase
- If phase has no plans and status != .done: contributes 0.0

Overall progress = sum of phase contributions / total phase count

**DetailView.swift changes:**
1. Update `overallCompletionPercentage(for:)` to use plan-weighted calculation instead of simple done-phase count
2. Update the ProgressView value on line 53 to use the same weighted calculation (currently uses `completedPhases` integer count)
3. Keep `completedPhases(in:)` method if still used elsewhere, or replace both with a single `overallProgress(for:) -> Double` method that returns 0.0-1.0

New helper method pattern:
```swift
private func overallProgress(for project: Project) -> Double {
    guard let roadmap = project.roadmap, !roadmap.phases.isEmpty else { return 0 }
    let plans = project.plans ?? []

    let phaseContributions = roadmap.phases.map { phase -> Double in
        if phase.status == .done { return 1.0 }
        let phasePlans = plans.filter { $0.phaseNumber == phase.number }
        guard !phasePlans.isEmpty else { return 0.0 }
        let done = phasePlans.filter { $0.status == .done }.count
        return Double(done) / Double(phasePlans.count)
    }

    return phaseContributions.reduce(0, +) / Double(roadmap.phases.count)
}
```

Then use: `ProgressView(value: overallProgress(for: project))` and `Text("\(Int(overallProgress(for: project) * 100))%")`

**SidebarView.swift changes:**
1. Update `progressValue(roadmap:)` in ProjectRow to accept `Project` instead of just `Roadmap` (needs access to plans)
2. Apply the same weighted calculation
3. Update `progressPercentage` and the `phaseCountText` accordingly
4. Update the call sites in ProjectRow body (lines 178, 183) to pass project instead of roadmap

Note: ProjectRow already has `let project: Project` property, so it has access to plans. Change the method signatures from `(roadmap: Roadmap)` to use `project` directly.

**DO NOT** change PhaseCardView.swift -- its plan-level progress within a single phase is already correct.
  </action>
  <verify>
Build the project with Cmd+B or `xcodebuild build` to confirm no compilation errors. Verify:
1. DetailView uses the new overallProgress method for both the percentage text and the ProgressView value
2. SidebarView ProjectRow uses the same weighted calculation
3. PhaseCardView is untouched
  </verify>
  <done>
Overall progress in sidebar and detail view reflects partial phase completion through plan data. A project with 7 done phases and 1 phase at 50% plan completion (out of 12 total) shows ~62% instead of 58%. Both views produce identical progress values for the same project.
  </done>
</task>

</tasks>

<verification>
- Build succeeds without errors
- DetailView and SidebarView use identical progress calculation logic
- PhaseCardView unchanged
- Progress values are continuous (not jumping in phase-sized increments)
</verification>

<success_criteria>
- Overall project progress accounts for in-progress phase plan completion
- Sidebar and detail view progress bars show the same value for the same project
- A project with partial plan completion in the current phase shows higher progress than pure phase counting
</success_criteria>

<output>
After completion, create `.planning/quick/5-coherence-fix-verify-and-align-progress-/5-SUMMARY.md`
</output>
