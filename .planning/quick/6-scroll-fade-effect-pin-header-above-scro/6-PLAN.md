---
phase: quick-6
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Views/DetailView.swift
autonomous: true
must_haves:
  truths:
    - "Project header and Overall Progress bar stay pinned at top, never scroll"
    - "Phase cards scroll independently beneath the pinned header"
    - "Phase cards fade out as they approach the top edge of the scroll area"
  artifacts:
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Pinned header with scrollable masked phase list"
  key_links:
    - from: "ScrollView"
      to: "LinearGradient mask"
      via: ".mask() modifier on ScrollView"
      pattern: "mask.*LinearGradient"
---

<objective>
Pin the project header and Overall Progress section above the scrolling phase list, and add a top-edge fade mask so phase cards visually disappear under the header.

Purpose: Better visual hierarchy — the header stays visible while phases scroll with a polished fade effect.
Output: Updated DetailView.swift with pinned header and fade-masked ScrollView.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Theme/Theme.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Pin header above ScrollView and add fade mask</name>
  <files>GSDMonitor/Views/DetailView.swift</files>
  <action>
Restructure the `if let project = selectedProject` branch in DetailView.swift:

1. Replace the current single `ScrollView` wrapping everything with a `VStack(spacing: 0)` that contains two sections:

   **Section A — Pinned header (outside ScrollView):**
   - The project header HStack (project name, phase/plan text, Open in Editor button) — lines 15-37
   - The Overall Progress VStack (headline, percentage, progress bar) — lines 40-57
   - Wrap both in a `VStack(alignment: .leading, spacing: 24)` with `.padding()` applied
   - Add `.background(Theme.bg0)` to ensure the pinned header has an opaque background matching the app theme

   **Section B — Scrollable phases (inside ScrollView):**
   - Only the "Roadmap phases" section (lines 60-79) stays inside the ScrollView
   - Keep the existing `VStack(alignment: .leading, spacing: 16)` with the "Phases" headline and ForEach
   - Apply `.padding([.horizontal, .bottom])` to the inner VStack (no top padding — the fade handles the visual gap)
   - Add `.padding(.top, 8)` for a small gap

2. Add a fade mask to the ScrollView:
   ```swift
   .mask(
       VStack(spacing: 0) {
           LinearGradient(
               colors: [.clear, .black],
               startPoint: .top,
               endPoint: .bottom
           )
           .frame(height: 20)

           Color.black // fully opaque for the rest
       }
   )
   ```
   This creates a 20pt fade zone at the top where cards dissolve as they scroll up.

3. Keep `.sheet(item: $selectedPhase)` attached to the outer VStack (or the enclosing container), not the ScrollView.

4. Keep `.frame(maxWidth: .infinity, alignment: .leading)` on the scrollable content.

5. Do NOT change the `else` branch (ContentUnavailableView), helper functions, or previews.
  </action>
  <verify>
Build the project with `xcodebuild -scheme GSDMonitor -destination 'platform=macOS' build 2>&1 | tail -5` — should compile with no errors. Visually: header stays fixed, phases scroll, cards fade at top edge.
  </verify>
  <done>
Project header and Overall Progress are pinned above the scroll area. Phase cards scroll independently with a fade-out effect at the top edge. App compiles and runs correctly.
  </done>
</task>

</tasks>

<verification>
- `xcodebuild` builds without errors
- Header (project name, phase info, progress bar) does not scroll
- Phase cards scroll and fade out at the top edge of the scroll area
- Background color is consistent (Theme.bg0) with no visual seams
</verification>

<success_criteria>
- Pinned header stays visible at all times during scroll
- Phase cards fade smoothly under the header when scrolling
- No visual artifacts or layout regressions
</success_criteria>

<output>
After completion, create `.planning/quick/6-scroll-fade-effect-pin-header-above-scro/6-SUMMARY.md`
</output>
