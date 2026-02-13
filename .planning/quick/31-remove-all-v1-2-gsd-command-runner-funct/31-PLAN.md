---
phase: quick-31
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - GSDMonitor/Services/CommandRunnerService.swift (DELETE)
  - GSDMonitor/Services/ProcessActor.swift (DELETE)
  - GSDMonitor/Services/ShellEnvironmentService.swift (DELETE)
  - GSDMonitor/Services/CommandHistoryStore.swift (DELETE)
  - GSDMonitor/Models/CommandRun.swift (DELETE)
  - GSDMonitor/Models/CommandState.swift (DELETE)
  - GSDMonitor/Utilities/GSDOutputParser.swift (DELETE)
  - GSDMonitor/Views/OutputPanel/ (DELETE directory)
  - GSDMonitor/Views/CommandPalette/CommandPaletteView.swift (DELETE)
  - GSDMonitor/Views/History/CommandHistoryView.swift (DELETE)
  - GSDMonitor/Views/ContentView.swift
  - GSDMonitor/Views/DetailView.swift
  - GSDMonitor/Views/SidebarView.swift
  - GSDMonitor/Views/Dashboard/PhaseCardView.swift
  - GSDMonitor/Views/Dashboard/PhaseDetailView.swift
  - GSDMonitor/Services/ProjectService.swift
autonomous: true
requirements: []
must_haves:
  truths:
    - "App compiles cleanly with zero errors after all command runner code is removed"
    - "No references to CommandRunnerService, CommandRun, CommandRequest, CommandState, ProcessActor, ShellEnvironmentService, CommandHistoryStore, GSDOutputParser, OutputPanel, CommandPalette, or CommandHistoryView remain in the codebase"
    - "App launches and displays project dashboard without crash"
  artifacts:
    - path: "GSDMonitor/Views/ContentView.swift"
      provides: "Root view without command runner environment or command palette"
    - path: "GSDMonitor/Views/DetailView.swift"
      provides: "Detail view as pure dashboard without History tab or OutputPanel"
    - path: "GSDMonitor/Views/SidebarView.swift"
      provides: "Sidebar ProjectRow without active run indicator"
    - path: "GSDMonitor/Views/Dashboard/PhaseCardView.swift"
      provides: "Phase card as read-only status display without action buttons"
    - path: "GSDMonitor/Views/Dashboard/PhaseDetailView.swift"
      provides: "Phase detail without command execution buttons"
    - path: "GSDMonitor/Services/ProjectService.swift"
      provides: "Project service without CommandRunnerService dependency"
  key_links:
    - from: "GSDMonitor/Views/ContentView.swift"
      to: "GSDMonitor/Views/DetailView.swift"
      via: "NavigationSplitView detail"
      pattern: "DetailView"
---

<objective>
Remove all v1.2 GSD Command Runner functionality from the app. Delete 16 files (services, models, utilities, views) related to command execution and clean up all references in 6 remaining files so the app compiles as a pure monitor/dashboard tool.

Purpose: The app should be a read-only project dashboard without any command execution capability, as part of v1.3 Project Safety & Flexibility milestone.
Output: Clean-compiling codebase with no command runner code.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@GSDMonitor/Views/ContentView.swift
@GSDMonitor/Views/DetailView.swift
@GSDMonitor/Views/SidebarView.swift
@GSDMonitor/Views/Dashboard/PhaseCardView.swift
@GSDMonitor/Views/Dashboard/PhaseDetailView.swift
@GSDMonitor/Services/ProjectService.swift
</context>

<tasks>

<task type="auto">
  <name>Task 1: Delete all command runner files and directories</name>
  <files>
    GSDMonitor/Services/CommandRunnerService.swift
    GSDMonitor/Services/ProcessActor.swift
    GSDMonitor/Services/ShellEnvironmentService.swift
    GSDMonitor/Services/CommandHistoryStore.swift
    GSDMonitor/Models/CommandRun.swift
    GSDMonitor/Models/CommandState.swift
    GSDMonitor/Utilities/GSDOutputParser.swift
    GSDMonitor/Views/OutputPanel/ (entire directory: OutputPanelView.swift, OutputStructuredView.swift, OutputRawView.swift, OutputBannerView.swift, ElapsedTimerView.swift)
    GSDMonitor/Views/CommandPalette/CommandPaletteView.swift
    GSDMonitor/Views/History/CommandHistoryView.swift
  </files>
  <action>
    Delete these files using rm:
    - GSDMonitor/Services/CommandRunnerService.swift
    - GSDMonitor/Services/ProcessActor.swift
    - GSDMonitor/Services/ShellEnvironmentService.swift
    - GSDMonitor/Services/CommandHistoryStore.swift
    - GSDMonitor/Models/CommandRun.swift
    - GSDMonitor/Models/CommandState.swift
    - GSDMonitor/Utilities/GSDOutputParser.swift
    - GSDMonitor/Views/OutputPanel/ (rm -rf the entire directory)
    - GSDMonitor/Views/CommandPalette/CommandPaletteView.swift
    - GSDMonitor/Views/History/CommandHistoryView.swift

    Also remove empty parent directories (CommandPalette/, History/) if they become empty.

    IMPORTANT: Do NOT delete GSDMonitor/Services/StateParser.swift -- it parses STATE.md for the project dashboard and is NOT command-runner related.
  </action>
  <verify>Confirm all listed files are deleted: `ls` each path should return "No such file or directory".</verify>
  <done>All 16 command runner files and the OutputPanel directory are deleted. StateParser.swift remains intact.</done>
