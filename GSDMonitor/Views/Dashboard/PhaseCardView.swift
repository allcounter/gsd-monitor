import SwiftUI

struct PhaseCardView: View {
    let phase: Phase
    let project: Project
    var projectColorIndex: Int = 0

    private var projectColor: (dark: Color, bright: Color) {
        ProjectColors.forIndex(projectColorIndex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with gradient background
            HStack {
                Text("Phase \(phase.number): \(phase.name)")
                    .font(.headline)
                    .foregroundStyle(Theme.fg0)

                Spacer()

                StatusBadge(phaseStatus: phase.status)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(headerGradient)
                    .opacity(0.25)
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Content area with padding
            VStack(alignment: .leading, spacing: 12) {
                // Goal with markdown rendering
                if !phase.goal.isEmpty {
                    if let attributedGoal = try? AttributedString(markdown: phase.goal) {
                        Text(attributedGoal)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(3)
                    } else {
                        Text(phase.goal)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(3)
                    }
                }

                // Dependencies row
                if !phase.dependencies.isEmpty {
                    HStack(spacing: 6) {
                        Text("Depends on:")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)

                        Text(phase.dependencies.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                }

                // Requirements row
                if !phase.requirements.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Requirements:")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)

                        FlowLayout(spacing: 6) {
                            ForEach(phase.requirements, id: \.self) { reqID in
                                RequirementBadgeView(requirementID: reqID, project: project)
                            }
                        }
                    }
                }

                // Milestones row
                if !phase.milestones.isEmpty {
                    HStack(spacing: 6) {
                        Text("Milestones:")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)

                        Text(phase.milestones.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(Theme.textMuted)
                    }
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)

                        Spacer()

                        Text("\(completionPercentage)%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.textPrimary)
                    }

                    AnimatedProgressBar(
                        progress: phaseProgress,
                        barColor: progressTintColor,
                        height: 6,
                        gradient: progressGradient
                    )
                }
            }
            .padding(16)
        }
        .background(Theme.cardBackground)
        .cornerRadius(12)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
    }

    // MARK: - Computed Properties

    private var phasePlans: [Plan] {
        project.plans?.filter { $0.phaseNumber == phase.number } ?? []
    }

    private var totalPlans: Int {
        phasePlans.count
    }

    private var completedPlans: Int {
        phasePlans.filter { $0.status == .done }.count
    }

    private var completionPercentage: Int {
        // Resolved phases always show 100%
        if phase.status == .done || phase.status == .cancelled || phase.status == .deferred { return 100 }
        guard totalPlans > 0 else { return 0 }
        return Int((Double(completedPlans) / Double(totalPlans)) * 100)
    }

    private var phaseProgress: Double {
        if phase.status == .done || phase.status == .cancelled || phase.status == .deferred { return 1.0 }
        guard totalPlans > 0 else { return 0.0 }
        return Double(completedPlans) / Double(totalPlans)
    }

    private var progressTintColor: Color {
        projectColor.bright
    }

    private var progressGradient: LinearGradient {
        LinearGradient(colors: [projectColor.dark, projectColor.bright], startPoint: .leading, endPoint: .trailing)
    }

    private var headerGradient: LinearGradient {
        switch phase.status {
        case .notStarted:
            return LinearGradient(
                colors: [Theme.bg3, Theme.bg4],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .inProgress:
            return LinearGradient(
                colors: [Theme.yellow, Theme.brightYellow],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .done:
            return LinearGradient(
                colors: [Theme.green, Theme.brightGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .cancelled:
            return LinearGradient(
                colors: [Theme.red, Theme.brightRed],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .deferred:
            return LinearGradient(
                colors: [Theme.orange, Theme.brightOrange],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
