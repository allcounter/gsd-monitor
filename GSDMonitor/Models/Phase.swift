import Foundation

struct Phase: Identifiable, Codable, Sendable {
    let id: UUID
    let number: Int
    let name: String
    let goal: String
    let dependencies: [String]
    let requirements: [String]
    let milestones: [String]
    let status: PhaseStatus

    // Computed property for UI
    var isComplete: Bool {
        status == .done
    }

    /// Phase is resolved (done, cancelled, or deferred) — no longer blocking progress
    var isResolved: Bool {
        status == .done || status == .cancelled || status == .deferred
    }

    // Manual initializer
    init(id: UUID = UUID(), number: Int, name: String, goal: String, dependencies: [String] = [], requirements: [String] = [], milestones: [String] = [], status: PhaseStatus = .notStarted) {
        self.id = id
        self.number = number
        self.name = name
        self.goal = goal
        self.dependencies = dependencies
        self.requirements = requirements
        self.milestones = milestones
        self.status = status
    }
}

enum PhaseStatus: String, Codable, Sendable {
    case notStarted = "not-started"
    case inProgress = "in-progress"
    case done = "done"
    case cancelled = "cancelled"
    case deferred = "deferred"
}
