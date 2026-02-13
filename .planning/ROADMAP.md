# Roadmap: GSD Monitor

## Milestones

- ✅ **v1.0 MVP** - Phases 1-5 (shipped 2026-02-14) - [archive](milestones/v1.0-ROADMAP.md)
- ✅ **v1.1 Visual Overhaul** - Phases 6-12 (shipped 2026-02-17) - [archive](milestones/v1.1-ROADMAP.md)
- ✅ **v1.2 GSD Command Runner** - Phases 13-15 (shipped 2026-02-18) - [archive](milestones/v1.2-ROADMAP.md)
- 🚧 **v1.3 Project Safety & Flexibility** - Phases 16-17 (in progress)

## Phases

<details>
<summary>✅ v1.0 MVP (Phases 1-5) - SHIPPED 2026-02-14</summary>

- [x] Phase 1: Foundation & Models (3/3 plans) - completed 2026-02-13
- [x] Phase 2: File Discovery & Parsing (5/5 plans) - completed 2026-02-13
- [x] Phase 3: File System Monitoring (3/3 plans) - completed 2026-02-13
- [x] Phase 4: Dashboard UI & Visualization (4/4 plans) - completed 2026-02-14
- [x] Phase 5: Notifications & Editor Integration (3/3 plans) - completed 2026-02-14

</details>

<details>
<summary>✅ v1.1 Visual Overhaul (Phases 6-12) - SHIPPED 2026-02-17</summary>

- [x] Phase 6: Theme Foundation (3/3 plans) - completed 2026-02-15
- [x] Phase 7: Animated Progress Rings (2/2 plans) - completed 2026-02-15
- [x] Phase 8: Gradient Headers (1/1 plan) - completed 2026-02-15
- [x] Phase 9: Colored Sidebar Icons (1/1 plan) - completed 2026-02-16
- [x] Phase 10: Enhanced Empty States (1/1 plan) - completed 2026-02-17
- [x] Phase 11: Dashboard Stats Cards (2/2 plans) - completed 2026-02-17
- [x] Phase 12: Milestone Timeline (2/2 plans) - completed 2026-02-17

</details>

<details>
<summary>✅ v1.2 GSD Command Runner (Phases 13-15) - SHIPPED 2026-02-18</summary>

- [x] Phase 13: Process Foundation (3/3 plans) - completed 2026-02-17
- [x] Phase 14: Output Panel (2/2 plans) - completed 2026-02-18
- [x] Phase 15: Command Triggering & Integration (3/3 plans) - completed 2026-02-18

</details>

### 🚧 v1.3 Project Safety & Flexibility (In Progress)

**Milestone Goal:** Give the user control over which directories are scanned and protect individual projects from accidental command execution.

- [x] **Phase 16: Configurable Scan Directories** - User controls which base directories the app scans for GSD projects (completed 2026-02-21)
- [ ] **Phase 17: Project Locking** - User can lock individual projects to prevent accidental command execution

## Phase Details

### Phase 16: Configurable Scan Directories
**Goal**: Users control which directories the app scans for GSD projects, with ~/Developer as the permanent default
**Depends on**: Phase 15
**Requirements**: SCAN-01, SCAN-02, SCAN-03, SCAN-04
**Success Criteria** (what must be TRUE):
  1. User can open Settings and add any directory as a scan source — app immediately begins scanning it for .planning/ projects
  2. User can remove a previously added scan directory — its projects disappear from the sidebar
  3. ~/Developer is always present as a scan source and cannot be removed
  4. Projects from all configured directories appear together in the sidebar alongside ~/Developer projects
**Plans:** 2/2 plans complete
Plans:
- [ ] 16-01-PLAN.md — Scan state tracking in ProjectService + ScanDirectoriesPopoverView
- [ ] 16-02-PLAN.md — Gear button in sidebar + collapsible sections + end-to-end verification

### Phase 17: Project Locking
**Goal**: Users can lock individual projects to prevent accidental GSD command execution against them
**Depends on**: Phase 16
**Requirements**: LOCK-01, LOCK-02, LOCK-03, LOCK-04
**Gap Closure:** Closes all 4 unsatisfied requirements + 2 integration issues from v1.3 audit
**Success Criteria** (what must be TRUE):
  1. User can right-click a project in the sidebar and select "Lock Project" — project becomes locked
  2. Locked projects display a visible lock indicator (icon or badge) in the sidebar
  3. All command buttons (Plan, Execute, Verify) are visually disabled and non-interactive on locked projects
  4. User can right-click a locked project and select "Unlock Project" — all command buttons become active again
  5. groupedProjects sorts ~/Developer first for deterministic auto-selection (integration fix)
  6. Unreachable empty-state dead code removed from SidebarView (integration fix)
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation & Models | v1.0 | 3/3 | Complete | 2026-02-13 |
| 2. File Discovery & Parsing | v1.0 | 5/5 | Complete | 2026-02-13 |
| 3. File System Monitoring | v1.0 | 3/3 | Complete | 2026-02-13 |
| 4. Dashboard UI & Visualization | v1.0 | 4/4 | Complete | 2026-02-14 |
| 5. Notifications & Editor Integration | v1.0 | 3/3 | Complete | 2026-02-14 |
| 6. Theme Foundation | v1.1 | 3/3 | Complete | 2026-02-15 |
| 7. Animated Progress Rings | v1.1 | 2/2 | Complete | 2026-02-15 |
| 8. Gradient Headers | v1.1 | 1/1 | Complete | 2026-02-15 |
| 9. Colored Sidebar Icons | v1.1 | 1/1 | Complete | 2026-02-16 |
| 10. Enhanced Empty States | v1.1 | 1/1 | Complete | 2026-02-17 |
| 11. Dashboard Stats Cards | v1.1 | 2/2 | Complete | 2026-02-17 |
| 12. Milestone Timeline | v1.1 | 2/2 | Complete | 2026-02-17 |
| 13. Process Foundation | v1.2 | 3/3 | Complete | 2026-02-17 |
| 14. Output Panel | v1.2 | 2/2 | Complete | 2026-02-18 |
| 15. Command Triggering & Integration | v1.2 | 3/3 | Complete | 2026-02-18 |
| 16. Configurable Scan Directories | 2/2 | Complete    | 2026-02-21 | - |
| 17. Project Locking | v1.3 | 0/? | Not started | - |

---
*Created: 2026-02-13*
*Last updated: 2026-02-18 after v1.3 roadmap created*
