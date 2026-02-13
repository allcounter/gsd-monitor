# Todo: Manual Editor Addition

**Source:** Phase 5 human verification (2026-02-14)
**Priority:** Low (v2 feature)

## Description
Add ability to manually add/configure editors that aren't auto-detected in /Applications. Currently EditorService only scans for Cursor, VS Code, and Zed via bundle IDs.

## Use Cases
- Editors installed via Homebrew or non-standard paths
- Custom editor configurations
- Editors not in the auto-detect list

## Implementation Ideas
- Add "Custom Editor" option in Settings > Editor tab
- Let user browse for .app bundle or provide path
- Store custom editors in UserDefaults alongside preferredEditorID
