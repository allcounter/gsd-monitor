---
phase: quick-14
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Services/ProjectService.swift
  - GSDMonitor/Views/ContentView.swift
autonomous: true
requirements: []
must_haves:
  truths:
    - "Milestones survive reconcilePhaseStatuses and appear in timeline view"
    - "App remembers last selected project across launches"
  artifacts:
    - path: "GSDMonitor/Services/ProjectService.swift"
      provides: "Milestone preservation in reconcilePhaseStatuses"
      contains: "milestones: roadmap.milestones"
    - path: "GSDMonitor/Views/ContentView.swift"
      provides: "UserDefaults persistence for selectedProjectID"
      contains: "UserDefaults"
  key_links:
    - from: "ProjectService.reconcilePhaseStatuses"
      to: "Roadmap.init"
      via: "milestones parameter passthrough"
      pattern: "milestones: roadmap\\.milestones"
    - from: "ContentView.selectedProjectID"
      to: "UserDefaults"
      via: "onChange persist + .task restore"
      pattern: "UserDefaults\\.standard"
---

<objective>
Fix two bugs: (1) reconcilePhaseStatuses drops milestones when constructing new Roadmap, (2) app forgets selected project on relaunch.

Purpose: Milestones disappear from timeline after phase reconciliation; user must re-select project every launch.
Output: Both bugs fixed in ProjectService.swift and ContentView.swift.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@GSDMonitor/Services/ProjectService.swift
@GSDMonitor/Views/ContentView.swift
@GSDMonitor/Models/Roadmap.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix milestone loss in reconcilePhaseStatuses</name>
  <files>GSDMonitor/Services/ProjectService.swift</files>
  <action>
In ProjectService.swift, find the reconcilePhaseStatuses method. At line 325, the return statement creates a new Roadmap without passing milestones:

```swift
return Roadmap(projectName: roadmap.projectName, phases: updatedPhases)
```

Change to:

```swift
return Roadmap(projectName: roadmap.projectName, phases: updatedPhases, milestones: roadmap.milestones)
```

This is a one-line fix. The Roadmap init already accepts `milestones` with a default of `[]`, so the current code silently drops them.
  </action>
  <verify>Build succeeds: `cd . && xcodebuild -scheme GSDMonitor -configuration Debug build 2>&1 | tail -5` shows BUILD SUCCEEDED. Grep confirms: `grep "milestones: roadmap.milestones" GSDMonitor/Services/ProjectService.swift`</verify>
  <done>reconcilePhaseStatuses preserves milestones from original roadmap when creating updated Roadmap</done>
</task>

<task type="auto">
  <name>Task 2: Remember last selected project across launches</name>
  <files>GSDMonitor/Views/ContentView.swift</files>
  <action>
In ContentView.swift, add UserDefaults persistence for selectedProjectID. Follow the existing pattern from Phase 5 decision: use computed property + UserDefaults (not @AppStorage, which is incompatible with @Observable pattern used elsewhere).

1. Add a private static key constant at top of struct:
```swift
private static let selectedProjectKey = "selectedProjectID"
```

2. Add an .onChange(of: selectedProjectID) modifier to persist selection:
```swift
.onChange(of: selectedProjectID) { _, newValue in
    if let id = newValue {
        UserDefaults.standard.set(id.uuidString, forKey: ContentView.selectedProjectKey)
    } else {
        UserDefaults.standard.removeObject(forKey: ContentView.selectedProjectKey)
    }
}
```

3. In the existing .task block, BEFORE the `if selectedProjectID == nil` auto-select logic, restore from UserDefaults:
```swift
// Restore last selected project
if let savedID = UserDefaults.standard.string(forKey: ContentView.selectedProjectKey),
   let uuid = UUID(uuidString: savedID),
   projectService.projects.contains(where: { $0.id == uuid }) {
    selectedProjectID = uuid
}
```

The `.contains(where:)` check ensures we don't restore a stale ID for a project that no longer exists. The existing auto-select fallback (`if selectedProjectID == nil`) still fires if the saved project is gone.

Note: Use UserDefaults directly (not @AppStorage) per project convention from Phase 5 decisions.
  </action>
  <verify>Build succeeds. Grep confirms UserDefaults usage: `grep "UserDefaults" GSDMonitor/Views/ContentView.swift`</verify>
  <done>Selected project ID persists to UserDefaults on change and restores on app launch; falls back to auto-select if saved project no longer exists</done>
</task>

</tasks>

<verification>
- `xcodebuild -scheme GSDMonitor -configuration Debug build` succeeds
- reconcilePhaseStatuses return includes `milestones: roadmap.milestones`
- ContentView persists and restores selectedProjectID via UserDefaults
</verification>

<success_criteria>
1. Milestones are preserved through phase status reconciliation (no data loss)
2. App remembers and restores last selected project on relaunch
3. Graceful fallback to auto-select when saved project ID is stale
</success_criteria>

<output>
After completion, create `.planning/quick/14-fix-milestone-loss-in-reconcilephasestat/14-SUMMARY.md`
</output>
