---
phase: quick
plan: 2
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Services/ProjectService.swift
autonomous: true
must_haves:
  truths:
    - "Plans with a matching SUMMARY.md show status 'done' in the app"
    - "Plans without a SUMMARY.md continue to show status 'pending'"
    - "All tasks within a completed plan show status 'done'"
  artifacts:
    - path: "GSDMonitor/Services/ProjectService.swift"
      provides: "SUMMARY.md existence check in parsePlans()"
      contains: "SUMMARY.md"
  key_links:
    - from: "GSDMonitor/Services/ProjectService.swift"
      to: "GSDMonitor/Models/Plan.swift"
      via: "Plan init with .done status"
      pattern: "status:\\s*\\.done"
---

<objective>
Fix plan status parsing so plans with a SUMMARY.md file show as "done" instead of always "pending".

Purpose: The app correctly shows phase-level completion from ROADMAP.md, but individual plans always display as "pending" because PlanParser hardcodes `.pending` and nobody checks for SUMMARY.md existence.
Output: Updated ProjectService.parsePlans() that derives plan/task status from SUMMARY.md presence.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Services/ProjectService.swift
@GSDMonitor/Services/PlanParser.swift
@GSDMonitor/Models/Plan.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add SUMMARY.md existence check to parsePlans and set done status</name>
  <files>GSDMonitor/Services/ProjectService.swift</files>
  <action>
In `parsePlans(from:)` method (line ~296), after successfully parsing a PLAN.md file into a `Plan`, check if a corresponding SUMMARY.md exists in the same directory:

1. Derive the SUMMARY filename by replacing "-PLAN.md" with "-SUMMARY.md" in `fileURL.lastPathComponent`
2. Build the SUMMARY URL: `fileURL.deletingLastPathComponent().appendingPathComponent(summaryFilename)`
3. Check if that file exists using `FileManager.default.fileExists(atPath:)`
4. If SUMMARY exists, create a new Plan with `.done` status and all tasks mapped to `.done`:
   ```swift
   let summaryFilename = fileURL.lastPathComponent.replacingOccurrences(of: "-PLAN.md", with: "-SUMMARY.md")
   let summaryURL = fileURL.deletingLastPathComponent().appendingPathComponent(summaryFilename)
   let hasSummary = FileManager.default.fileExists(atPath: summaryURL.path)

   if hasSummary {
       let donePlan = Plan(
           phaseNumber: plan.phaseNumber,
           planNumber: plan.planNumber,
           objective: plan.objective,
           tasks: plan.tasks.map { Task(name: $0.name, type: $0.type, status: .done) },
           status: .done
       )
       plans.append(donePlan)
   } else {
       plans.append(plan)
   }
   ```

Do NOT modify PlanParser.swift -- keep the change isolated to ProjectService where filesystem access is natural.
  </action>
  <verify>
Build the project with Cmd+B (or `xcodebuild build` from CLI). Verify no compile errors. Then visually confirm in the app that completed phases show their plans as "done" (green checkmarks or equivalent) while incomplete phases still show "pending".
  </verify>
  <done>Plans with a corresponding SUMMARY.md file display as "done" with all tasks marked "done". Plans without SUMMARY.md remain "pending".</done>
</task>

</tasks>

<verification>
- Build succeeds without errors or warnings
- Open the app, select a project with completed phases (e.g., phases 1-8 of gsd-monitor itself)
- Plans within completed phases show "done" status
- Plans within incomplete/future phases show "pending" status
</verification>

<success_criteria>
Plan and task status correctly reflects SUMMARY.md existence across all monitored projects.
</success_criteria>

<output>
After completion, create `.planning/quick/2-fix-plan-status-parsing-set-plan-and-tas/2-SUMMARY.md`
</output>
