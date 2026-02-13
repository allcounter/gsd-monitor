---
phase: quick-32
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Models/DriftCommit.swift
  - GSDMonitor/Services/GitLogParser.swift
  - GSDMonitor/Models/Project.swift
  - GSDMonitor/Services/ProjectService.swift
  - GSDMonitor/Views/Dashboard/DriftSectionView.swift
  - GSDMonitor/Views/DetailView.swift
  - GSDMonitor/Utilities/PreviewData.swift
autonomous: true
requirements: [DRIFT-01]
must_haves:
  truths:
    - "Dashboard shows drift commits that don't match GSD patterns"
    - "Each drift commit displays hash, message, date, and files changed count"
    - "Only recent commits are checked (last 50) for performance"
    - "GSD-pattern commits are correctly excluded from drift list"
  artifacts:
    - path: "GSDMonitor/Models/DriftCommit.swift"
      provides: "DriftCommit model struct"
    - path: "GSDMonitor/Services/GitLogParser.swift"
      provides: "Git log parsing and GSD pattern filtering"
    - path: "GSDMonitor/Views/Dashboard/DriftSectionView.swift"
      provides: "Drift section UI for dashboard"
  key_links:
    - from: "GSDMonitor/Services/ProjectService.swift"
      to: "GitLogParser"
      via: "parseProject calls GitLogParser.parseDriftCommits"
      pattern: "gitLogParser\\.parseDriftCommits"
    - from: "GSDMonitor/Views/DetailView.swift"
      to: "DriftSectionView"
      via: "Embedded in dashboard below stats grid"
      pattern: "DriftSectionView"
---

<objective>
Add drift detection that parses git log for non-GSD commits and displays them in the project dashboard.

Purpose: Let user see at a glance which commits in a project were made outside the GSD workflow, helping maintain process discipline.
Output: DriftCommit model, GitLogParser service, DriftSectionView in dashboard.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Models/Project.swift
@GSDMonitor/Services/ProjectService.swift
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Views/Dashboard/StatsGridView.swift
@GSDMonitor/Views/Dashboard/StatCardView.swift
@GSDMonitor/Theme/Theme.swift
@GSDMonitor/Utilities/PreviewData.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create DriftCommit model and GitLogParser service</name>
  <files>
    GSDMonitor/Models/DriftCommit.swift
    GSDMonitor/Services/GitLogParser.swift
    GSDMonitor/Models/Project.swift
    GSDMonitor/Services/ProjectService.swift
    GSDMonitor/Utilities/PreviewData.swift
  </files>
  <action>
    1. Create `GSDMonitor/Models/DriftCommit.swift`:
       - Struct `DriftCommit: Identifiable, Codable, Sendable`
       - Properties: `id: String` (commit hash, short 7-char), `message: String`, `date: Date`, `filesChanged: Int`
       - Computed `relativeDate: String` using RelativeDateTimeFormatter

    2. Create `GSDMonitor/Services/GitLogParser.swift`:
       - Class `GitLogParser` with method `func parseDriftCommits(at projectPath: URL) async -> [DriftCommit]`
       - Run `git log --oneline --format="%h|%s|%ai|%H" -50` using Process (not shell: true) with currentDirectoryURL set to projectPath
       - For each commit, also run `git diff-tree --no-commit-id --name-only -r <full-hash>` to count files changed (or use `--stat` with `--format` to get numstat in one pass). Better approach: use single command `git log --format="%h|%s|%ai" --shortstat -50` and parse the interleaved output (hash line followed by stat line).
       - Define GSD patterns as regex array:
         ```
         ^(feat|fix|docs|refactor|chore|test|style)\(\d+-\d+\):     // phase plans: feat(16-01):
         ^(feat|fix|docs|refactor|chore|test|style)\(quick-\d+\):   // quick tasks: docs(quick-32):
         ^(feat|fix|docs|refactor|chore|test|style)\(phase-\d+\):   // phase-level: docs(phase-16):
         ^wip:                                                        // work in progress
         ^docs\(\d+\):                                                // docs(16): style
         ^docs\(roadmap\):                                            // roadmap updates
         ^Merge                                                       // merge commits
         ```
       - A commit is "drift" if its message does NOT match any GSD pattern
       - Return array sorted by date descending (most recent first)
       - Handle errors gracefully: if git command fails (not a git repo, etc.), return empty array
       - IMPORTANT: Use Process with `/usr/bin/env` and arguments `["git", "log", ...]` to avoid PATH issues. Set `process.currentDirectoryURL = projectPath`.

    3. Update `GSDMonitor/Models/Project.swift`:
       - Add `var driftCommits: [DriftCommit]?` property to Project struct
       - Add to CodingKeys, init(from decoder:) with decodeIfPresent, encode(to:) with encodeIfPresent
       - Add to manual init with default nil

    4. Update `GSDMonitor/Services/ProjectService.swift`:
       - Add `private let gitLogParser = GitLogParser()` property
       - In `parseProject(at:scanSource:)`, after parsing plans, call `let driftCommits = await gitLogParser.parseDriftCommits(at: url)`
       - Pass `driftCommits: driftCommits.isEmpty ? nil : driftCommits` to Project init

    5. Update `GSDMonitor/Utilities/PreviewData.swift`:
       - Add sample driftCommits to the first preview project:
         ```swift
         driftCommits: [
             DriftCommit(id: "a1b2c3d", message: "quick fix for layout bug", date: Date().addingTimeInterval(-3600), filesChanged: 2),
             DriftCommit(id: "e4f5g6h", message: "update readme", date: Date().addingTimeInterval(-86400), filesChanged: 1),
         ]
         ```
  </action>
  <verify>
    <automated>cd . && xcodebuild -scheme GSDMonitor -configuration Debug build 2>&1 | tail -5</automated>
  </verify>
  <done>DriftCommit model exists, GitLogParser correctly identifies non-GSD commits from git log, Project model carries drift data, ProjectService populates drift on load</done>
