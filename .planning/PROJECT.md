# GSD Monitor

## What This Is

Native macOS app (SwiftUI) that provides a live, graphical overview of all GSD projects. Reads `.planning/` directories directly, displays roadmaps, phases, tasks, and progress in a visual dashboard — with Gruvbox Dark theme, FSEvents live updates, milestone timeline, stats cards, macOS notifications, and editor integration.

## Core Value

A live, graphical overview of all GSD projects across ~/Developer — so you always know where you are, without opening a terminal.

## Current State

**Shipped:** v1.2 GSD Command Runner (2026-02-18)
**Codebase:** 6,840 LOC Swift, ~140 commits
**Tech stack:** Swift 6 / SwiftUI, FSEvents, UserNotifications, Foundation.Process/PTY, swift-markdown (SPM)

## Requirements

### Validated

- ✓ Multi-project sidebar with auto-scan of ~/Developer for .planning/ directories — v1.0
- ✓ Manual addition of project directories outside ~/Developer — v1.0
- ✓ Visual roadmap with phase cards showing goals, requirements, and progress bars — v1.0
- ✓ Phase detail view with plans, tasks, and status — v1.0
- ✓ Requirements view with REQ-IDs and completion status — v1.0
- ✓ Live updates via FSEvents when .planning/ files change on disk — v1.0
- ✓ macOS notifications when phases or tasks change status — v1.0
- ✓ Editor integration — click to open in Cursor/VS Code/Zed — v1.0
- ✓ Parsing of ROADMAP.md, STATE.md, REQUIREMENTS.md, PLAN.md, and config.json — v1.0
- ✓ System theme — follows macOS dark/light mode automatically — v1.0
- ✓ Gruvbox Dark color system — 27 colors as centralized Theme system — v1.1
- ✓ Always dark theme — forced dark mode via NSApp.appearance — v1.1
- ✓ Animated progress bars with gradient fills and hasAppeared animation — v1.1
- ✓ Gradient headers on phase cards with Gruvbox colors based on status — v1.1
- ✓ Milestone timeline — phases as connected nodes with expand/collapse — v1.1
- ✓ Stats cards in project header (total phases, completion %, active, execution time) — v1.1
- ✓ Colored SF Symbol project icons in sidebar based on status — v1.1
- ✓ Themed empty states with ContentUnavailableView and Gruvbox colors — v1.1
- ✓ Consolidated StatusBadge component with Gruvbox colors — v1.1
- ✓ Embedded GSD command runner with ProcessActor, PTY, live AsyncStream output — v1.2
- ✓ Shell environment PATH resolution for claude CLI (zsh -l -c env) — v1.2
- ✓ Per-project FIFO command queue with cancel/kill escalation — v1.2
- ✓ Live output panel with raw/structured toggle, stderr coloring, rolling buffer — v1.2
- ✓ Structured view with GSD banner parsing, task progress, exit codes — v1.2
- ✓ Context buttons on phase cards and plan rows (Plan/Execute/Verify) — v1.2
- ✓ Multi-step command palette (Cmd+K) with project/phase selection — v1.2
- ✓ Command history tab with re-run and FSEvents suppression — v1.2
- ✓ Cancel confirmation dialog and actionable error messages — v1.2
- ✓ Manual editor addition in preferences — v1.2

### Active

## Current Milestone: v1.3 Project Safety & Flexibility

**Goal:** Give the user control over scan directories and protect projects from accidental commands.

**Target features:**
- Configurable scan directories (add/remove base directories)
- Project locking (lock projects from commands)

### Out of Scope

- Full general terminal emulator — GSD commands only, not a shell
- gsd-console as dependency — builds everything natively, no Bun/Node
- iOS/iPad version — macOS only
- Cloud sync — local files only
- Light mode / system theme — Gruvbox Dark only
- Theme picker / multiple themes — Gruvbox Dark only
- Interactive stdin prompts — GSD commands run non-interactively
- Multiple concurrent commands per project — GSD agents mutate same .planning/ files

## Context

