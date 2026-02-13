---
phase: quick-7
plan: 01
subsystem: UI/Theme
tags: [refactor, deterministic-color, name-based-hashing]
dependency_graph:
  requires: []
  provides:
    - ProjectColors.forName deterministic color assignment
  affects:
    - SidebarView
    - ContentView
    - DetailView
    - PhaseCardView
tech_stack:
  added: []
  patterns:
    - Name-based color hashing (first letter ASCII value)
    - Immutable color palette lookup
key_files:
  created: []
  modified:
    - GSDMonitor/Theme/Theme.swift
    - GSDMonitor/Views/SidebarView.swift
    - GSDMonitor/Views/ContentView.swift
    - GSDMonitor/Views/DetailView.swift
    - GSDMonitor/Views/Dashboard/PhaseCardView.swift
decisions:
  - Use first character ASCII value for deterministic hash (simple, collision-friendly across palette)
  - Keep forIndex method for backward compatibility (can be removed later if unused)
  - Hash lowercased name for case-insensitive consistency
metrics:
  duration: 78s (~1.3 min)
  tasks_completed: 1
  files_modified: 5
  lines_changed: +18/-28
  completed_at: 2026-02-16
---

# Quick Task 7: Name-Based Project Colors

**One-liner:** Deterministic project colors using first-letter hash instead of list position index.

## What Changed

Replaced index-based color assignment (`ProjectColors.forIndex(index)`) with name-based assignment (`ProjectColors.forName(name)`). Projects now always get the same color regardless of filtering, sorting, or display order.

**Before:** Project colors depended on position in filtered/grouped list (color changed when searching or filtering).

**After:** Project colors are deterministic based on project name's first letter.

## Implementation

### 1. ProjectColors.forName Method
Added to `Theme.swift`:
```swift
static func forName(_ name: String) -> (dark: Color, bright: Color) {
    let index = Int(name.lowercased().first?.asciiValue ?? 0) % palette.count
    return palette[index]
}
```

**Hash logic:**
- Extract first character, lowercase
- Convert to ASCII value
- Modulo by palette count (7 colors)
- Same name → same color always

### 2. Removed Index Tracking
**SidebarView:**
- Removed `flatIndexOffset` computed property (tracked running index across groups)
- Removed `startIndex` parameter from `projectSection(for:startIndex:)`
- Removed `enumerated()` iteration in `ForEach`
- Changed `ProjectRow` from `colorIndex: Int` to `projectName: String`

**ContentView:**
- Removed `selectedProjectColorIndex` computed property (calculated index in flattened list)
- Changed `DetailView` call to pass `projectName` instead of `projectColorIndex`

### 3. Updated All Color Call Sites
**DetailView:** `projectColorIndex: Int` → `projectName: String`
**PhaseCardView:** `projectColorIndex: Int` → `projectName: String`

All uses of `ProjectColors.forIndex(projectColorIndex)` replaced with `ProjectColors.forName(projectName)`.

## Deviations from Plan

None - plan executed exactly as written.

## Verification

- `grep -r "forIndex" GSDMonitor/Views/` → No matches
- `grep -r "colorIndex" GSDMonitor/Views/` → No matches
- `grep -r "flatIndexOffset" GSDMonitor/` → No matches
- `xcodebuild` → BUILD SUCCEEDED
- `ProjectColors.forName` exists in Theme.swift
- All 5 files updated and committed

## Impact

**User-visible:**
- Projects maintain consistent color identity across app sessions
- Searching/filtering no longer changes project colors
- Same project always has same accent color in sidebar border and progress bars

**Technical:**
- Simplified code: removed index tracking logic
- More predictable behavior: color is a pure function of project name
- Better UX: visual identity is stable

## Self-Check: PASSED

All claimed files and commits verified:

- FOUND: GSDMonitor/Theme/Theme.swift
- FOUND: GSDMonitor/Views/SidebarView.swift
- FOUND: GSDMonitor/Views/ContentView.swift
- FOUND: GSDMonitor/Views/DetailView.swift
- FOUND: GSDMonitor/Views/Dashboard/PhaseCardView.swift
- FOUND: aae1438 (commit)
