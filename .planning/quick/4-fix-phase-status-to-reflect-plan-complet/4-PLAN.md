---
phase: quick-04
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Services/ProjectService.swift
autonomous: true
must_haves:
  truths:
    - "Phase card shows 'done' when all its plans have SUMMARY.md files (status: done)"
    - "Phase card shows 'in-progress' when some but not all plans are done"
    - "Phase card shows 'not-started' when no plans exist or none are done"
  artifacts:
    - path: "GSDMonitor/Services/ProjectService.swift"
      provides: "Phase status reconciliation logic in parseProject()"
      contains: "reconcilePhaseStatuses"
  key_links:
    - from: "ProjectService.parseProject()"
      to: "Roadmap.phases[].status"
      via: "Plan grouping by phaseNumber and status aggregation"
      pattern: "reconcilePhaseStatuses"
---

<objective>
Fix phase status display by reconciling plan completion data with roadmap phase statuses.

Purpose: Phase cards currently show "not started" even when all plans within that phase are marked "done" (via SUMMARY.md existence). The roadmap parser only reads checkbox state from ROADMAP.md text, which is never updated by the workflow. Plan status IS correctly derived (quick task 2 fixed this). We need to propagate plan-level completion UP to phase-level status.

Output: Updated ProjectService.swift with phase status reconciliation.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Services/ProjectService.swift
@GSDMonitor/Models/Phase.swift
@GSDMonitor/Models/Plan.swift
@GSDMonitor/Models/Roadmap.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add phase status reconciliation in parseProject()</name>
  <files>GSDMonitor/Services/ProjectService.swift</files>
  <action>
Add a private helper method `reconcilePhaseStatuses` to ProjectService that takes a Roadmap and [Plan] and returns a new Roadmap with corrected phase statuses.

Logic for `reconcilePhaseStatuses(roadmap: Roadmap, plans: [Plan]) -> Roadmap`:

1. Group plans by `phaseNumber` into a dictionary: `Dictionary(grouping: plans, by: \.phaseNumber)`
2. Map over `roadmap.phases`, creating new Phase instances with corrected status:
   - Get plans for this phase: `plansByPhase[phase.number]`
   - If no plans exist for this phase, keep the original `phase.status` unchanged
   - If plans exist:
     - If ALL plans have `.done` status -> new status is `.done`
     - If ANY plan has `.done` or `.inProgress` status -> new status is `.inProgress`
     - Otherwise -> keep original `phase.status`
   - Create new Phase with same id, number, name, goal, dependencies, requirements, milestones but updated status
3. Return new `Roadmap(projectName: roadmap.projectName, phases: updatedPhases)`

Note: Roadmap uses `let` properties so we need Roadmap to support init with all fields. Check if Roadmap has a manual init -- if not, since it's a simple struct with Codable, we can use the memberwise-style approach or add an init.

Then in `parseProject()`, after line 280 (`let plans = parsePlans(...)`) and before the return statement, add:

```swift
// Reconcile phase statuses based on actual plan completion
let reconciledRoadmap = roadmap.map { reconcilePhaseStatuses(roadmap: $0, plans: plans) }
```

And update the return statement to use `reconciledRoadmap` instead of `roadmap`:

```swift
return Project(
    name: reconciledRoadmap?.projectName ?? roadmap?.projectName ?? url.lastPathComponent,
    path: url,
    roadmap: reconciledRoadmap ?? roadmap,
    ...
)
```

Actually simpler: just use `reconciledRoadmap` for name too since it preserves projectName:

```swift
let finalRoadmap = roadmap.map { reconcilePhaseStatuses(roadmap: $0, plans: plans) } ?? roadmap
let name = finalRoadmap?.projectName ?? url.lastPathComponent
```

Then pass `finalRoadmap` to the Project init for `roadmap:`.
  </action>
  <verify>
Build the project with Cmd+B (or `xcodebuild build` from CLI). Verify no compiler errors. Then run the app, open a project that has completed phases with SUMMARY.md files, and confirm the phase card shows the correct status (done/in-progress) instead of "not started".

CLI build check: `cd . && xcodebuild build -scheme GSDMonitor -destination 'platform=macOS' 2>&1 | tail -5`
  </verify>
  <done>
Phase cards display correct status: "done" when all plans in that phase have SUMMARY.md (plan status = done), "in-progress" when some plans are done, and original roadmap status when no plans exist for that phase. Build succeeds with no errors.
  </done>
</task>

</tasks>

<verification>
- Project builds without errors
- Phase with all plans completed shows "done" status
- Phase with some plans completed shows "in-progress" status
- Phase with no plans retains its original roadmap-parsed status
</verification>

<success_criteria>
Phase status in the UI accurately reflects the completion state of its child plans rather than only relying on ROADMAP.md checkbox parsing.
</success_criteria>

<output>
After completion, create `.planning/quick/4-fix-phase-status-to-reflect-plan-complet/4-SUMMARY.md`
</output>
