import Foundation

struct State: Codable, Sendable {
    let currentPhase: Int?
    let currentPlan: Int?
    let status: String
    let lastActivity: String?
    let decisions: [String]
    let blockers: [String]
    let totalExecutionTime: String?
    let currentMilestone: String?

    enum CodingKeys: String, CodingKey {
        case currentPhase = "current_phase"
        case currentPlan = "current_plan"
        case status
        case lastActivity = "last_activity"
        case decisions
        case blockers
        case totalExecutionTime = "total_execution_time"
        case currentMilestone = "current_milestone"
    }
}