</task>

<task type="auto">
  <name>Task 2: Create DriftSectionView and integrate into dashboard</name>
  <files>
    GSDMonitor/Views/Dashboard/DriftSectionView.swift
    GSDMonitor/Views/DetailView.swift
  </files>
  <action>
    1. Create `GSDMonitor/Views/Dashboard/DriftSectionView.swift`:
       - Takes `let driftCommits: [DriftCommit]`
       - Section header: HStack with exclamationmark.triangle icon (Theme.brightOrange), "Drift" title (.headline), and count badge
       - List each commit in a compact row:
         - Left: commit hash in monospaced font (Theme.brightOrange, .caption), truncated message (Theme.fg1, .callout, lineLimit 1)
         - Right: files changed count with "doc" icon (Theme.textMuted, .caption), relative date (Theme.textMuted, .caption)
       - Each row background: Theme.bg1, cornerRadius 8, padding 10
       - Whole section wrapped in VStack(alignment: .leading, spacing: 8)
       - If driftCommits is empty, don't render anything (return EmptyView)
       - Show max 10 commits, with a "Show all (N)" disclosure if more than 10

    2. Update `GSDMonitor/Views/DetailView.swift`:
       - In `dashboardContent(for:)`, add DriftSectionView AFTER the StatsGridView and BEFORE the milestone timeline
       - Condition: `if let driftCommits = project.driftCommits, !driftCommits.isEmpty`
       - Place inside the pinned header VStack alongside other stats

    3. Style guidelines (match existing Gruvbox theme):
       - Use Theme.brightOrange as accent for drift (warning tone)
       - Use Theme.bg1 for row backgrounds (same as StatCardView)
       - Monospaced hash: `.font(.system(.caption, design: .monospaced))`
       - Match spacing/padding patterns from StatsGridView (spacing: 10, padding: 14)
  </action>
  <verify>
    <automated>cd . && xcodebuild -scheme GSDMonitor -configuration Debug build 2>&1 | tail -5</automated>
    <manual>Run app with makeapp, select a project with non-GSD commits, verify drift section appears with correct commits</manual>
  </verify>
  <done>Drift section visible in dashboard when project has non-GSD commits, each row shows hash/message/date/files, styled with Gruvbox orange warning theme</done>
</task>

</tasks>

<verification>
1. Build succeeds: `xcodebuild -scheme GSDMonitor -configuration Debug build`
2. App launches and shows drift section for projects with non-GSD commits
3. GSD-patterned commits (feat(16-01):, docs(quick-31):, wip:, etc.) are correctly filtered out
4. Projects without git or with only GSD commits show no drift section
</verification>

<success_criteria>
- DriftCommit model and GitLogParser service exist and compile
- GitLogParser correctly identifies non-GSD commits using regex patterns
- Dashboard displays drift section with commit hash, message, date, files changed
- Drift section only appears when drift commits exist
- Performance acceptable (git log -50 is fast, no blocking UI)
</success_criteria>

<output>
After completion, create `.planning/quick/32-add-drift-detection-parse-git-log-for-no/32-SUMMARY.md`
</output>
