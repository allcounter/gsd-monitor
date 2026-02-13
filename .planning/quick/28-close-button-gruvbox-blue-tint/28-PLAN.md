---
phase: quick
plan: 28
type: execute
wave: 1
depends_on: []
files_modified: [GSDMonitor/Views/Dashboard/PhaseDetailView.swift]
autonomous: true
requirements: []
---

<objective>
Change the Close button in PhaseDetailView.swift to use Gruvbox blue tint instead of default accent blue.

Purpose: Visual consistency with the Gruvbox theme — the Close button should use Theme.blue (#458588) for a cohesive color palette throughout the UI.

Output: Updated PhaseDetailView.swift with `.tint(Theme.blue)` applied to the Close button.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@./GSDMonitor/Views/Dashboard/PhaseDetailView.swift
@./GSDMonitor/Theme/Theme.swift
</context>

<tasks>

<task type="auto">
  <name>Add Gruvbox blue tint to Close button</name>
  <files>GSDMonitor/Views/Dashboard/PhaseDetailView.swift</files>
  <action>
    In PhaseDetailView.swift, locate the Close button on lines 32-37. Add `.tint(Theme.blue)` modifier after `.controlSize(.regular)` on line 36, before `.keyboardShortcut(.defaultAction)`.

    Current code:
    ```
    Button("Close") {
        dismiss()
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.regular)
    .keyboardShortcut(.defaultAction)
    ```

    Update to:
    ```
    Button("Close") {
        dismiss()
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.regular)
    .tint(Theme.blue)
    .keyboardShortcut(.defaultAction)
    ```

    Theme.blue is the Gruvbox blue color (#458588) already defined in Theme.swift.
  </action>
  <verify>
    1. Open the file and confirm the `.tint(Theme.blue)` modifier is present on the Close button
    2. Build the project: `xcodebuild -scheme GSDMonitor -configuration Debug 2>&1 | head -20` (confirm no build errors)
    3. Verify file has no syntax errors by checking Xcode's swift syntax validator
  </verify>
  <done>
    Close button now renders with Gruvbox blue tint (Theme.blue color) instead of default accent color. Build succeeds without errors.
  </done>
</task>

</tasks>

<verification>
Verify the change by:
1. Confirming the source file shows `.tint(Theme.blue)` on the Close button
2. Building the project successfully without errors
3. (If running app) Opening a phase to see the Close button now renders in blue
</verification>

<success_criteria>
- Close button has `.tint(Theme.blue)` modifier applied
- Project builds successfully without errors or warnings
- File syntax is valid
</success_criteria>

<output>
After completion, create `.planning/quick/28-close-button-gruvbox-blue-tint/28-SUMMARY.md`
</output>
