import SwiftUI

struct SidebarView: View {
    let projectService: ProjectService
    @Binding var selectedProjectID: UUID?

    @SwiftUI.State private var searchText = ""
    @SwiftUI.State private var statusFilter: StatusFilter = .all
    @SwiftUI.State private var showingScanSettings = false

    enum StatusFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case completed = "Completed"
    }

    var body: some View {
        Group {
            if projectService.projects.isEmpty && projectService.scanSources.isEmpty {
                emptyState
            } else if filteredProjects.isEmpty && !searchText.isEmpty {
                noMatchingProjectsState
            } else if filteredProjects.isEmpty && statusFilter != .all {
                noMatchingProjectsState
            } else {
                projectList
            }
        }
    }

    /// Returns grouped projects, always including all scan sources (even empty) when no
    /// search or status filter is active. Scan sources are sorted alphabetically with
    /// ~/Developer always first; "Manually Added" always last.
    private var filteredProjects: [(source: String, projects: [Project])] {
        // Start with groupedProjects from the service
        var groups = projectService.groupedProjects

        // When no search or status filter: include ALL scan sources even if they have 0 projects
        if searchText.isEmpty && statusFilter == .all {
            let homePath = FileManager.default.homeDirectoryForCurrentUser.path
            let existingSourceKeys = Set(groups.map { $0.source })

            // Add any scan sources with 0 projects
            for scanSource in projectService.scanSources {
                let displayKey = scanSource.path.replacingOccurrences(of: homePath, with: "~")
                if !existingSourceKeys.contains(displayKey) {
                    groups.append((source: displayKey, projects: []))
                }
            }

            // Re-sort: ~/Developer first, then alphabetically, "Manually Added" last
            groups.sort { lhs, rhs in
                if lhs.source == "~/Developer" { return true }
                if rhs.source == "~/Developer" { return false }
                if lhs.source == "Manually Added" { return false }
                if rhs.source == "Manually Added" { return true }
                return lhs.source < rhs.source
            }
            return groups
        }

        // With search filter
        if !searchText.isEmpty {
            groups = groups.compactMap { group in
                let filtered = group.projects.filter { project in
                    project.name.localizedCaseInsensitiveContains(searchText)
                }
                return filtered.isEmpty ? nil : (source: group.source, projects: filtered)
            }
        }

        // With status filter
        if statusFilter != .all {
            groups = groups.compactMap { group in
                let filtered = group.projects.filter { project in
                    matchesStatusFilter(project)
                }
                return filtered.isEmpty ? nil : (source: group.source, projects: filtered)
            }
        }

        // Sort: ~/Developer first, then alphabetically, "Manually Added" last
        groups.sort { lhs, rhs in
            if lhs.source == "~/Developer" { return true }
            if rhs.source == "~/Developer" { return false }
            if lhs.source == "Manually Added" { return false }
            if rhs.source == "Manually Added" { return true }
            return lhs.source < rhs.source
        }

        return groups
    }

    private func matchesStatusFilter(_ project: Project) -> Bool {
        guard let roadmap = project.roadmap else { return false }

        switch statusFilter {
        case .all:
            return true
        case .active:
            // Active = at least one phase in progress
            return roadmap.phases.contains { $0.status == .inProgress }
        case .completed:
            // Completed = ALL phases are resolved (done, cancelled, or deferred)
            return !roadmap.phases.isEmpty && roadmap.phases.allSatisfy { $0.isResolved }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label {
                Text("No Projects Found")
                    .foregroundStyle(Theme.fg1)
            } icon: {
                Image(systemName: "folder.badge.questionmark")
                    .foregroundStyle(Theme.textSecondary)
            }
        } description: {
            Text("GSD projects will appear here when discovered in ~/Developer")
                .foregroundStyle(Theme.fg4)
        }
    }

    private var noMatchingProjectsState: some View {
        ContentUnavailableView {
            Label {
                Text("No Matching Projects")
                    .foregroundStyle(Theme.fg1)
            } icon: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.textSecondary)
            }
        } description: {
            Text("Try adjusting your search or filter")
                .foregroundStyle(Theme.fg4)
        }
    }

    private var projectList: some View {
        VStack(spacing: 0) {
            // Status filter — always visible
            HStack(spacing: 4) {
                ForEach(StatusFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            statusFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption)
                            .fontWeight(statusFilter == filter ? .semibold : .regular)
                            .foregroundStyle(statusFilter == filter ? Theme.fg0 : Theme.fg4)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(statusFilter == filter ? Theme.bg3 : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.bg0)

            List(selection: $selectedProjectID) {
                ForEach(filteredProjects, id: \.source) { group in
                    projectSection(for: group)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg0)
        }
        .focusEffectDisabled()
        .searchable(text: $searchText, prompt: "Search projects")
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addButton
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    showingScanSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingScanSettings, arrowEdge: .bottom) {
                    ScanDirectoriesPopoverView(projectService: projectService)
                        .frame(width: 340)
                }
                .padding(8)
            }
            .background(Theme.bg0)
        }
    }

    /// Global color index: stable rainbow across all projects sorted by name
    private func globalColorIndex(for project: Project) -> Int {
        let allSorted = projectService.projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return allSorted.firstIndex(where: { $0.id == project.id }) ?? 0
    }

    @ViewBuilder
    private func projectSection(for group: (source: String, projects: [Project])) -> some View {
        Section {
            if group.projects.isEmpty {
                    Text("No projects found")
                        .font(.caption)
                        .foregroundStyle(Theme.fg4)
                        .italic()
                        .padding(.vertical, 4)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .listRowBackground(Theme.bg0)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(group.projects) { project in
                        ProjectRow(
                            project: project,
                            projectName: project.name,
                            isSelected: selectedProjectID == project.id,
                            isManuallyAdded: group.source == "Manually Added",
                            onRemove: {
                                projectService.removeManualProject(project)
                            },
                            colorIndex: globalColorIndex(for: project)
                        )
                        .tag(project.id)
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        .listRowBackground(Theme.bg0)
                        .listRowSeparator(.hidden)
                    }
                }
        } header: {
            HStack {
                Text(group.source)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                Spacer()
                Text("\(group.projects.count)")
                    .font(.caption2)
                    .foregroundStyle(Theme.fg4)
            }
        }
    }

    private var addButton: some View {
        Button(action: addProject) {
            Label("Add Project", systemImage: "plus")
        }
    }

    private func addProject() {
        _Concurrency.Task {
            await projectService.addProjectManually()
        }
    }
}

