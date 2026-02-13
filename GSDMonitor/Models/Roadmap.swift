import Foundation

struct Milestone: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String           // "v1.0 MVP", "v1.1 Visual Overhaul"
    let phaseNumbers: [Int]    // Phase numbers belonging to this milestone
    var isComplete: Bool       // True if all phases in group are .done

    init(name: String, phaseNumbers: [Int], isComplete: Bool) {
        self.id = UUID()
        self.name = name
        self.phaseNumbers = phaseNumbers
        self.isComplete = isComplete
    }
}

struct Roadmap: Codable, Sendable {
    let projectName: String?
    let phases: [Phase]
    var milestones: [Milestone]

    enum CodingKeys: String, CodingKey {
        case projectName = "project_name"
        case phases
        case milestones
    }

    init(projectName: String?, phases: [Phase], milestones: [Milestone] = []) {
        self.projectName = projectName
        self.phases = phases
        self.milestones = milestones
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
        phases = try container.decode([Phase].self, forKey: .phases)
        milestones = try container.decodeIfPresent([Milestone].self, forKey: .milestones) ?? []
    }
}
