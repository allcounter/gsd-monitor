---
phase: quick-34
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/ContentView.swift
  - GSDMonitor/Views/DetailView.swift
autonomous: true
must_haves:
  truths:
    - "Enter on phase result opens PhaseDetailView sheet directly"
    - "Enter on plan result navigates to project and scrolls to parent phase"
    - "Enter on requirement result navigates to project"
    - "Enter on project result navigates to project (unchanged)"
  artifacts:
    - path: "GSDMonitor/Views/ContentView.swift"
      provides: "Deep navigation routing by SearchResultType"
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "External phase selection binding + scroll-to-phase"
  key_links:
    - from: "ContentView.swift"
      to: "DetailView.swift"
      via: "selectedPhase binding and scrollToPhase binding"
      pattern: "selectedPhase|scrollToPhase"
---

<objective>
Add deep navigation to the Cmd+K command palette so Enter on non-project results navigates deeper than just selecting the project.

Purpose: Phase results should open PhaseDetailView as a sheet. Plan results should navigate to the project and scroll to the relevant phase. Requirements and projects just navigate to the project.
Output: Updated ContentView.swift and DetailView.swift with deep navigation wiring.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/ContentView.swift
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Views/CommandPalette/CommandPaletteView.swift
@GSDMonitor/Services/SearchService.swift
@GSDMonitor/Views/Dashboard/PhaseDetailView.swift
@GSDMonitor/Models/Phase.swift
@GSDMonitor/Models/Plan.swift
</context>

<interfaces>
<!-- Key types and contracts the executor needs -->

From SearchService.swift:
```swift
enum SearchResultType {
    case project
    case phase(Phase)
    case requirement(Requirement)
    case plan(Plan)
}

struct SearchResult: Identifiable {
    let id: UUID
    let projectID: UUID
    let projectName: String
    let title: String
    let subtitle: String
    let type: SearchResultType
    let score: Int
}
```

From DetailView.swift (current internal state that needs lifting):
```swift
@SwiftUI.State private var selectedPhase: Phase?
// Used by:
.sheet(item: $selectedPhase) { phase in
    PhaseDetailView(phase: phase, project: project)
}
// And triggered by PhaseCardView tap:
.onTapGesture { selectedPhase = phase }
```

From ContentView.swift (current handler):
```swift
private func handleCommandPaletteSelection(_ result: SearchResult) {
    selectedProjectID = result.projectID
    withAnimation(.easeOut(duration: 0.15)) {
        showCommandPalette = false
    }
}
```

From Plan.swift:
```swift
struct Plan: Identifiable, Codable, Sendable {
    let phaseNumber: Int
    let planNumber: Int
}
```
</interfaces>

<tasks>

<task type="auto">
  <name>Task 1: Lift phase selection state and add scroll-to-phase to DetailView</name>
  <files>GSDMonitor/Views/DetailView.swift</files>
  <action>
  1. Change `@SwiftUI.State private var selectedPhase: Phase?` to `@Binding var selectedPhase: Phase?` so ContentView can set it externally.
  2. Add `@Binding var scrollToPhaseNumber: Int?` property for scroll-to-phase navigation from plan results.
  3. Update the `init` / parameter list to accept these bindings. Keep `selectedMilestone` as internal `@State`.
  4. Wrap the phases `ScrollView` content in a `ScrollViewReader`. Each `PhaseCardView` already has an implicit id from `ForEach` — add explicit `.id(phase.id)` on each PhaseCardView.
  5. Add `.onChange(of: scrollToPhaseNumber)` that:
     - Finds the matching phase by number in `roadmap.phases`
     - Finds the milestone containing that phase number and sets `selectedMilestone` to it (so the phase is visible in the filtered list)
     - If no milestone contains it, set `selectedMilestone = nil` (show all)
     - Scrolls to the phase using `proxy.scrollTo(phase.id, anchor: .top)` with animation
     - Resets `scrollToPhaseNumber = nil` after scrolling
  6. Update both Preview structs to use `.constant(nil)` for the new bindings.
  </action>
  <verify>Project builds with `swift build 2>&1 | tail -5` — no errors related to DetailView</verify>
  <done>DetailView accepts external selectedPhase and scrollToPhaseNumber bindings, scroll-to-phase works via onChange</done>
</task>

<task type="auto">
  <name>Task 2: Wire deep navigation in ContentView based on SearchResultType</name>
  <files>GSDMonitor/Views/ContentView.swift</files>
  <action>
  1. Add two new `@SwiftUI.State` properties:
     - `@SwiftUI.State private var selectedPhase: Phase? = nil`
     - `@SwiftUI.State private var scrollToPhaseNumber: Int? = nil`
  2. Pass these as bindings to `DetailView`:
     ```swift
     DetailView(
         selectedProject: ...,
         projectName: ...,
         projectColorIndex: ...,
         selectedPhase: $selectedPhase,
         scrollToPhaseNumber: $scrollToPhaseNumber
     )
     ```
  3. Update `handleCommandPaletteSelection` to route by type:
     ```swift
     private func handleCommandPaletteSelection(_ result: SearchResult) {
         // Always navigate to the project first
         selectedProjectID = result.projectID

         // Reset deep navigation state
         selectedPhase = nil
         scrollToPhaseNumber = nil

         // Deep navigate based on result type
         switch result.type {
         case .project:
             break // Just navigate to project
         case .phase(let phase):
             // Open PhaseDetailView sheet after a brief delay to let project load
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                 selectedPhase = phase
             }
         case .plan(let plan):
             // Scroll to the parent phase
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                 scrollToPhaseNumber = plan.phaseNumber
             }
         case .requirement:
             break // Just navigate to project
         }

         withAnimation(.easeOut(duration: 0.15)) {
             showCommandPalette = false
         }
     }
     ```
  4. Also reset `selectedPhase` and `scrollToPhaseNumber` in `onChange(of: selectedProjectID)` when project changes via sidebar (not via command palette) to avoid stale state. Do this by checking: if the new selectedProjectID differs from the previous deep-nav target, reset both to nil. Actually simpler: just reset in onChange — the command palette handler sets them AFTER setting projectID via asyncAfter, so the onChange reset happens first, then the delayed set applies correctly.
  </action>
  <verify>Build and run with `makeapp`. Open Cmd+K, search for a phase name, press Enter — PhaseDetailView sheet should open. Search for a plan, press Enter — should scroll to the phase.</verify>
  <done>Cmd+K Enter on phase opens PhaseDetailView sheet. Enter on plan scrolls to parent phase. Enter on project/requirement navigates to project.</done>
</task>

</tasks>

<verification>
- `swift build` compiles without errors
- Cmd+K search for a phase name -> Enter -> project selected AND PhaseDetailView sheet opens
- Cmd+K search for a plan objective -> Enter -> project selected AND scrolls to parent phase
- Cmd+K search for a project -> Enter -> project selected (unchanged behavior)
- Cmd+K search for a requirement -> Enter -> project selected (unchanged behavior)
- PhaseCardView tap in DetailView still opens PhaseDetailView sheet (existing behavior preserved)
</verification>

<success_criteria>
All four SearchResultType cases produce the correct deep navigation behavior. Existing PhaseCardView tap-to-open-sheet behavior is preserved.
</success_criteria>

<output>
After completion, create `.planning/quick/34-cmd-k-deep-navigation-enter-p-phase-bner/34-SUMMARY.md`
</output>
