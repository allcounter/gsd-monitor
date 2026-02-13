import SwiftUI

struct TimelinePhaseNodeView: View {
    let phase: Phase
    let project: Project
    let isLast: Bool
    var isCompact: Bool = false
    var onPhaseSelected: ((Phase) -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left column: circle + connector line
            VStack(spacing: 0) {
                Circle()
                    .fill(nodeColor)
                    .frame(width: isCompact ? 8 : 12, height: isCompact ? 8 : 12)
                    .padding(.top, 4)

                if !isLast {
                    Rectangle()
                        .fill(Theme.bg3)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            // Right column: phase info
            VStack(alignment: .leading, spacing: 4) {
                Text("Phase \(phase.number): \(phase.name)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.fg1)

                HStack(spacing: 6) {
                    AnimatedProgressBar(
                        progress: phaseProgress,
                        barColor: nodeColor,
                        height: isCompact ? 3 : 4
                    )
                    .frame(width: 60)

                    Text("\(Int(phaseProgress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.bottom, isCompact ? 4 : 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onPhaseSelected?(phase)
        }
    }

    // MARK: - Computed Properties

    private var nodeColor: Color {
        switch phase.status {
        case .notStarted: return Theme.statusNotStarted
        case .inProgress: return Theme.statusActive
        case .done: return Theme.statusComplete
        case .cancelled: return Theme.statusCancelled
        case .deferred: return Theme.statusDeferred
        }
    }

    private var phaseProgress: Double {
        if phase.isResolved { return 1.0 }
        let phasePlans = project.plans?.filter { $0.phaseNumber == phase.number } ?? []
        guard !phasePlans.isEmpty else { return 0.0 }
        let done = phasePlans.filter { $0.status == .done }.count
        return Double(done) / Double(phasePlans.count)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 0) {
        TimelinePhaseNodeView(
            phase: PreviewData.projects[0].roadmap!.phases[0],
            project: PreviewData.projects[0],
            isLast: false,
            isCompact: false
        )
        TimelinePhaseNodeView(
            phase: PreviewData.projects[0].roadmap!.phases[1],
            project: PreviewData.projects[0],
            isLast: true,
            isCompact: false
        )
    }
    .padding()
    .background(Theme.bg0)
}