- Shipped v1.0 MVP on 2026-02-14 (2 days, 5 phases, 18 plans)
- Shipped v1.1 Visual Overhaul on 2026-02-17 (4 days, 7 phases, 12 plans + 15 quick tasks)
- Shipped v1.2 GSD Command Runner on 2026-02-18 (1 day, 3 phases, 8 plans + 14 quick tasks)
- Inspired by gsd-console (Codesushi-com/gsd-console), a terminal TUI for GSD
- GSD (Get-Shit-Done) stores all planning in `.planning/` directories as markdown and JSON files
- macOS — standard system directory names

## Constraints

- **Platform**: macOS 14+ (Sonoma) — SwiftUI med moderne APIs
- **Language**: Swift 6 / SwiftUI
- **Dependency**: swift-markdown (SPM) — otherwise only Apple frameworks
- **Data**: Read-only + command runner — the app reads .planning/ directly and can trigger GSD commands that modify them
- **Distribution**: Local build, not Mac App Store

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SwiftUI over Electron/Tauri | Native performance, low memory, feels like a Mac app | ✓ Good |
| Read files directly vs embed gsd-console | gsd-console is Bun/TS TUI — not reusable in SwiftUI. File parsing is simple | ✓ Good |
| FSEvents for live updates | Killer feature — app updates automatically when GSD runs in terminal | ✓ Good |
| Read-only in v1 | Command execution is complex and not core value. Added in v2 | ✓ Good |
| Phase card UI over timeline/kanban | GSD phases have goals+requirements+status — cards are the natural display | ✓ Good |
| Gruvbox Dark only over system theme | Strong visual identity, consistent brand | ✓ Good |
| Swift 6 strict concurrency | Prevents data races at compile time, future-proof | ✓ Good |
| @Observable over ObservableObject | Modern SwiftUI pattern, less boilerplate | ✓ Good |
| Disabled app sandbox | Developer utility needs ~/Developer filesystem access | ✓ Good |
| .timeSensitive notifications | Focus mode pass-through for important status changes | ✓ Good |
| Auto-detect editors only | Manual addition deferred — auto-detect covers 95% of use cases | ✓ Good |
| Code-based Gruvbox colors (hex extension) | Portability over Asset Catalog; two-layer naming (Theme.bg0 + Theme.statusActive) | ✓ Good |
| Linear bars over circular rings | Capsule bars with gradients are cleaner than circular rings | ✓ Good |
| hasAppeared animation pattern | Animates on first render only — FSEvents updates don't re-trigger animation | ✓ Good |
| Deterministic UUID from path (SHA-256) | Project selection survives FSEvents reload — no state loss | ✓ Good |
| Dual FileWatcherService instances | Separate watchers for scan sources vs .planning/ — independent lifecycle/debounce | ✓ Good |
| Milestone not Codable | Derived at parse time, excluded from CodingKeys to preserve JSON encode/decode | ✓ Good |
| Foundation.Process + Pipe (not PTY for MVP) | Validate with claude --version first; PTY only if needed | ✓ Good |
| actor ProcessActor pattern | Mirrors FileWatcherService's AsyncStream + C callback pattern | ✓ Good |
| Login shell env capture (zsh -l -c env) | launchd PATH does not include claude CLI install locations | ✓ Good |
| One command per project queue | GSD agents mutate same .planning/ files; concurrent runs corrupt state | ✓ Good |
| FSEvents reload suppressed during commands | Single forced reload on completion — prevents flicker | ✓ Good |
| _Concurrency.Task qualifier | GSDMonitor.Task model shadows Swift Concurrency Task module-wide | ✓ Good |
| HSplitView layout | Dashboard left (minWidth 400) + output right (280-600px) | ✓ Good |
| CommandRunnerService as @Environment | Injected once in ContentView, shared via .environment() | ✓ Good |
| Multi-step command palette | command→project→phase flow instead of single-step | ✓ Good |
| CommandHistoryStore as actor | Actor isolation prevents concurrent file I/O contention | ✓ Good |

---
*Last updated: 2026-02-18 after v1.3 milestone started*
