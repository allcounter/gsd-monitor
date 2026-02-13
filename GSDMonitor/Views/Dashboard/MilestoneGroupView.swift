import SwiftUI

struct MilestoneGroupView: View {
    let milestone: Milestone
    let phases: [Phase]
    let project: Project
    var onPhaseSelected: ((Phase) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Separator badge row
            HStack {
                Text(milestone.isComplete ? "\(milestone.name) \u{2713}" : milestone.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(milestone.isComplete ? Theme.bg0 : Theme.fg1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(milestone.isComplete ? Theme.statusComplete : Theme.bg2)
                    .clipShape(Capsule())

                if milestone.isComplete {
                    Text("\(completedCount)/\(phases.count) phases")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()
            }
            .padding(.vertical, 8)

            // Phase nodes — only for active/incomplete milestones
            if !milestone.isComplete {
                ForEach(Array(phases.enumerated()), id: \.element.id) { idx, phase in
                    TimelinePhaseNodeView(
                        phase: phase,
                        project: project,
                        isLast: idx == phases.count - 1,
                        isCompact: false,
                        onPhaseSelected: onPhaseSelected
                    )
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var completedCount: Int {
        phases.filter { $0.isResolved }.count
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            MilestoneGroupView(
                milestone: Milestone(name: "v1.0 MVP", phaseNumbers: [1, 2, 3, 4, 5], isComplete: true),
                phases: PreviewData.projects[0].roadmap?.phases ?? [],
                project: PreviewData.projects[0]
            )
            MilestoneGroupView(
                milestone: Milestone(name: "v1.1 Visual Overhaul", phaseNumbers: [6, 7, 8, 9, 10, 11, 12], isComplete: false),
                phases: PreviewData.projects[0].roadmap?.phases ?? [],
                project: PreviewData.projects[0]
            )
        }
        .padding()
        .background(Theme.bg0)
    }
}
