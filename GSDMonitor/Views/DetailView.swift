import SwiftUI

struct DetailView: View {
    let selectedProject: Project?
    var projectName: String = ""
    var projectColorIndex: Int = 0
    @Binding var selectedPhase: Phase?
    @Binding var scrollToPhaseNumber: Int?

    private var projectColor: (dark: Color, bright: Color) {
        ProjectColors.forIndex(projectColorIndex)
    }

    @SwiftUI.State private var editorService = EditorService()
    @SwiftUI.State private var selectedMilestone: Milestone?

    var body: some View {
            if let project = selectedProject {
                dashboardContent(for: project)
                .onAppear {
                        autoSelectActiveMilestone(for: project)
                    }
                    .onChange(of: selectedProject?.id) {
                        autoSelectActiveMilestone(for: selectedProject)
                    }
                    .sheet(item: $selectedPhase) { phase in
                        PhaseDetailView(phase: phase, project: project, editorService: editorService)
                    }
            } else {
                ContentUnavailableView {
                    Label {
                        Text("Select a Project")
                            .foregroundStyle(Theme.fg1)
                    } icon: {
                        Image(systemName: "sidebar.left")
                            .foregroundStyle(Theme.textSecondary)
                    }
                } description: {
                    Text("Choose a project from the sidebar to view its roadmap")
                        .foregroundStyle(Theme.fg4)
                }
            }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(for project: Project) -> some View {
        VStack(spacing: 0) {
            // Pinned header section
            VStack(alignment: .leading, spacing: 24) {
                // Project header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(project.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        if let state = project.state {
                            Text("Phase \(state.currentPhase ?? 0), Plan \(state.currentPlan ?? 0)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    Spacer()

                    if !editorService.installedEditors.isEmpty {
                        Button {
                            editorService.openFile(project.path)
                        } label: {
                            Label("Open in Editor", systemImage: "arrow.up.forward.app")
                        }
                        .gsdButtonStyle(.secondary)
                    }
                }

                // Overall project progress
                if let roadmap = project.roadmap, !roadmap.phases.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Overall Progress")
                                .font(.headline)

                            Spacer()

                            Text("\(Int(overallProgress(for: project) * 100))%")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        AnimatedProgressBar(
                            progress: overallProgress(for: project),
                            barColor: projectColor.bright,
                            height: 6,
                            gradient: LinearGradient(
                                colors: [projectColor.dark, projectColor.bright],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                }

                StatsGridView(project: project)

                if let driftCommits = project.driftCommits, !driftCommits.isEmpty {
                    DriftSectionView(driftCommits: driftCommits)
                }

                if let roadmap = project.roadmap, !roadmap.milestones.isEmpty {
                    MilestoneTimelineView(
                        project: project,
                        selectedMilestone: $selectedMilestone
                    )
                }
            }
            .padding()
            .background(Theme.bg0)

            Divider()
                .background(Theme.bg2)

            // Scrollable phases section
            if let roadmap = project.roadmap, !roadmap.phases.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(selectedMilestone != nil ? selectedMilestone!.name : "All Phases")
                                    .font(.headline)
                                Spacer()
                            }

                            ForEach(filteredPhases(for: roadmap)) { phase in
                                PhaseCardView(phase: phase, project: project, projectColorIndex: projectColorIndex)
                                    .id(phase.id)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedPhase = phase
                                    }
                            }
                        }
                        .padding([.horizontal, .bottom])
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: scrollToPhaseNumber) { _, targetNumber in
                        guard let targetNumber = targetNumber,
                              let roadmap = project.roadmap else { return }
                        // Find the target phase
                        guard let targetPhase = roadmap.phases.first(where: { $0.number == targetNumber }) else { return }
                        // Find milestone containing the phase and select it so it's visible
                        if let milestone = roadmap.milestones.first(where: { $0.phaseNumbers.contains(targetNumber) }) {
                            selectedMilestone = milestone
                        } else {
                            selectedMilestone = nil
                        }
                        // Scroll to phase with slight delay so the milestone filter takes effect first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(targetPhase.id, anchor: .top)
                            }
                            scrollToPhaseNumber = nil
                        }
                    }
                    .mask(
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 20)

                            Color.black
                        }
                    )
                } // end ScrollViewReader
            } else {
                ContentUnavailableView {
                    Label {
                        Text("No Roadmap Data")
                            .foregroundStyle(Theme.fg1)
                    } icon: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(Theme.textSecondary)
                    }
                } description: {
                    Text("This project doesn't have a ROADMAP.md file yet")
                        .foregroundStyle(Theme.fg4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Computed Properties

    private func filteredPhases(for roadmap: Roadmap) -> [Phase] {
        let sorted = roadmap.phases.sorted { $0.number < $1.number }
        guard let milestone = selectedMilestone else {
            return sorted
        }
        return sorted.filter { milestone.phaseNumbers.contains($0.number) }
    }

    // MARK: - Helper Functions

    private func autoSelectActiveMilestone(for project: Project?) {
        guard let milestones = project?.roadmap?.milestones else {
            selectedMilestone = nil
            return
        }
        // Auto-select the first incomplete milestone (active milestone)
        if let active = milestones.first(where: { !$0.isComplete }) {
            selectedMilestone = active
        } else {
            // All milestones complete — show all phases
            selectedMilestone = nil
        }
    }

    private func overallProgress(for project: Project) -> Double {
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
}

#Preview("No Selection") {
    DetailView(selectedProject: nil, selectedPhase: .constant(nil), scrollToPhaseNumber: .constant(nil))
}

#Preview("With Selection") {
    DetailView(selectedProject: PreviewData.projects.first, selectedPhase: .constant(nil), scrollToPhaseNumber: .constant(nil))
}

#Preview("Minimal Project") {
    DetailView(selectedProject: PreviewData.projects[1], selectedPhase: .constant(nil), scrollToPhaseNumber: .constant(nil))
}