private enum ProjectStatus {
    case notStarted
    case active
    case complete
}

private struct ProjectRow: View {
    let project: Project
    let projectName: String
    let isSelected: Bool
    let isManuallyAdded: Bool
    let onRemove: () -> Void
    var colorIndex: Int = 0

    // MARK: - Single color source — everything derives from this

    private var color: (dark: Color, bright: Color) {
        ProjectColors.forIndex(colorIndex)
    }

    private var projectStatus: ProjectStatus {
        guard let roadmap = project.roadmap else { return .notStarted }
        if !roadmap.phases.isEmpty && roadmap.phases.allSatisfy({ $0.isResolved }) {
            return .complete
        }
        if roadmap.phases.contains(where: { $0.status == .inProgress }) {
            return .active
        }
        return .notStarted
    }

    // MARK: - Derived appearance (all from `color`)

    private var stripe: Color { color.dark }

    private var progressBar: Color { color.bright }

    private var statusIcon: String {
        switch projectStatus {
        case .notStarted: "folder"
        case .active:     "folder.fill"
        case .complete:   "checkmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(project.name)
                        .font(.body)
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    Image(systemName: statusIcon)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(stripe)
                        .font(.system(size: 14))

                    if let roadmap = project.roadmap {
                        Text(phaseCountText(roadmap: roadmap))
                            .font(.caption2)
                            .foregroundStyle(Theme.textMuted)
                    }
                }

                Text(project.path.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                    .font(.caption2)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if project.roadmap != nil {
                HStack(spacing: 6) {
                    AnimatedProgressBar(
                        progress: progressValue(),
                        barColor: progressBar,
                        height: 4
                    )

                    Text("\(progressPercentage())%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.textMuted)
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            isSelected ? Theme.bg2 : Theme.bg1,
                            color.dark.opacity(isSelected ? 0.18 : 0.06)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(alignment: .leading) {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: 8,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                    .fill(stripe)
                    .frame(width: 4)
                    .shadow(
                        color: isSelected ? color.bright.opacity(0.5) : .clear,
                        radius: isSelected ? 6 : 0,
                        x: 0, y: 0
                    )
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(color.dark.opacity(isSelected ? 0.6 : 0), lineWidth: 1.5)
        )
        .animation(.easeOut(duration: 0.25), value: isSelected)
        .contextMenu {
            Button("Vis i Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path.path)
            }
            if isManuallyAdded {
                Divider()
                Button("Remove from GSD Monitor", role: .destructive) {
                    onRemove()
                }
            }
        }
    }

    private func progressValue() -> Double {
        guard let roadmap = project.roadmap, !roadmap.phases.isEmpty else { return 0 }
        let plans = project.plans ?? []

        let phaseContributions = roadmap.phases.map { phase -> Double in
            if phase.isResolved { return 1.0 }
            let phasePlans = plans.filter { $0.phaseNumber == phase.number }
            guard !phasePlans.isEmpty else { return 0.0 }
            let done = phasePlans.filter { $0.status == .done }.count
            return Double(done) / Double(phasePlans.count)
        }

        return phaseContributions.reduce(0, +) / Double(roadmap.phases.count)
    }

    private func progressPercentage() -> Int {
        Int(progressValue() * 100)
    }

    private func phaseCountText(roadmap: Roadmap) -> String {
        let completed = roadmap.phases.filter { $0.isResolved }.count
        let total = roadmap.phases.count
        return "\(completed)/\(total)"
    }
}

#Preview("Empty State") {
    let service = ProjectService()
    return SidebarView(projectService: service, selectedProjectID: .constant(nil))
}

#Preview("With Projects") {
    let service = ProjectService()
    service.projects = PreviewData.projects
    return SidebarView(
        projectService: service,
        selectedProjectID: .constant(PreviewData.projects.first?.id)
    )
}
