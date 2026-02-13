import SwiftUI

struct StatusBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(Theme.bg0)  // Dark text on bright badge
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Convenience Initializers

extension StatusBadge {
    /// Phase status badge
    init(phaseStatus: PhaseStatus) {
        switch phaseStatus {
        case .notStarted:
            self.init(label: "not started", color: Theme.statusNotStarted)
        case .inProgress:
            self.init(label: "in progress", color: Theme.statusActive)
        case .done:
            self.init(label: "complete", color: Theme.statusComplete)
        case .cancelled:
            self.init(label: "cancelled", color: Theme.statusCancelled)
        case .deferred:
            self.init(label: "deferred", color: Theme.statusDeferred)
        }
    }

    /// Plan status badge
    init(planStatus: PlanStatus) {
        switch planStatus {
        case .pending:
            self.init(label: "pending", color: Theme.statusNotStarted)
        case .inProgress:
            self.init(label: "in progress", color: Theme.statusActive)
        case .done:
            self.init(label: "complete", color: Theme.statusComplete)
        }
    }

    /// Task status badge
    init(taskStatus: TaskStatus) {
        switch taskStatus {
        case .pending:
            self.init(label: "pending", color: Theme.statusNotStarted)
        case .inProgress:
            self.init(label: "in progress", color: Theme.statusActive)
        case .done:
            self.init(label: "complete", color: Theme.statusComplete)
        }
    }

    /// Requirement status badge
    init(requirementStatus: RequirementStatus) {
        switch requirementStatus {
        case .active:
            self.init(label: "active", color: Theme.requirementActive)
        case .validated:
            self.init(label: "validated", color: Theme.requirementValidated)
        case .deferred:
            self.init(label: "deferred", color: Theme.requirementDeferred)
        }
    }
}
