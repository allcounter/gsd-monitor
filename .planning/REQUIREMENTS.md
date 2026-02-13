# Requirements: GSD Monitor

**Defined:** 2026-02-18
**Core Value:** A live, graphical overview of all GSD projects across ~/Developer — so you always know where you are, without opening a terminal.

## v1.3 Requirements

### Scan Sources

- [x] **SCAN-01**: User can add custom scan directories via settings
- [x] **SCAN-02**: User can remove scan directories
- [x] **SCAN-03**: App scans all configured directories for .planning/ projects
- [x] **SCAN-04**: ~/Developer remains default scan directory

### Project Locking

- [ ] **LOCK-01**: User can lock a project from sidebar context menu
- [ ] **LOCK-02**: Locked projects show a visual lock indicator
- [ ] **LOCK-03**: Command buttons are disabled on locked projects
- [ ] **LOCK-04**: User can unlock a project from sidebar context menu

## Future Requirements

(none deferred)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Drag-and-drop folder reordering | Unnecessary complexity for v1.3 |
| Per-folder scan depth settings | Overkill — flat scan is sufficient |
| Password/biometric unlock for locked projects | Simple toggle is enough |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SCAN-01 | Phase 16 | Complete |
| SCAN-02 | Phase 16 | Complete |
| SCAN-03 | Phase 16 | Complete |
| SCAN-04 | Phase 16 | Complete |
| LOCK-01 | Phase 17 | Pending |
| LOCK-02 | Phase 17 | Pending |
| LOCK-03 | Phase 17 | Pending |
| LOCK-04 | Phase 17 | Pending |

**Coverage:**
- v1.3 requirements: 8 total
- Mapped to phases: 8
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-18*
*Last updated: 2026-02-18 after v1.3 roadmap created (phases 16-17 assigned)*
