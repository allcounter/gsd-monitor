---
phase: quick
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Services/RoadmapParser.swift
autonomous: true
must_haves:
  truths:
    - "Phases inside <details> blocks appear in the parsed Roadmap with correct number, name, and status"
    - "Phases from standard ### headings still parse correctly (no regression)"
    - "Phases from checkbox format (- [x] Phase N: Name) are marked as .done"
  artifacts:
    - path: "GSDMonitor/Services/RoadmapParser.swift"
      provides: "HTML details block pre-pass extraction"
      contains: "extractPhasesFromDetailsBlocks"
  key_links:
    - from: "RoadmapParser.parse()"
      to: "extractPhasesFromDetailsBlocks"
      via: "pre-pass before or merge after MarkupWalker"
      pattern: "extractPhasesFromDetailsBlocks"
---

<objective>
Fix RoadmapParser to extract phases from HTML `<details><summary>` blocks.

Purpose: Swift Markdown treats HTML blocks as opaque — it does not parse markdown inside `<details>` tags. Completed milestones in GSD use this format, causing those phases to be invisible (showing "0/0"). A regex-based pre-pass on the raw string will extract these phases before/alongside the Markdown AST walk.

Output: Updated RoadmapParser.swift that handles both formats.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Services/RoadmapParser.swift
@GSDMonitor/Models/Phase.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add regex pre-pass to extract phases from details blocks</name>
  <files>GSDMonitor/Services/RoadmapParser.swift</files>
  <action>
Add a private method `extractPhasesFromDetailsBlocks(_ content: String) -> [Phase]` to `RoadmapParser` (or as a standalone private function).

This method should:

1. Use a regex to find all `<details>...</details>` blocks in the raw markdown string. Use a pattern like `(?s)<details>.*?</details>` (dotMatchesLineSeparators).

2. Within each details block, find all checkbox list items matching the pattern:
   `- [x] Phase (\d+): (.+?)(?:\s*\((\d+)/(\d+)\s*plans?\))?$` (multiline mode)

   Also handle unchecked: `- [ ] Phase (\d+): ...` — these would be `.notStarted` or `.inProgress`.

3. For each match, create a `Phase` with:
   - `number`: captured group 1 (Int)
   - `name`: captured group 2, trimmed, strip any trailing parenthetical like "(2/2 plans)"
   - `status`: `.done` if `[x]`, `.notStarted` if `[ ]`
   - `goal`: empty string (not available in this format)

4. In the `parse(_ content:)` method, call `extractPhasesFromDetailsBlocks(content)` to get HTML-block phases. Then run the existing `RoadmapWalker` for AST-parsed phases. Merge the two lists:
   - Use a dictionary keyed by phase number to deduplicate (AST-parsed phases take priority if they exist for the same number, since they have richer data like goal/dependencies).
   - Sort final list by phase number.

Important: Do NOT remove or change the existing MarkupWalker logic — it handles the standard `### Phase N:` heading format correctly. This is purely additive.
  </action>
  <verify>
Build the project: `cd . && xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -20`

Verify no compiler errors.
  </verify>
  <done>
RoadmapParser.parse() returns phases from both `### Phase N:` headings AND `<details>` checkbox items. Phases inside details blocks have correct number, name, and .done status. No regression on standard heading-based phases.
  </done>
</task>

<task type="auto">
  <name>Task 2: Verify with real ROADMAP.md files containing details blocks</name>
  <files>GSDMonitor/Services/RoadmapParser.swift</files>
  <action>
Find a real ROADMAP.md in ~/Developer that uses the details/summary format and test the parser against it. Run a quick validation:

1. `grep -rl '<details>' ~/Developer/*/ROADMAP.md 2>/dev/null | head -3` to find examples.
2. Read one of those files to confirm the format matches expectations.
3. If any edge cases are found (e.g., emoji in summary line like "completed" checkmark, nested details, phases without plan counts), adjust the regex in Task 1's implementation to handle them.

Also check for an edge case: some ROADMAP.md files may have BOTH `### Phase N:` headings AND the same phases in a details block checklist. Confirm the deduplication logic works (AST phases should win since they have more metadata).
  </action>
  <verify>
Run the app or use a Swift script to parse a real ROADMAP.md and print the phase count. The count should be > 0 for projects that previously showed "0/0".
  </verify>
  <done>
Parser correctly extracts phases from at least one real-world ROADMAP.md that uses the details/summary archival format. Edge cases handled.
  </done>
</task>

</tasks>

<verification>
- Project builds without errors
- Phases from `<details>` blocks are extracted with correct numbers, names, and statuses
- Standard `### Phase N:` parsing is unaffected
- Duplicate phases (same number in both formats) are deduplicated correctly
</verification>

<success_criteria>
Projects using GSD milestone archival format (`<details><summary>` blocks with checkbox phase lists) no longer show "0/0" phases in the sidebar. All completed phases appear with `.done` status.
</success_criteria>

<output>
After completion, create `.planning/quick/1-fix-roadmapparser-to-extract-phases-from/1-SUMMARY.md`
</output>
