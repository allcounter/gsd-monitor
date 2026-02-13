---
type: quick
autonomous: true
files_modified:
  - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
---

<objective>
Enhance the PhaseDetailView popup to show dependencies, success criteria, and full plan objective text.

Purpose: The phase detail sheet currently omits useful data (dependencies, milestones) and truncates plan objectives. This makes the popup more informative.
Output: Updated PhaseDetailView.swift with three changes.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@GSDMonitor/Views/Dashboard/PhaseDetailView.swift
@GSDMonitor/Models/Phase.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add dependencies, success criteria sections and remove lineLimit</name>
  <files>GSDMonitor/Views/Dashboard/PhaseDetailView.swift</files>
  <action>
Make three changes to PhaseDetailView.swift:

1. **Add Dependencies section** — Insert between the Goal section (ends ~line 56) and the Requirements section (starts ~line 59). Only show if `phase.dependencies` is not empty and does not contain only "Nothing (first phase)" or similar no-dependency strings:

```swift
// Dependencies section
if !phase.dependencies.isEmpty && !phase.dependencies.allSatisfy({ $0.lowercased().contains("nothing") }) {
    VStack(alignment: .leading, spacing: 8) {
        Text("Dependencies")
            .font(.headline)

        ForEach(phase.dependencies, id: \.self) { dep in
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 16)
                Text(dep)
                    .font(.body)
                    .foregroundStyle(Theme.fg1)
            }
        }
    }
}
```

2. **Add Success Criteria section** — Insert after Requirements section (after line 70), before Plans section. Only show if `phase.milestones` is not empty:

```swift
// Success Criteria section
if !phase.milestones.isEmpty {
    VStack(alignment: .leading, spacing: 8) {
        Text("Success Criteria")
            .font(.headline)

        ForEach(Array(phase.milestones.enumerated()), id: \.offset) { index, milestone in
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: phase.isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(phase.isComplete ? Theme.statusComplete : Theme.textSecondary)
                    .frame(width: 16)
                Text(milestone)
                    .font(.body)
                    .foregroundStyle(Theme.fg1)
            }
        }
    }
}
```

3. **Remove lineLimit on plan objective** — In PlanCard, remove `.lineLimit(2)` from the plan objective Text (line 122). Keep the `.font(.subheadline)` and `.foregroundStyle(Theme.textSecondary)` modifiers.

All styling uses existing Theme colors — no new colors or styles needed.
  </action>
  <verify>Build succeeds: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5`</verify>
  <done>PhaseDetailView shows Dependencies section (when present and meaningful), Success Criteria section with checkmarks for done phases, and plan objectives display full text without truncation.</done>
</task>

</tasks>

<verification>
- App builds without errors
- Dependencies section appears for phases that have real dependencies
- Dependencies section hidden for phases with only "Nothing" entries
- Success criteria shows numbered milestones with check/circle icons based on phase completion
- Plan objective text is no longer truncated
</verification>

<success_criteria>
PhaseDetailView popup displays all available phase data: goal, dependencies, requirements, success criteria, and plans with full objective text.
</success_criteria>
