---
phase: quick-29
plan: 29
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Models/Editor.swift
  - GSDMonitor/Services/EditorService.swift
  - GSDMonitor/Views/Settings/EditorSettingsView.swift
autonomous: true
must_haves:
  truths:
    - "User can add a custom editor by browsing for a .app bundle"
    - "Custom editors appear in the preferred editor picker alongside auto-detected ones"
    - "Custom editors persist across app restarts via UserDefaults"
    - "User can remove a previously added custom editor"
  artifacts:
    - path: "GSDMonitor/Models/Editor.swift"
      provides: "Editor model with isCustom flag"
    - path: "GSDMonitor/Services/EditorService.swift"
      provides: "Custom editor CRUD + persistence in UserDefaults"
    - path: "GSDMonitor/Views/Settings/EditorSettingsView.swift"
      provides: "Add Custom Editor button + remove capability"
  key_links:
    - from: "EditorSettingsView.swift"
      to: "EditorService.swift"
      via: "addCustomEditor / removeCustomEditor calls"
    - from: "EditorService.swift"
      to: "UserDefaults"
      via: "customEditors JSON storage key"
---

<objective>
Add ability to manually add editors that are not auto-detected. Users can browse for any .app bundle, give it a name, and it persists in UserDefaults alongside the auto-detected editors.

Purpose: Editors installed via Homebrew, non-standard paths, or not in the known bundle ID list are currently invisible.
Output: Updated Editor model, EditorService with custom editor persistence, and EditorSettingsView with add/remove UI.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Models/Editor.swift
@GSDMonitor/Services/EditorService.swift
@GSDMonitor/Views/Settings/EditorSettingsView.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add custom editor support to Editor model and EditorService</name>
  <files>GSDMonitor/Models/Editor.swift, GSDMonitor/Services/EditorService.swift</files>
  <action>
1. In Editor.swift, add an `isCustom: Bool = false` stored property. Add it to CodingKeys, init, encode/decode (default false for backward compat). Keep Sendable conformance.

2. In EditorService.swift:
   - Add a private `customEditorsKey = "customEditors"` constant.
   - Add a `customEditors: [Editor]` computed property that reads/writes JSON-encoded `[Editor]` array from UserDefaults under that key. Use JSONEncoder/JSONDecoder. Return empty array on decode failure.
   - Update `installedEditors` population: after `detectInstalledEditors()` runs and sets the auto-detected editors, append `customEditors` to the list (filtering out any whose path no longer exists on disk — stale cleanup).
   - Add `func addCustomEditor(name: String, path: URL)` that:
     a. Creates an Editor with `id` = path.path (since custom apps may lack bundle IDs, use the path as stable identifier), `name` = provided name, `path` = path, `isCustom` = true.
     b. Appends to the stored customEditors array in UserDefaults.
     c. Calls `detectInstalledEditors()` to refresh the combined list.
   - Add `func removeCustomEditor(id: String)` that:
     a. Filters out the editor with matching id from the stored customEditors array.
     b. Writes back to UserDefaults.
     c. If `preferredEditorID == id`, resets preferredEditorID to "".
     d. Calls `detectInstalledEditors()` to refresh.
   - In `detectInstalledEditors()`, after the existing for-loop that builds `found`, append custom editors (loaded from UserDefaults) whose `path` still exists. Set `installedEditors = found`.

Note: Use path.path as the editor ID for custom editors (not bundle ID) because Homebrew-installed apps or arbitrary .app bundles may not have discoverable bundle IDs through Bundle(url:). This ensures a stable, unique identifier.
  </action>
  <verify>Build compiles: `cd . && swift build 2>&1 | tail -5` shows "Build complete"</verify>
  <done>Editor model has isCustom flag. EditorService can add/remove/persist custom editors in UserDefaults and merges them with auto-detected editors.</done>
</task>

<task type="auto">
  <name>Task 2: Add custom editor UI to EditorSettingsView</name>
  <files>GSDMonitor/Views/Settings/EditorSettingsView.swift</files>
  <action>
Update EditorSettingsView to allow adding and removing custom editors:

1. Add @SwiftUI.State properties: `showingFileImporter: Bool = false`, `customEditorName: String = ""`, `showingNamePrompt: Bool = false`, `pendingAppURL: URL? = nil`.

2. In the "Detected Editors" section, show each editor row. For custom editors (editor.isCustom == true), add a trailing delete button (minus circle icon, red tint) that calls `editorService.removeCustomEditor(id: editor.id)`.

3. Add a new Section("Custom Editors") AFTER "Detected Editors":
   - Button("Add Custom Editor...") with a plus icon that sets `showingFileImporter = true`.

4. Attach `.fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.application])` to the Form:
   - On success: store the selected URL in `pendingAppURL`, try to read the app name from `Bundle(url:)?.infoDictionary?["CFBundleName"]` or fall back to the filename without extension. Set `customEditorName` to that value. Set `showingNamePrompt = true`.
   - On failure: ignore (user cancelled).

5. Attach `.alert("Editor Name", isPresented: $showingNamePrompt)` with a TextField bound to `customEditorName` and two buttons:
   - "Add": calls `editorService.addCustomEditor(name: customEditorName, path: pendingAppURL!)` then resets state.
   - "Cancel": resets state.

6. The Picker for "Preferred Editor:" already iterates `editorService.installedEditors`, so custom editors automatically appear there — no changes needed.

Follow existing Theme usage (Theme.textSecondary for secondary text). Use .formStyle(.grouped) as already present.

IMPORTANT: For the fileImporter allowedContentTypes, import UniformTypeIdentifiers and use UTType.application (which matches .app bundles).
  </action>
  <verify>Build compiles: `cd . && swift build 2>&1 | tail -5` shows "Build complete"</verify>
  <done>User can click "Add Custom Editor", browse for a .app, confirm the name, and see it appear in both the detected list and the preferred editor picker. Custom editors show a remove button. Removing clears the editor from UserDefaults and resets preference if it was selected.</done>
</task>

</tasks>

<verification>
1. `swift build` succeeds with no errors
2. Manual test: Open Settings > Editor, click "Add Custom Editor", browse to any .app, confirm name, verify it appears in picker and detected list
3. Quit and relaunch app — custom editor persists
4. Remove the custom editor — it disappears and preference resets if it was selected
</verification>

<success_criteria>
- Custom editors can be added via file browser (.app selection)
- Custom editors persist in UserDefaults across restarts
- Custom editors appear in the preferred editor picker
- Custom editors can be removed with a delete button
- Auto-detected editors continue working unchanged
- Build compiles cleanly
</success_criteria>

<output>
After completion, create `.planning/quick/29-manual-editor-addition/29-SUMMARY.md`
</output>