</task>

<task type="auto">
  <name>Task 2: Remove all command runner references from remaining codebase</name>
  <files>
    GSDMonitor/Views/ContentView.swift
    GSDMonitor/Views/DetailView.swift
    GSDMonitor/Views/SidebarView.swift
    GSDMonitor/Views/Dashboard/PhaseCardView.swift
    GSDMonitor/Views/Dashboard/PhaseDetailView.swift
    GSDMonitor/Services/ProjectService.swift
  </files>
  <action>
    **ContentView.swift:**
    - Remove `@SwiftUI.State private var commandRunnerService = CommandRunnerService()`
    - Remove `@SwiftUI.State private var showCommandPalette = false`
    - Remove `.environment(commandRunnerService)` modifier
    - Remove entire `.sheet(isPresented: $showCommandPalette)` block (lines 30-37, the CommandPaletteView sheet)
    - Remove the hidden Cmd+K keyboard shortcut button block (lines 38-44)
    - Remove `projectService.commandRunner = commandRunnerService` from `.task` (line 47)
    - Remove the SAFE-02 comment and `projectService.commandRunner = commandRunnerService` from `.onChange(of: scenePhase)` (lines 80-81)

    **DetailView.swift:**
    - Remove the `DetailTab` enum entirely (lines 3-6)
    - Remove `@SwiftUI.State private var detailTab: DetailTab = .dashboard`
    - Remove `@Environment(CommandRunnerService.self) private var commandRunner`
    - Remove the HSplitView wrapper -- the view should just show `dashboardContent(for: project)` directly (no split, no right pane)
    - Remove the tab Picker and the switch statement for tabs
    - Remove the `CommandHistoryView(project: project)` reference
    - Remove the `OutputPanelView(project: project)` reference and its frame
    - The body for a selected project should just be `dashboardContent(for: project)` without HSplitView/tabs

    **SidebarView.swift (ProjectRow only):**
    - Remove `@Environment(CommandRunnerService.self) private var commandRunner`
    - Remove `private var activeRun: CommandRun?` computed property
    - Remove the `if let run = activeRun` block (lines 224-232) that shows the spinner + ElapsedTimerView when a command is running. Keep the `else` branch content (the status icon) as the only content in that spot.

    **PhaseCardView.swift:**
    - Remove `@Environment(CommandRunnerService.self) private var commandRunner`
    - Remove `private var isRunning: Bool` computed property
    - Remove `private var smartDefaultAction` computed property
    - Remove the entire "Action button row" HStack (lines 112-181) -- this contains all the command execution buttons (Plan/Execute/Verify/Cancel) and the overflow menu. Remove the whole block. The phase card becomes a read-only status display.

    **PhaseDetailView.swift:**
    - In `PhaseDetailView`: Remove `@Environment(CommandRunnerService.self) private var commandRunner`
    - In `PlanCard` (private struct at bottom): Remove `@Environment(CommandRunnerService.self) private var commandRunner`
    - In `PlanCard`: Remove `private var isRunning: Bool` computed property
    - In `PlanCard` body: Remove the `if isRunning` branch (lines 167-173) that shows ProgressView + ElapsedTimerView. Also remove the `else` branch's Button("Execute") (lines 175-186). The plan header HStack should just show the plan number text, Spacer, and StatusBadge -- no execute button, no running indicator.

    **ProjectService.swift:**
    - Remove `var commandRunner: CommandRunnerService?` property (line 35)
    - Remove the SAFE-02 comment block (lines 33-34)
    - Remove the SAFE-02 check in `startMonitoring()` (lines 257-261): the `if let runner = commandRunner...` block that skips reload. Just always reload -- remove the entire if/continue block.
  </action>
  <verify>Run `swift build` from the project root (or `xcodebuild build -scheme GSDMonitor -destination 'platform=macOS'`). The build must succeed with zero errors. Then grep the entire GSDMonitor/ directory for "CommandRunner", "CommandRun", "CommandRequest", "CommandState", "CommandPalette", "CommandHistory", "OutputPanel", "ElapsedTimer", "ProcessActor", "ShellEnvironment", "GSDOutputParser" -- zero matches expected.</verify>
  <done>All 6 files compile cleanly. No references to any command runner types exist in the codebase. The app is a pure monitoring dashboard.</done>
</task>

</tasks>

<verification>
1. `swift build` (or xcodebuild) succeeds with zero errors
2. `grep -r "CommandRunner\|CommandRun\|CommandRequest\|CommandState\|CommandPalette\|CommandHistory\|OutputPanel\|ElapsedTimer\|ProcessActor\|ShellEnvironment\|GSDOutputParser" GSDMonitor/` returns zero matches
3. App launches and displays project sidebar + dashboard without crash
</verification>

<success_criteria>
- All 16 command runner files deleted
- Zero compilation errors
- Zero remaining references to deleted types
- App functions as read-only dashboard
</success_criteria>

<output>
After completion, create `.planning/quick/31-remove-all-v1-2-gsd-command-runner-funct/31-SUMMARY.md`
</output>
