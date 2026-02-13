import SwiftUI

struct MilestoneTimelineView: View {
    let project: Project
    @Binding var selectedMilestone: Milestone?

    var body: some View {
        let milestones = project.roadmap?.milestones ?? []
        if milestones.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(milestones) { milestone in
                        pillButton(for: milestone)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Pill Button

    @ViewBuilder
    private func pillButton(for milestone: Milestone) -> some View {
        let isSelected = selectedMilestone?.name == milestone.name

        Button {
            if isSelected {
                selectedMilestone = nil
            } else {
                selectedMilestone = milestone
            }
        } label: {
            HStack(spacing: 4) {
                Text(milestone.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(pillForeground(milestone: milestone, isSelected: isSelected))

                if milestone.isComplete && !isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.statusComplete)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(pillBackground(milestone: milestone, isSelected: isSelected))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Styling Helpers

    private func pillBackground(milestone: Milestone, isSelected: Bool) -> Color {
        if isSelected {
            return milestone.isComplete ? Theme.statusComplete : Theme.statusActive
        }
        return Theme.bg2
    }

    private func pillForeground(milestone: Milestone, isSelected: Bool) -> Color {
        if isSelected {
            return Theme.bg0
        }
        return milestone.isComplete ? Theme.textSecondary : Theme.fg1
    }
}

private struct MilestoneTimelinePreview: View {
    @SwiftUI.State private var selected: Milestone? = nil

    var body: some View {
        MilestoneTimelineView(
            project: PreviewData.projects[0],
            selectedMilestone: $selected
        )
        .padding()
        .background(Theme.bg0)
    }
}

#Preview {
    MilestoneTimelinePreview()
}
