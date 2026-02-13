import Foundation
import SwiftUI
import AsyncAlgorithms

// MARK: - Scan Source State

struct ScanSourceState {
    var isScanning: Bool = false
    var lastScannedAt: Date? = nil
    var isAccessible: Bool = true
}

@MainActor
@Observable
final class ProjectService {
    var projects: [Project] = []
    var scanSourceStates: [String: ScanSourceState] = [:]
    var duplicateWarningPath: String? = nil

    private var isLoading = false

    var scanSources: [URL] {
        get {
            // Load from UserDefaults
            if let paths = UserDefaults.standard.stringArray(forKey: "scanSources") {
                return paths.map { URL(fileURLWithPath: $0) }
            }
            // Default to ~/Developer
            return [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer")]
        }
        set {
            // Save to UserDefaults
            let paths = newValue.map { $0.path }
            UserDefaults.standard.set(paths, forKey: "scanSources")
        }
    }

    private let discoveryService = ProjectDiscoveryService()
    private let bookmarkService = BookmarkService()
    private let roadmapParser = RoadmapParser()
    private let stateParser = StateParser()
    private let requirementsParser = RequirementsParser()
    private let planParser = PlanParser()
    private let configParser = ConfigParser()
    private let gitLogParser = GitLogParser()

    private let fileWatcher = FileWatcherService()
    private var monitoringTask: _Concurrency.Task<Void, Never>?

    private let scanSourceWatcher = FileWatcherService()
    private var scanSourceMonitoringTask: _Concurrency.Task<Void, Never>?

    // Track manually added project paths
    private var manualProjectPaths: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: "manualProjectPaths") ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "manualProjectPaths")
        }
    }

    // MARK: - Lifecycle

    func loadProjects() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        var newProjects: [Project] = []

        // Mark all scan sources as scanning
        let currentSources = scanSources
        for source in currentSources {
            scanSourceStates[source.path, default: ScanSourceState()].isScanning = true
            // Check accessibility
            var isDir: ObjCBool = false
            let accessible = FileManager.default.fileExists(atPath: source.path, isDirectory: &isDir) && isDir.boolValue
            scanSourceStates[source.path, default: ScanSourceState()].isAccessible = accessible
        }

        // 1. Load manually added projects from bookmarks
        let bookmarkIdentifiers = bookmarkService.allBookmarkIdentifiers()
        for identifier in bookmarkIdentifiers {
            if let url = try? bookmarkService.resolveBookmark(for: identifier) {
                let didAccess = url.startAccessingSecurityScopedResource()
                defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

                // Verify directory still exists and has .planning/
                let planningURL = url.appendingPathComponent(".planning")
                if FileManager.default.fileExists(atPath: planningURL.path) {
                    if let project = await parseProject(at: url, scanSource: nil) {
                        newProjects.append(project)
                    }
                } else {
                    // Project directory disappeared, remove bookmark
                    bookmarkService.removeBookmark(for: identifier)
                    var paths = manualProjectPaths
                    paths.remove(url.path)
                    manualProjectPaths = paths
                }
            }
        }

        // 2. Scan configured scan sources
        let discoveredProjects = await discoveryService.discoverProjects(in: currentSources)

        // 3. Parse each discovered project
        for discovered in discoveredProjects {
            if let project = await parseProject(at: discovered.path, scanSource: discovered.scanSource) {
                newProjects.append(project)
            }
        }

        // 4. Remove duplicates (prefer manual over discovered)
        var seenPaths: Set<String> = []
        var deduplicated: [Project] = []

        // Manual projects first
        for project in newProjects where manualProjectPaths.contains(project.path.path) {
            if !seenPaths.contains(project.path.path) {
                deduplicated.append(project)
                seenPaths.insert(project.path.path)
            }
        }

        // Then discovered projects
        for project in newProjects where !manualProjectPaths.contains(project.path.path) {
            if !seenPaths.contains(project.path.path) {
                deduplicated.append(project)
                seenPaths.insert(project.path.path)
            }
        }

        projects = deduplicated

        // Mark all scan sources as done scanning
        let scanTime = Date()
        for source in currentSources {
            scanSourceStates[source.path, default: ScanSourceState()].isScanning = false
            scanSourceStates[source.path, default: ScanSourceState()].lastScannedAt = scanTime
        }

        // Start watching for file changes
        startMonitoring()
        startScanSourceMonitoring()
    }

    // MARK: - Manual Project Management

    func addProjectManually() async {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a directory containing a .planning folder"

        let response = await panel.begin()
        guard response == .OK, let url = panel.url else {
            return
        }

        // Validate .planning/ exists
        let planningURL = url.appendingPathComponent(".planning")
        guard FileManager.default.fileExists(atPath: planningURL.path) else {
            return
        }

        // Validate ROADMAP.md exists
        let roadmapURL = planningURL.appendingPathComponent("ROADMAP.md")
        guard FileManager.default.fileExists(atPath: roadmapURL.path) else {
            return
        }

        // Save bookmark
        let identifier = url.path
        try? bookmarkService.saveBookmark(for: url, identifier: identifier)

        // Track as manual project
        var paths = manualProjectPaths
        paths.insert(url.path)
        manualProjectPaths = paths

        // Parse and add to projects
        if let project = await parseProject(at: url, scanSource: nil) {
            // Remove existing entry if present (to avoid duplicates)
            projects.removeAll { $0.path.path == project.path.path }
            projects.append(project)
        }

        // Restart monitoring to include new project path
        stopMonitoring()
        startMonitoring()
        startScanSourceMonitoring()
    }

    func removeManualProject(_ project: Project) {
        // Remove from projects array
        projects.removeAll { $0.id == project.id }

        // Remove bookmark
        bookmarkService.removeBookmark(for: project.path.path)

        // Remove from manual tracking
        var paths = manualProjectPaths
        paths.remove(project.path.path)
        manualProjectPaths = paths

        // Restart monitoring to exclude removed project path
        stopMonitoring()
        startMonitoring()
        startScanSourceMonitoring()
    }

    // MARK: - Scan Directory Management

    func addScanDirectory(_ url: URL) {
        let standardized = url.standardizedFileURL
        // Guard duplicate
        if scanSources.contains(where: { $0.standardizedFileURL.path == standardized.path }) {
            duplicateWarningPath = standardized.path
            // Auto-clear after 3 seconds
            let path = standardized.path
            _Concurrency.Task { @MainActor in
                try? await _Concurrency.Task.sleep(for: .seconds(3))
                if duplicateWarningPath == path {
                    duplicateWarningPath = nil
                }
            }
            return
        }

        // Clear any existing warning
        duplicateWarningPath = nil

        // Append to scanSources (triggers UserDefaults write)
        var sources = scanSources
        sources.append(url)
        scanSources = sources

        // Check accessibility
        var isDir: ObjCBool = false
        let accessible = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
        scanSourceStates[url.path] = ScanSourceState(isScanning: true, lastScannedAt: nil, isAccessible: accessible)

        // Scan the new directory in background
        _Concurrency.Task {
            let discovered = await discoveryService.discoverProjects(in: [url])
            for d in discovered {
                if let project = await parseProject(at: d.path, scanSource: d.scanSource) {
                    if !projects.contains(where: { $0.path.path == project.path.path }) {
                        projects.append(project)
                    }
                }
            }

            // Mark scan complete
            scanSourceStates[url.path, default: ScanSourceState()].isScanning = false
            scanSourceStates[url.path, default: ScanSourceState()].lastScannedAt = Date()

            // Restart monitoring to include new directory
            // stopMonitoring() nils scanSourceMonitoringTask, allowing startScanSourceMonitoring() to run
            stopMonitoring()
            startMonitoring()
            startScanSourceMonitoring()
        }
    }

    func removeScanDirectory(_ url: URL) {
        // Guard: do NOT allow removing the default ~/Developer source
        let developerURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Developer")
        guard url.path != developerURL.path else { return }

        // Remove projects from this source (but not manually added projects)
        projects.removeAll { project in
            project.path.path.hasPrefix(url.path) && !manualProjectPaths.contains(project.path.path)
        }

        // Remove from scanSources
        var sources = scanSources
        sources.removeAll { $0.path == url.path }
        scanSources = sources

        // Remove scan state
        scanSourceStates.removeValue(forKey: url.path)

        // Clear any duplicate warning for this path
        if duplicateWarningPath == url.path {
            duplicateWarningPath = nil
        }

        // Restart monitoring without this directory
        // stopMonitoring() nils scanSourceMonitoringTask, allowing startScanSourceMonitoring() to run
        stopMonitoring()
        startMonitoring()
        startScanSourceMonitoring()
    }

    func addScanDirectoryViaPanel() async {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a directory to scan for GSD projects"

        let response = await panel.begin()
        guard response == .OK, let url = panel.url else { return }

        addScanDirectory(url)
    }

    // MARK: - Project Grouping

    var groupedProjects: [(source: String, projects: [Project])] {
        var groups: [String: [Project]] = [:]

        for project in projects {
            if manualProjectPaths.contains(project.path.path) {
                groups["Manually Added", default: []].append(project)
            } else {
                // Find which scan source this project belongs to
                let sourceKey = scanSources.first { scanSource in
                    project.path.path.hasPrefix(scanSource.path)
                }.map { url in
                    // Display-friendly path with tilde
                    url.path.replacingOccurrences(
                        of: FileManager.default.homeDirectoryForCurrentUser.path,
                        with: "~"
                    )
                } ?? "Unknown"

                groups[sourceKey, default: []].append(project)
            }
        }

        // Sort groups: scan sources alphabetically, then "Manually Added" last
        let sortedKeys = groups.keys.sorted { lhs, rhs in
            if lhs == "Manually Added" { return false }
            if rhs == "Manually Added" { return true }
            return lhs < rhs
        }

        return sortedKeys.map { key in
            let sortedProjects = groups[key]!.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return (source: key, projects: sortedProjects)
        }
    }

    // MARK: - File Monitoring

    func reloadProject(at projectPath: URL) async {
        // Determine scan source (nil if manual)
        let scanSource: URL? = manualProjectPaths.contains(projectPath.path) ? nil : scanSources.first { projectPath.path.hasPrefix($0.path) }

        // Re-parse the project
        if let updated = await parseProject(at: projectPath, scanSource: scanSource) {
            // Find index AFTER await — array may have changed during async parsing
            if let index = projects.firstIndex(where: { $0.path.path == projectPath.path }) {
                projects[index] = updated
            }
        }
    }

    func startMonitoring() {
        // Collect all .planning/ paths from loaded projects
        let planningPaths = projects.map { $0.path.appendingPathComponent(".planning") }

        guard !planningPaths.isEmpty else { return }

        let eventStream = fileWatcher.watch(paths: planningPaths)

        monitoringTask = _Concurrency.Task {
            // Use debounce to coalesce rapid changes (Git commits, multi-file saves)
            for await changedURLs in eventStream.debounce(for: .seconds(1)) {
                // Determine which projects were affected
                var affectedProjects: Set<String> = []
                for url in changedURLs {
                    // Find the project root by looking for the .planning/ segment
                    let path = url.path
                    if let range = path.range(of: "/.planning") {
                        let projectRoot = String(path[path.startIndex..<range.lowerBound])
                        affectedProjects.insert(projectRoot)
                    }
                }

                // Reload each affected project
                for projectPath in affectedProjects {
                    await reloadProject(at: URL(fileURLWithPath: projectPath))
                }
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        fileWatcher.stopWatching()

        scanSourceMonitoringTask?.cancel()
        scanSourceMonitoringTask = nil
        scanSourceWatcher.stopWatching()
    }

    func startScanSourceMonitoring() {
        // Already running — don't restart (prevents infinite loop from loadProjects -> watcher -> loadProjects)
        guard scanSourceMonitoringTask == nil else { return }

        let paths = scanSources
        guard !paths.isEmpty else { return }

        let eventStream = scanSourceWatcher.watch(paths: paths)

        scanSourceMonitoringTask = _Concurrency.Task {
            // Use longer debounce (2s vs 1s) — directory operations like git clone create many events
            for await _ in eventStream.debounce(for: .seconds(2)) {
                await loadProjects()
            }
        }
    }

    // MARK: - Helper Methods

    private func reconcilePhaseStatuses(roadmap: Roadmap, plans: [Plan]) -> Roadmap {
        // Group plans by phase number
        let plansByPhase = Dictionary(grouping: plans, by: \.phaseNumber)

        // Map over phases, updating status based on plan completion
        let updatedPhases = roadmap.phases.map { phase -> Phase in
            guard let phasePlans = plansByPhase[phase.number], !phasePlans.isEmpty else {
                // No plans for this phase, keep original status
                return phase
            }

            // Determine new status based on plan completion
            let allDone = phasePlans.allSatisfy { $0.status == .done }
            let anyStarted = phasePlans.contains { $0.status == .done || $0.status == .inProgress }

            let newStatus: PhaseStatus
            if allDone {
                newStatus = .done
            } else if anyStarted {
                newStatus = .inProgress
            } else {
                newStatus = phase.status
            }

            // Return new Phase with updated status
            return Phase(
                id: phase.id,
                number: phase.number,
                name: phase.name,
                goal: phase.goal,
                dependencies: phase.dependencies,
                requirements: phase.requirements,
                milestones: phase.milestones,
                status: newStatus
            )
        }

        return Roadmap(projectName: roadmap.projectName, phases: updatedPhases, milestones: roadmap.milestones)
    }

    private func parseProject(at url: URL, scanSource: URL?) async -> Project? {
        let planningURL = url.appendingPathComponent(".planning")

        // Read and parse files
        let roadmap = readFileContent(at: planningURL.appendingPathComponent("ROADMAP.md"))
            .flatMap { try? roadmapParser.parse($0) }

        let state = readFileContent(at: planningURL.appendingPathComponent("STATE.md"))
            .flatMap { try? stateParser.parse($0) }

        let configURL = planningURL.appendingPathComponent("config.json")
        let config = (try? Data(contentsOf: configURL))
            .flatMap { try? configParser.parse($0) }

        // Parse requirements from REQUIREMENTS.md
        let requirements = readFileContent(at: planningURL.appendingPathComponent("REQUIREMENTS.md"))
            .map { requirementsParser.parse($0) }

        // Parse all PLAN.md files from phases/ subdirectories
        let plans = parsePlans(from: planningURL.appendingPathComponent("phases"))

        // Reconcile phase statuses based on actual plan completion
        let finalRoadmap = roadmap.map { reconcilePhaseStatuses(roadmap: $0, plans: plans) } ?? roadmap

        // Project name from roadmap, fallback to directory name
        let name = finalRoadmap?.projectName ?? url.lastPathComponent

        // Parse drift commits (we already know .planning/ exists since we parsed from it above)
        let driftCommits = await gitLogParser.parseDriftCommits(at: url)

        return Project(
            name: name,
            path: url,
            roadmap: finalRoadmap,
            state: state,
            config: config,
            requirements: requirements,
            plans: plans.isEmpty ? nil : plans,
            driftCommits: driftCommits.isEmpty ? nil : driftCommits
        )
    }

    private func parsePlans(from phasesDir: URL) -> [Plan] {
        var plans: [Plan] = []

        guard let enumerator = FileManager.default.enumerator(at: phasesDir, includingPropertiesForKeys: nil) else {
            return plans
        }

        for case let fileURL as URL in enumerator where fileURL.lastPathComponent.hasSuffix("-PLAN.md") {
            if let content = readFileContent(at: fileURL),
               let plan = planParser.parse(content) {

                // Check if corresponding SUMMARY.md exists
                let summaryFilename = fileURL.lastPathComponent.replacingOccurrences(of: "-PLAN.md", with: "-SUMMARY.md")
                let summaryURL = fileURL.deletingLastPathComponent().appendingPathComponent(summaryFilename)
                let hasSummary = FileManager.default.fileExists(atPath: summaryURL.path)

                if hasSummary {
                    // Plan is complete - mark plan and all tasks as done
                    let donePlan = Plan(
                        phaseNumber: plan.phaseNumber,
                        planNumber: plan.planNumber,
                        objective: plan.objective,
                        tasks: plan.tasks.map { Task(name: $0.name, type: $0.type, status: .done) },
                        status: .done
                    )
                    plans.append(donePlan)
                } else {
                    // Plan is still pending
                    plans.append(plan)
                }
            }
        }

        return plans
    }

    private func readFileContent(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
}
