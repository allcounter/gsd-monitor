# Phase 17: Project Locking - Context

**Gathered:** 2026-02-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Lock/unlock individual projects to prevent accidental GSD command execution. Right-click context menu to toggle lock state, visible lock indicator in sidebar, command buttons disabled when locked. Also includes 2 integration fixes: groupedProjects sorting and dead code removal.

</domain>

<decisions>
## Implementation Decisions

### Lock indicator style
- Small lock icon appears trailing (right side) of the project name in the sidebar
- Use SF Symbol `lock.fill` for the icon
- Icon uses an accent/warning color (orange/yellow) to make locked state visually obvious
- No dimming of the row — icon alone communicates locked state

### Disabled button behavior
- Plan, Execute, Verify command buttons are grayed out and disabled when project is locked
- Output panel remains fully readable — locking only prevents triggering new commands
- Clicking a disabled button shows a brief tooltip/toast: "Unlock project to run commands"
- Additional visual indication on buttons area: Claude's discretion
- Phase selector behavior when locked: Claude's discretion

### Context menu design
- Right-click on project in sidebar shows context menu with lock/unlock option
- Locking requires confirmation ("Are you sure?"), unlocking is instant
- Menu item text/style (toggle text vs checkmark): Claude's discretion based on macOS conventions
- No keyboard shortcut — right-click menu only
- Researcher should check if existing context menu exists on sidebar projects

### Lock persistence
- Lock state persists across app restarts — stored in UserDefaults
- Lock/unlock is per-project (individual toggling)
- Bulk lock/unlock option available via sidebar header menu (Lock All / Unlock All)

### Claude's Discretion
- Whether to add a small lock badge or label near the command buttons area
- Phase selector behavior when locked (disabled vs still browsable)
- Context menu item style (toggle text vs checkmark)
- Exact accent color for lock icon (within orange/yellow family)

</decisions>

<specifics>
## Specific Ideas

- Lock icon should feel like a clear "stop" signal — accent/warning color, not subtle
- Confirmation on lock prevents accidental locking, but unlock should be frictionless
- Bulk lock/unlock in sidebar header for managing many projects at once

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 17-project-locking*
*Context gathered: 2026-02-21*
