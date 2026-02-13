---
phase: quick-30
plan: 30
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Services/CommandRunnerService.swift
  - GSDMonitor/Services/CommandHistoryStore.swift
  - GSDMonitor/Services/NotificationService.swift
  - GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
  - GSDMonitor/Views/DetailView.swift
  - .planning/phases/14-output-panel/14-VERIFICATION.md
  - .planning/phases/15-command-triggering-integration/15-03-SUMMARY.md
autonomous: true
must_haves:
  truths:
    - "No dead code methods exist in CommandRunnerService or NotificationService"
    - "MilestoneTimelineView has no unused parameters"
    - "Phase 14 VERIFICATION.md correctly reflects that OUTP-06 says 5000 lines matching implementation"
    - "Phase 15-03 SUMMARY.md declares TRIG-04 and SAFE-02 in requirements-completed frontmatter"
  artifacts:
    - path: "GSDMonitor/Services/CommandRunnerService.swift"
      provides: "Command runner without dead removeQueuedCommand method"
      contains: "cancelRunningCommand"
    - path: "GSDMonitor/Services/CommandHistoryStore.swift"
      provides: "History store without dead removeQueuedCommand method"
    - path: "GSDMonitor/Services/NotificationService.swift"
      provides: "Notification service without dead sendCommandFailureNotification method"
    - path: "GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift"
      provides: "Timeline view without unused projectName parameter"
    - path: ".planning/phases/14-output-panel/14-VERIFICATION.md"
      provides: "Corrected verification doc — OUTP-06 marked VERIFIED not PARTIAL"
    - path: ".planning/phases/15-command-triggering-integration/15-03-SUMMARY.md"
      provides: "Summary with requirements-completed frontmatter"
  key_links:
    - from: "GSDMonitor/Views/DetailView.swift"
      to: "MilestoneTimelineView"
      via: "call site without projectName param"
      pattern: "MilestoneTimelineView\\(\\s*project:"
---

<objective>
Clean up 6 tech debt items identified in the v1.2 milestone audit.

Purpose: Remove dead code, fix documentation inaccuracies, and clean unused parameters before closing the v1.2 milestone.
Output: Cleaner codebase with no dead methods, accurate verification docs, and complete summary frontmatter.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/v1.2-MILESTONE-AUDIT.md
@GSDMonitor/Services/CommandRunnerService.swift
@GSDMonitor/Services/CommandHistoryStore.swift
@GSDMonitor/Services/NotificationService.swift
@GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
@GSDMonitor/Views/DetailView.swift
@.planning/phases/14-output-panel/14-VERIFICATION.md
@.planning/phases/15-command-triggering-integration/15-03-SUMMARY.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Remove dead code methods and unused parameter</name>
  <files>
    GSDMonitor/Services/CommandRunnerService.swift
    GSDMonitor/Services/CommandHistoryStore.swift
    GSDMonitor/Services/NotificationService.swift
    GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift
    GSDMonitor/Views/DetailView.swift
  </files>
  <action>
1. In `CommandRunnerService.swift`: Delete the entire `removeQueuedCommand(id:forProject:)` method (lines ~78-89, including the doc comment above it). No callers exist.

2. In `CommandHistoryStore.swift`: Delete the entire `removeQueuedCommand(id:)` method (lines ~69-76, including the doc comment above it). The only caller was `CommandRunnerService.removeQueuedCommand` which is also being deleted.

3. In `NotificationService.swift`: Delete the entire `sendCommandFailureNotification(projectName:command:exitCode:)` method (lines 96-115). This is dead code — OutputPanelView uses inline UNUserNotificationCenter directly instead.

4. In `MilestoneTimelineView.swift`: Remove the `var projectName: String = ""` property (line 5). It is never referenced in the view body.

5. In `DetailView.swift`: Update the MilestoneTimelineView call site (around line 137-141) to remove the `projectName: projectName` argument. The call should become:
```swift
MilestoneTimelineView(
    project: project,
    selectedMilestone: $selectedMilestone
)
```

6. Also update the preview struct in MilestoneTimelineView.swift (line 79-82) — it already does not pass projectName, so no change needed there. Just verify it still compiles.
  </action>
  <verify>
Build succeeds: `cd . && swift build 2>&1 | tail -5`

Grep confirms no remaining references:
- `grep -r "removeQueuedCommand" GSDMonitor/` returns nothing
- `grep -r "sendCommandFailureNotification" GSDMonitor/` returns nothing
- `grep -r "projectName" GSDMonitor/Views/Dashboard/MilestoneTimelineView.swift` returns nothing
  </verify>
  <done>
