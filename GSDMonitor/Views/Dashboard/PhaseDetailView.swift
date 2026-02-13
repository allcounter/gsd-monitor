import SwiftUI

struct PhaseDetailView: View {
    let phase: Phase
    let project: Project
    var editorService: EditorService = EditorService()

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phase \(phase.number): \(phase.name)")
                        .font(.title2)
                        .fontWeight(.bold)
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

                StatusBadge(phaseStatus: phase.status)

                Button("Close") {
                    dismiss()
                }
                .gsdButtonStyle(.primary)
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Goal section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goal")
                            .font(.headline)

                        if let attributedGoal = try? AttributedString(markdown: phase.goal) {
                            Text(attributedGoal)
                        } else {
                            Text(phase.goal)
                        }
                    }

                    // Dependencies section
                    if !phase.dependencies.isEmpty && !phase.dependencies.allSatisfy({ $0.lowercased().contains("nothing") }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dependencies")
                                .font(.headline)

                            ForEach(phase.dependencies, id: \.self) { dep in
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.turn.down.right")
                                        .foregroundStyle(Theme.textSecondary)
                                        .frame(width: 16)
                                    Text(dep)
                                        .font(.body)
                                        .foregroundStyle(Theme.fg1)
                                }
                            }
                        }
                    }

                    // Requirements section
                    if !phase.requirements.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Requirements")
                                .font(.headline)

                            HStack(spacing: 8) {
                                ForEach(phase.requirements, id: \.self) { reqID in
                                    RequirementBadgeView(requirementID: reqID, project: project)
                                }
                            }
                        }
                    }

                    // Success Criteria section
                    if !phase.milestones.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Success Criteria")
                                .font(.headline)

                            ForEach(Array(phase.milestones.enumerated()), id: \.offset) { index, milestone in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: phase.isComplete ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(phase.isComplete ? Theme.statusComplete : Theme.textSecondary)
                                        .frame(width: 16)
                                    Text(milestone)
                                        .font(.body)
                                        .foregroundStyle(Theme.fg1)
                                }
                            }
                        }
                    }

                    // Plans section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Plans")
                            .font(.headline)

                        if phasePlans.isEmpty {
                            Text("No plans found for this phase")
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            ForEach(phasePlans) { plan in
                                PlanCard(plan: plan, project: project)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 580, idealWidth: 620, minHeight: 500, idealHeight: 700, maxHeight: 800)
        .background {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .hidden()
        }
    }

    // MARK: - Computed Properties

    private var phasePlans: [Plan] {
        let plans = project.plans?.filter { $0.phaseNumber == phase.number } ?? []
        return plans.sorted { $0.planNumber < $1.planNumber }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let plan: Plan
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Plan header
            HStack {
                Text("Plan \(String(format: "%02d", plan.planNumber))")
                    .font(.headline)

                Spacer()

                StatusBadge(planStatus: plan.status)
            }

            // Plan objective
            Text(plan.objective)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)

            // Tasks
            if !plan.tasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.tasks) { task in
                        HStack(spacing: 8) {
                            taskStatusIcon(for: task.status)
                                .foregroundStyle(taskStatusColor(for: task.status))
                                .frame(width: 16)

                            Text(task.name)
                                .font(.body)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Theme.surface)
        .cornerRadius(8)
    }

    private func taskStatusIcon(for status: TaskStatus) -> Image {
        switch status {
        case .pending:
            return Image(systemName: "circle")
        case .inProgress:
            return Image(systemName: "arrow.right")
        case .done:
            return Image(systemName: "checkmark.circle.fill")
        }
    }

    private func taskStatusColor(for status: TaskStatus) -> Color {
        switch status {
        case .pending: return Theme.statusNotStarted
        case .inProgress: return Theme.statusActive
        case .done: return Theme.statusComplete
        }
    }
}
