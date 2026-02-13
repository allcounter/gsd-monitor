---
phase: quick-26
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
autonomous: true
requirements: [QUICK-26]
must_haves:
  truths:
    - "PhaseDetailView has no floating xmark.circle.fill overlay button"
    - "A borderedProminent Close button appears in the header HStack after StatusBadge"
    - "Escape key still dismisses the popup"
    - "DetailView overlay still uses ignoresSafeArea on the backdrop for full-window centering"
  artifacts:
    - path: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      provides: "Phase detail popup with header Close button"
      contains: "buttonStyle(.borderedProminent)"
  key_links:
    - from: "Close button"
      to: "onDismiss()"
      via: "Button action"
      pattern: "onDismiss"
---

<objective>
Move the close button from a floating xmark overlay into the header HStack as a borderedProminent button, and verify DetailView overlay centering is intact.

Purpose: The floating close button has had repeated positioning/overlap issues (quick-22 through quick-25). Moving it into the header flow eliminates offset hacks entirely.
Output: Clean header with inline Close button, no floating overlay.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@GSDMonitor/Views/Dashboard/PhaseDetailView.swift
@GSDMonitor/Views/DetailView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace floating close button with header borderedProminent Close button</name>
  <files>GSDMonitor/Views/Dashboard/PhaseDetailView.swift</files>
  <action>
In PhaseDetailView.swift:

1. Replace the outer `ZStack(alignment: .topTrailing)` (line 11) with just the `VStack` that is currently its first child. The VStack (line 12) becomes the top-level container inside `body`.

2. Remove the entire floating close button block (lines 123-136): the Button with xmark.circle.fill, .buttonStyle(.plain), .padding(16), .offset(x: 12, y: -12), .keyboardShortcut(.defaultAction).

3. In the header HStack, AFTER the `StatusBadge(phaseStatus: phase.status)` (line 31), add a Close button:

```swift
Button("Close") {
    onDismiss()
}
.buttonStyle(.borderedProminent)
.controlSize(.regular)
.keyboardShortcut(.defaultAction)
```

4. Keep the hidden Cancel button for Escape key — move it inside the VStack (e.g., as an overlay or at the end of the VStack, hidden). It was previously inside the ZStack; now place it as a `.background` modifier or just inside the VStack before the closing brace:

```swift
.background {
    Button("Cancel") {
        onDismiss()
    }
    .keyboardShortcut(.cancelAction)
    .hidden()
}
```

Apply this .background modifier on the outermost VStack.

5. Keep all existing modifiers on the view: .frame, .clipShape, .shadow — these should now apply to the VStack directly.
  </action>
  <verify>Build the project with `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5` — must show BUILD SUCCEEDED. Grep PhaseDetailView.swift for: no "xmark.circle.fill", no "ZStack(alignment: .topTrailing)", contains "borderedProminent", contains "controlSize(.regular)".</verify>
  <done>PhaseDetailView has no floating close button. Header HStack contains a borderedProminent "Close" button after StatusBadge. Escape key dismissal preserved via hidden Cancel button. Build succeeds.</done>
</task>

<task type="auto">
  <name>Task 2: Verify DetailView overlay centering is correct</name>
  <files>GSDMonitor/Views/DetailView.swift</files>
  <action>
Read DetailView.swift and confirm the phase detail overlay (lines 159-181) has:

1. `Color.black.opacity(0.3).ignoresSafeArea()` — backdrop covers entire window including sidebar
2. The PhaseDetailView is wrapped in `VStack { Spacer() HStack { Spacer() ... Spacer() } Spacer() }` with `.frame(maxWidth: .infinity, maxHeight: .infinity).ignoresSafeArea()` — centers over the full window
3. The overlay is inside the outermost ZStack (line 12), NOT inside `if let project` — so it spans the whole view

This is a verification-only task. If all three points are correct, no changes needed. If any are wrong, fix them to match the pattern above.
  </action>
  <verify>Grep DetailView.swift for `.ignoresSafeArea()` — should appear at least twice (backdrop + centering container). Confirm overlay ZStack is at top level.</verify>
  <done>DetailView overlay confirmed correct: backdrop has ignoresSafeArea, centering container has ignoresSafeArea, overlay is at top-level ZStack scope.</done>
</task>

</tasks>

<verification>
- `xcodebuild` build succeeds
- PhaseDetailView.swift contains `buttonStyle(.borderedProminent)` and `controlSize(.regular)`
- PhaseDetailView.swift does NOT contain `xmark.circle.fill` or `ZStack(alignment: .topTrailing)`
- PhaseDetailView.swift contains `.keyboardShortcut(.cancelAction)` (Escape key preserved)
- DetailView.swift overlay structure unchanged and correct
</verification>

<success_criteria>
The floating xmark close button is gone. A "Close" button with borderedProminent style sits in the header after StatusBadge. Escape key still dismisses. Overlay centers over full window. Build succeeds.
</success_criteria>

<output>
After completion, create `.planning/quick/26-revert-close-button-to-header-borderedpr/26-SUMMARY.md`
</output>
