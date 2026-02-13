import SwiftUI

struct RequirementDetailSheet: View {
    let requirement: Requirement
    let project: Project

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(requirement.id)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(requirement.category)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Button("Done") {
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
                    // Definition section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Definition")
                            .font(.headline)

                        Text(requirement.description)
                            .textSelection(.enabled)
                    }

                    // Mapped to Phases section
                    if !mappedPhases.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Mapped to Phases")
                                .font(.headline)

                            ForEach(mappedPhases) { phase in
                                HStack {
                                    Text("Phase \(phase.number): \(phase.name)")

                                    Spacer()

                                    StatusBadge(phaseStatus: phase.status)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Related Plans section (REQ-03 cross-reference)
                    if !relatedPlans.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Related Plans")
                                .font(.headline)

                            ForEach(relatedPlans) { plan in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Plan \(plan.phaseNumber)-\(String(format: "%02d", plan.planNumber))")
                                            .font(.subheadline)
                                            .fontWeight(.medium)

                                        Text(plan.objective)
                                            .font(.caption)
                                            .foregroundStyle(Theme.textSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    StatusBadge(planStatus: plan.status)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Status section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.headline)

                        HStack(spacing: 8) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)

                            Text(statusText)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 450)
    }

    // MARK: - Computed Properties

    private var mappedPhases: [Phase] {
        guard let roadmap = project.roadmap else { return [] }
        return roadmap.phases.filter { requirement.mappedToPhases.contains($0.number) }
    }

    private var relatedPlans: [Plan] {
        project.plans?.filter { requirement.mappedToPhases.contains($0.phaseNumber) } ?? []
    }

    private var statusColor: Color {
        switch requirement.status {
        case .active: return Theme.requirementActive
        case .validated: return Theme.requirementValidated
        case .deferred: return Theme.requirementDeferred
        }
    }

    private var statusText: String {
        switch requirement.status {
        case .active: return "Active"
        case .validated: return "Validated"
        case .deferred: return "Deferred"
        }
    }
}

