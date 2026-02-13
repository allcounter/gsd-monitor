---
phase: quick
plan: 3
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Models/Project.swift
  - GSDMonitor/Services/ProjectService.swift
autonomous: true
must_haves:
  truths:
    - "Selecting a project in the sidebar survives FSEvents-triggered reloads"
    - "Same project directory always produces the same UUID"
    - "Codable decoding still reads the stored id from JSON unchanged"
  artifacts:
    - path: "GSDMonitor/Models/Project.swift"
      provides: "Deterministic UUID generation from path"
      contains: "deterministicID"
    - path: "GSDMonitor/Services/ProjectService.swift"
      provides: "Uses deterministic ID when creating Project instances"
      contains: "deterministicID"
  key_links:
    - from: "GSDMonitor/Services/ProjectService.swift"
      to: "GSDMonitor/Models/Project.swift"
      via: "Project.deterministicID(from:) called in parseProject"
      pattern: "Project\\.deterministicID"
---

<objective>
Fix project selection being lost when FSEvents triggers a reload.

Purpose: When file changes trigger `loadProjects()` or `reloadProject(at:)`, new `Project` instances get random UUIDs via `UUID()`, invalidating `selectedProjectID` in ContentView. By deriving a deterministic UUID from the project path, the same directory always maps to the same ID, keeping sidebar selection stable.

Output: Modified Project.swift and ProjectService.swift
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Models/Project.swift
@GSDMonitor/Services/ProjectService.swift
@GSDMonitor/Views/ContentView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add deterministic UUID generation and wire it into project parsing</name>
  <files>GSDMonitor/Models/Project.swift, GSDMonitor/Services/ProjectService.swift</files>
  <action>
In Project.swift:
1. Add `import CryptoKit` at the top.
2. Add a static method to Project:
```swift
static func deterministicID(from path: URL) -> UUID {
    let hash = SHA256.hash(data: Data(path.path.utf8))
    let bytes = Array(hash)
    // Build a UUID from the first 16 bytes of the SHA-256 hash
    let uuid = UUID(uuid: (
        bytes[0], bytes[1], bytes[2], bytes[3],
        bytes[4], bytes[5], bytes[6], bytes[7],
        bytes[8], bytes[9], bytes[10], bytes[11],
        bytes[12], bytes[13], bytes[14], bytes[15]
    ))
    return uuid
}
```
3. Change the manual init default from `id: UUID = UUID()` to `id: UUID? = nil`, and inside the init body set `self.id = id ?? Project.deterministicID(from: path)`. This way callers that don't pass an id get a path-based deterministic one, and the Codable `init(from decoder:)` is completely untouched (it reads id from JSON).

In ProjectService.swift:
4. In `parseProject(at:scanSource:)` (line ~285), the `Project(name:path:...)` call currently omits `id:`, so it will now automatically get a deterministic UUID from path via the updated default. No changes needed to ProjectService unless the compiler requires it -- but verify the call compiles with the new optional-id signature.

Important: Do NOT touch `init(from decoder:)` -- that codepath must continue decoding the stored UUID as-is.
  </action>
  <verify>
Build the project with `xcodebuild -project GSDMonitor.xcodeproj -scheme GSDMonitor build 2>&1 | tail -5` (or the workspace equivalent). Confirm zero errors. Confirm that calling `Project.deterministicID(from: URL(fileURLWithPath: "/tmp/test"))` twice returns the same UUID (add a temporary print or trust the SHA256 determinism).
  </verify>
  <done>
Project.swift has `deterministicID(from:)` static method. Manual init uses it as default when no id is provided. ProjectService.parseProject creates Projects that get stable UUIDs from their path. Codable init unchanged. Build succeeds with no errors.
  </done>
</task>

</tasks>

<verification>
1. Build succeeds: `xcodebuild build` completes with 0 errors
2. Behavioral: Launch app, select a project, trigger a file change in its .planning/ directory, confirm sidebar selection stays on the same project
</verification>

<success_criteria>
- The same project directory always produces the same UUID across reloads
- Sidebar selection (selectedProjectID) survives FSEvents-triggered reloads
- Codable decoding path is unaffected
- App builds and runs without errors
</success_criteria>

<output>
After completion, create `.planning/quick/3-fix-project-selection-lost-on-fsevents-r/3-SUMMARY.md`
</output>
