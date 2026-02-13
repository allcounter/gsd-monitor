# Milestones

## v1.0 MVP (Shipped: 2026-02-14)

**Phases completed:** 5 phases, 18 plans
**Timeline:** 2 days (2026-02-13 → 2026-02-14)
**Codebase:** 3,292 LOC Swift, 67 commits

**Key accomplishments:**
- Swift 6 strict concurrency foundation with Codable models and NavigationSplitView layout
- Auto-discovery of GSD projects in ~/Developer with security-scoped bookmarks for persistence
- Full .planning/ file parsing: ROADMAP.md, STATE.md, REQUIREMENTS.md, PLAN.md, config.json
- FSEvents-based live monitoring with 1-second debounce and .git/ filtering
- Visual dashboard with phase cards, progress bars, Cmd+K command palette, and status filtering
- macOS notifications on phase status changes with Focus mode support (.timeSensitive)
- Editor integration: auto-detect Cursor/VS Code/Zed, open projects with one click

**Archives:** [v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md) | [v1.0-REQUIREMENTS.md](milestones/v1.0-REQUIREMENTS.md)

---

## v1.1 Visual Overhaul (Shipped: 2026-02-17)

**Phases completed:** 7 phases (6-12), 12 plans, 15 quick tasks
**Timeline:** 4 days (2026-02-15 → 2026-02-17)
**Codebase:** 4,255 LOC Swift, 110 commits (cumulative)

**Key accomplishments:**
- Gruvbox Dark color palette (27 colors) as centralized Theme system with forced dark mode — all system colors eliminated
- Animated progress bars with gradient fills and hasAppeared pattern (no FSEvents re-animation)
- Status-colored gradient headers on phase cards (gray/yellow/green based on phase status)
- Colored SF Symbol sidebar icons with status derivation from roadmap phases
- Themed empty states across all views using ContentUnavailableView with Gruvbox colors
- Dashboard stats grid: total phases, completion %, active phases, execution time
- Milestone timeline with connected phase nodes, expand/collapse for completed milestones
- 15 quick tasks: parser fixes, progress coherence, sidebar polish, scan source watching

**Known tech debt:** (from audit)
- Unused `projectName` parameter in MilestoneTimelineView
- Overall progress bar uses system ProgressView (not AnimatedProgressBar)
- Color.black in scroll mask (technically system color, functionally correct)

**Archives:** [v1.1-ROADMAP.md](milestones/v1.1-ROADMAP.md) | [v1.1-REQUIREMENTS.md](milestones/v1.1-REQUIREMENTS.md) | [v1.1-MILESTONE-AUDIT.md](milestones/v1.1-MILESTONE-AUDIT.md)

---


## v1.2 GSD Command Runner (Shipped: 2026-02-18)

**Phases completed:** 3 phases (13-15), 8 plans, 14 quick tasks
**Timeline:** 1 day (2026-02-17 → 2026-02-18)
**Codebase:** 6,840 LOC Swift, ~140 commits (cumulative)

**Key accomplishments:**
- Embedded command execution engine: ProcessActor with PTY, live AsyncStream output, SIGINT→SIGKILL cancel escalation, per-project FIFO queues
- Live output panel: HSplitView with raw terminal output, stderr coloring (Gruvbox red), auto-scroll, rolling 5000-line buffer
- Structured output view: parses GSD banners, task progress, exit codes with success/failure banners and macOS failure notifications
- Context buttons on phase cards and plan rows: smart default action (Plan/Execute/Verify) with overflow menu and running state indicators
- Multi-step command palette (Cmd+K): command→project→phase selection flow with real-time search
- Command history tab with re-run capability, FSEvents reload suppression during active commands

**Archives:** [v1.2-ROADMAP.md](milestones/v1.2-ROADMAP.md) | [v1.2-REQUIREMENTS.md](milestones/v1.2-REQUIREMENTS.md) | [v1.2-MILESTONE-AUDIT.md](milestones/v1.2-MILESTONE-AUDIT.md)

---

