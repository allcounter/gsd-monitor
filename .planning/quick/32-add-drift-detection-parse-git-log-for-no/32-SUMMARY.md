---
phase: quick-32
plan: 01
subsystem: drift-detection
tags: [git, parsing, dashboard, swift]
dependency_graph:
  requires: []
  provides: [DriftCommit model, GitLogParser service, DriftSectionView]
  affects: [Project model, ProjectService, DetailView, PreviewData]
tech_stack:
  added: [NSRegularExpression, Process, RelativeDateTimeFormatter]
  patterns: [async/await git subprocess, numstat parsing, Gruvbox theme components]
key_files:
  created:
    - GSDMonitor/Models/DriftCommit.swift
    - GSDMonitor/Services/GitLogParser.swift
    - GSDMonitor/Views/Dashboard/DriftSectionView.swift
  modified:
    - GSDMonitor/Models/Project.swift
    - GSDMonitor/Services/ProjectService.swift
    - GSDMonitor/Utilities/PreviewData.swift
    - GSDMonitor/Views/DetailView.swift
    - GSDMonitor.xcodeproj/project.pbxproj
decisions:
  - "Used git log --numstat for single-pass parsing of both commit metadata and file counts"
  - "7 GSD patterns compiled as NSRegularExpression with caseInsensitive flag"
  - "driftCommits stored as nil (not empty array) when no drift found, for Optional-based conditional rendering"
  - "Used @SwiftUI.State to avoid ambiguity with project's State model type"
metrics:
  duration: "~5 minutes"
  completed: "2026-02-24"
  tasks_completed: 2
  files_modified: 8
---

# Phase quick-32 Plan 01: Drift Detection Summary

**One-liner:** Git log drift detection with NSRegularExpression GSD pattern filtering and Gruvbox-themed dashboard section.

## What Was Built

Drift detection that parses the last 50 git commits for each project, filters out GSD-workflow commits using 7 regex patterns, and displays the remaining "drift" commits in the project dashboard with a warning-orange Gruvbox styling.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create DriftCommit model and GitLogParser service | cfda45e | DriftCommit.swift, GitLogParser.swift, Project.swift, ProjectService.swift, PreviewData.swift, project.pbxproj |
| 2 | Create DriftSectionView and integrate into dashboard | a9b2375 | DriftSectionView.swift, DetailView.swift |

## Implementation Details

**DriftCommit model** (`GSDMonitor/Models/DriftCommit.swift`):
- `Identifiable, Codable, Sendable` struct
- Properties: `id` (7-char hash), `message`, `date`, `filesChanged`
- Computed `relativeDate` via `RelativeDateTimeFormatter`

**GitLogParser service** (`GSDMonitor/Services/GitLogParser.swift`):
- Runs `git log --format=%h|%s|%ai --numstat -50` via `Process` + `/usr/bin/env`
- Parses interleaved output: commit header lines followed by numstat file lines
- 7 GSD patterns compiled as `NSRegularExpression` (caseInsensitive):
  - `feat/fix/docs/etc(NN-NN):` — phase plans
  - `feat/fix/docs/etc(quick-NN):` — quick tasks
  - `feat/fix/docs/etc(phase-NN):` — phase-level docs
  - `wip:` — work in progress
  - `docs(NN):` — phase docs
  - `docs(roadmap):` — roadmap updates
  - `Merge` — merge commits
- Returns array sorted by date descending; empty array on git failure

**DriftSectionView** (`GSDMonitor/Views/Dashboard/DriftSectionView.swift`):
- Orange `exclamationmark.triangle` header with count badge
- Each row: monospaced hash (brightOrange), truncated message, file count with doc icon, relative date
- Shows max 10 commits; "Show all (N)" button to expand
- Empty commits = `EmptyView()` (no render)

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `GSDMonitor/Models/DriftCommit.swift` — exists
- [x] `GSDMonitor/Services/GitLogParser.swift` — exists
- [x] `GSDMonitor/Views/Dashboard/DriftSectionView.swift` — exists
- [x] Commit `cfda45e` — exists
- [x] Commit `a9b2375` — exists
- [x] Build succeeded: `** BUILD SUCCEEDED **`

## Self-Check: PASSED
