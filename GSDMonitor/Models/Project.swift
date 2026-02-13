import Foundation
import CryptoKit

struct Project: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let path: URL
    var roadmap: Roadmap?
    var state: State?
    var config: PlanningConfig?
    var requirements: [Requirement]?
    var plans: [Plan]?
    var driftCommits: [DriftCommit]?

    enum CodingKeys: String, CodingKey {
        case id, name, path, roadmap, state, config, requirements, plans, driftCommits
    }

    // Custom init for URL decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        let pathString = try container.decode(String.self, forKey: .path)
        path = URL(fileURLWithPath: pathString)

        roadmap = try container.decodeIfPresent(Roadmap.self, forKey: .roadmap)
        state = try container.decodeIfPresent(State.self, forKey: .state)
        config = try container.decodeIfPresent(PlanningConfig.self, forKey: .config)
        requirements = try container.decodeIfPresent([Requirement].self, forKey: .requirements)
        plans = try container.decodeIfPresent([Plan].self, forKey: .plans)
        driftCommits = try container.decodeIfPresent([DriftCommit].self, forKey: .driftCommits)
    }

    // Custom encode for URL encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path.path, forKey: .path)
        try container.encodeIfPresent(roadmap, forKey: .roadmap)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(config, forKey: .config)
        try container.encodeIfPresent(requirements, forKey: .requirements)
        try container.encodeIfPresent(plans, forKey: .plans)
        try container.encodeIfPresent(driftCommits, forKey: .driftCommits)
    }

    // Deterministic UUID generation from path
    static func deterministicID(from path: URL) -> UUID {
        let hash = SHA256.hash(data: Data(path.path.utf8))
        let bytes = Array(hash)
        // Build a UUID from the first 16 bytes of the SHA-256 hash
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return uuid
    }

    // Manual initializer for creating instances
    init(id: UUID? = nil, name: String, path: URL, roadmap: Roadmap? = nil, state: State? = nil, config: PlanningConfig? = nil, requirements: [Requirement]? = nil, plans: [Plan]? = nil, driftCommits: [DriftCommit]? = nil) {
        self.id = id ?? Project.deterministicID(from: path)
        self.name = name
        self.path = path
        self.roadmap = roadmap
        self.state = state
        self.config = config
        self.requirements = requirements
        self.plans = plans
        self.driftCommits = driftCommits
    }
}

struct PlanningConfig: Codable, Sendable {
    let workflowVersion: String?
    let autoCommit: Bool?
    let mode: String?
    let depth: String?
    let parallelization: Bool?

    enum CodingKeys: String, CodingKey {
        case workflowVersion = "workflow_version"
        case autoCommit = "auto_commit"
        case mode
        case depth
        case parallelization
    }

    // Manual initializer for testing
    init(workflowVersion: String? = nil, autoCommit: Bool? = nil, mode: String? = nil, depth: String? = nil, parallelization: Bool? = nil) {
        self.workflowVersion = workflowVersion
        self.autoCommit = autoCommit
        self.mode = mode
        self.depth = depth
        self.parallelization = parallelization
    }
}
