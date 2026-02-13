---
phase: quick-29
plan: 29
subsystem: settings/editor
tags: [editor, settings, userdefaults, persistence, fileimporter]
dependency_graph:
  requires: []
  provides: [custom-editor-add, custom-editor-remove, custom-editor-persist]
  affects: [EditorSettingsView, EditorService, Editor]
tech_stack:
  added: [UniformTypeIdentifiers]
  patterns: [UserDefaults JSON persistence, fileImporter sheet, alert with TextField]
key_files:
  created: []
  modified:
    - GSDMonitor/Models/Editor.swift
    - GSDMonitor/Services/EditorService.swift
    - GSDMonitor/Views/Settings/EditorSettingsView.swift
decisions:
  - "Use path.path as editor ID for custom editors — Homebrew and non-standard .app bundles lack discoverable bundle IDs"
  - "Stale cleanup on detectInstalledEditors — silently drop custom editors whose .app path no longer exists"
  - "Alert with TextField for name confirmation — pre-populate from CFBundleName or filename, user can edit before adding"
metrics:
  duration: 80s
  completed: 2026-02-18
  tasks_completed: 2
  tasks_total: 2
  files_modified: 3
---

# Quick Task 29: Manual Editor Addition Summary

**One-liner:** Custom editor add/remove via .app file browser with UserDefaults JSON persistence and stale-path cleanup on detect.

## What Was Built

Users can now add any .app bundle as a custom editor in Settings > Editor. Custom editors persist across restarts, appear alongside auto-detected editors in the preferred editor picker, and show a red remove button in the detected editors list.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add isCustom to Editor model + EditorService CRUD | 26c68a1 | Editor.swift, EditorService.swift |
| 2 | Custom editor UI in EditorSettingsView | 29f03f9 | EditorSettingsView.swift |

## Changes Made

### Editor.swift
- Added `isCustom: Bool` stored property (default `false`)
- Added `isCustom` to `CodingKeys`, `init`, `encode`, `decode` (backward-compatible: defaults to `false` if key absent)

### EditorService.swift
- Added `customEditorsKey = "customEditors"` constant
- Added `customEditors: [Editor]` computed property reading/writing JSON-encoded array to UserDefaults
- `detectInstalledEditors()` now appends stored custom editors whose path still exists on disk
- `addCustomEditor(name:path:)` — creates Editor with `id = path.path`, `isCustom = true`, appends to UserDefaults, refreshes list
- `removeCustomEditor(id:)` — filters from UserDefaults, resets `preferredEditorID` if matched, refreshes list

### EditorSettingsView.swift
- Added `import UniformTypeIdentifiers` for `UTType.application`
- Added `@State` properties: `showingFileImporter`, `customEditorName`, `showingNamePrompt`, `pendingAppURL`
- Detected Editors section: custom editors show a red minus.circle delete button
- New "Custom Editors" section with "Add Custom Editor..." button (plus icon)
- `.fileImporter` attached to Form — reads `CFBundleName` or falls back to filename-without-extension for default name
- `.alert("Editor Name")` with editable TextField, "Add" and "Cancel" buttons

## Decisions Made

1. **path.path as editor ID** — Homebrew apps and arbitrary .app bundles may not have bundle IDs accessible via `Bundle(url:).bundleIdentifier`. Using the full path string as a stable unique identifier is reliable and avoids API calls to read Info.plist manually.

2. **Stale cleanup on detect** — Rather than cleaning up at add-time or on a timer, the stale check happens each time `detectInstalledEditors()` runs. This ensures moves/deletions of custom apps are reflected on the next refresh or app launch without requiring explicit user action.

3. **Alert with TextField** — Pre-populates the app name from `CFBundleName` (when readable via Bundle API) or the filename. Gives the user a chance to correct misread names (e.g., internal app names differ from display names).

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `xcodebuild` Build Succeeded after both tasks
- Manual testing required: Settings > Editor > Add Custom Editor > browse to .app > confirm name > verify in picker and list > remove > verify disappears

## Self-Check

- [x] GSDMonitor/Models/Editor.swift — modified with isCustom
- [x] GSDMonitor/Services/EditorService.swift — modified with CRUD + persistence
- [x] GSDMonitor/Views/Settings/EditorSettingsView.swift — modified with file importer + alert UI
- [x] Commit 26c68a1 — Task 1
- [x] Commit 29f03f9 — Task 2

## Self-Check: PASSED
