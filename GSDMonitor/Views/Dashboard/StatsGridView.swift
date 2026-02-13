import SwiftUI

struct StatsGridView: View {
    let project: Project

    private let columns = Array(repeating: GridItem(.flexible(minimum: 80), spacing: 12), count: 4)

    var body: some View {
        guard project.roadmap?.phases.isEmpty == false else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                if let milestoneName = project.state?.currentMilestone {
                    Text(milestoneName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    StatCardView(
                        icon: "chart.bar.fill",
                        value: "\(totalPhases)",
                        label: "Total Phases",
                        accentColor: Theme.brightBlue
                    )
                    StatCardView(
                        icon: "percent",
                        value: "\(completionPercent)%",
                        label: "Complete",
                        accentColor: Theme.brightGreen
                    )
                    StatCardView(
                        icon: "bolt.fill",
                        value: "\(activePhases)",
                        label: "Active",
                        accentColor: Theme.brightYellow
                    )
                    StatCardView(
                        icon: "clock.fill",
                        value: executionTime,
                        label: "Time Spent",
                        accentColor: Theme.brightOrange
                    )
                }
            }
        )
    }

    // MARK: - Computed Properties

    private var totalPhases: Int {
        project.roadmap?.phases.count ?? 0
    }

    private var completionPercent: Int {
        guard let roadmap = project.roadmap, !roadmap.phases.isEmpty else { return 0 }
        let plans = project.plans ?? []
        let phaseContributions = roadmap.phases.map { phase -> Double in
            if phase.status == .done || phase.status == .cancelled || phase.status == .deferred { return 1.0 }
            let phasePlans = plans.filter { $0.phaseNumber == phase.number }
            guard !phasePlans.isEmpty else { return 0.0 }
            let done = phasePlans.filter { $0.status == .done }.count
            return Double(done) / Double(phasePlans.count)
        }
        return Int((phaseContributions.reduce(0, +) / Double(roadmap.phases.count)) * 100)
    }

    private var activePhases: Int {
        project.roadmap?.phases.filter { $0.status == .inProgress }.count ?? 0
    }

    private var executionTime: String {
        project.state?.totalExecutionTime ?? "\u{2014}"
    }
}

#Preview {
    StatsGridView(project: PreviewData.projects[0])
        .padding()
        .background(Theme.bg0)
}
