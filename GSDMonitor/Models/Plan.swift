import Foundation

struct Plan: Identifiable, Codable, Sendable {
    let id: UUID
    let phaseNumber: Int
    let planNumber: Int
    let objective: String
    let tasks: [Task]
    let status: PlanStatus

    enum CodingKeys: String, CodingKey {
        case id
        case phaseNumber = "phase_number"
        case planNumber = "plan_number"
        case objective
        case tasks
        case status
    }

    // Manual initializer
    init(id: UUID = UUID(), phaseNumber: Int, planNumber: Int, objective: String, tasks: [Task] = [], status: PlanStatus = .pending) {
        self.id = id
        self.phaseNumber = phaseNumber
        self.planNumber = planNumber
        self.objective = objective
        self.tasks = tasks
        self.status = status
    }
}

struct Task: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let type: TaskType
    let status: TaskStatus

    // Manual initializer
    init(id: UUID = UUID(), name: String, type: TaskType, status: TaskStatus = .pending) {
        self.id = id
        self.name = name
        self.type = type
        self.status = status
    }
}

enum TaskType: String, Codable, Sendable {
    case auto
    case checkpoint
}

enum TaskStatus: String, Codable, Sendable {
    case pending
    case inProgress = "in-progress"
    case done
}

enum PlanStatus: String, Codable, Sendable {
    case pending
    case inProgress = "in-progress"
    case done
}
