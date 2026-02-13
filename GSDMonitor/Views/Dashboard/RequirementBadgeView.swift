import SwiftUI

struct RequirementBadgeView: View {
    let requirementID: String
    let project: Project

    @SwiftUI.State private var showDetail = false

    var body: some View {
        Button(action: { showDetail = true }) {
            Text(requirementID)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Theme.bg0)
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badgeColor)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .sheet(isPresented: $showDetail) {
            if let requirement = requirement {
                RequirementDetailSheet(requirement: requirement, project: project)
            }
        }
    }

    // MARK: - Computed Properties

    private var requirement: Requirement? {
        project.requirements?.first(where: { $0.id == requirementID })
    }

    private var badgeColor: Color {
        guard let req = requirement else { return Theme.textMuted }
        switch req.status {
        case .active: return Theme.requirementActive
        case .validated: return Theme.requirementValidated
        case .deferred: return Theme.requirementDeferred
        }
    }
}