Three dead code methods removed (removeQueuedCommand x2, sendCommandFailureNotification x1). Unused projectName parameter removed from MilestoneTimelineView and its call site. Project builds cleanly.
  </done>
</task>

<task type="auto">
  <name>Task 2: Fix documentation inaccuracies in VERIFICATION.md and SUMMARY.md</name>
  <files>
    .planning/phases/14-output-panel/14-VERIFICATION.md
    .planning/phases/15-command-triggering-integration/15-03-SUMMARY.md
  </files>
  <action>
1. In `14-VERIFICATION.md` frontmatter:
   - Change `status: gaps_found` to `status: passed`
   - Change `score: 10/11 must-haves verified` to `score: 11/11 must-haves verified`
   - Remove the entire `gaps:` block (lines 7-15) — the gap was a false positive (REQUIREMENTS.md says 5000, implementation says 5000, they match)
   - Update `re_verification: false` to `re_verification: true` (this is a re-verification correcting the false gap)

2. In `14-VERIFICATION.md` body:
   - In the Observable Truths table row #4 (line 55): Change status from `PARTIAL` to `VERIFIED` and update evidence to: "Implementation uses 5000 (OutputPanelView.swift:136-137), matching REQUIREMENTS.md OUTP-06 which specifies 5000 lines"
   - Update `**Score:** 10/11 truths verified (1 partial — buffer size discrepancy)` to `**Score:** 11/11 truths verified`
   - In Requirements Coverage table, OUTP-06 row (line 107): Change status from `BLOCKED` to `SATISFIED` and update description column from "(2000 lines)" to "(5000 lines)" and update evidence to: "REQUIREMENTS.md states 5000 lines; implementation matches at 5000. Originally flagged as discrepancy but REQUIREMENTS.md was already correct."
   - In Anti-Patterns Found table (line 119): Remove the row about buffer cap discrepancy (leave "No TODO/FIXME..." text)
   - In Gaps Summary section (lines 165-177): Replace content with "No gaps. All 11 must-haves verified. The OUTP-06 buffer size was originally flagged as a discrepancy (claiming REQUIREMENTS.md said 2000), but REQUIREMENTS.md actually says 5000, matching the implementation."
   - Update the status line near the top of the body (line 41): Change "gaps_found (1 gap: buffer size discrepancy...)" to "passed (all must-haves verified; original OUTP-06 gap was a false positive)"

3. In `15-03-SUMMARY.md` frontmatter: Add the missing field after the existing `tags:` line (or after `subsystem:`):
```yaml
requirements-completed: [TRIG-04, SAFE-02]
```
  </action>
  <verify>
Check frontmatter updates:
- `grep "status: passed" .planning/phases/14-output-panel/14-VERIFICATION.md`
- `grep "11/11" .planning/phases/14-output-panel/14-VERIFICATION.md`
- `grep "requirements-completed" .planning/phases/15-command-triggering-integration/15-03-SUMMARY.md` shows `[TRIG-04, SAFE-02]`
- `grep "BLOCKED" .planning/phases/14-output-panel/14-VERIFICATION.md` returns nothing
- `grep "PARTIAL" .planning/phases/14-output-panel/14-VERIFICATION.md` returns nothing
  </verify>
  <done>
Phase 14 VERIFICATION.md corrected: false OUTP-06 gap removed, status changed to passed, score 11/11. Phase 15 15-03-SUMMARY.md updated with requirements-completed: [TRIG-04, SAFE-02].
  </done>
</task>

</tasks>

<verification>
1. `swift build` succeeds with no errors
2. No references to `removeQueuedCommand` in GSDMonitor/
3. No references to `sendCommandFailureNotification` in GSDMonitor/
4. No `projectName` property in MilestoneTimelineView.swift
5. 14-VERIFICATION.md shows status: passed, score 11/11, no PARTIAL or BLOCKED entries
6. 15-03-SUMMARY.md has requirements-completed: [TRIG-04, SAFE-02]
</verification>

<success_criteria>
All 6 tech debt items from v1.2 milestone audit resolved (item 6 — system ProgressView — was already fixed in quick task 21, so 5 items actively addressed). Build passes. No dead code. Accurate documentation.
</success_criteria>

<output>
After completion, create `.planning/quick/30-clean-up-v1-2-tech-debt-items-from-miles/30-SUMMARY.md`
</output>
