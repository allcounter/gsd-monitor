import Foundation

struct Requirement: Identifiable, Codable, Sendable {
    let id: String  // REQ-ID like "NAV-01"
    let category: String
    let description: String
    let mappedToPhases: [Int]
    let status: RequirementStatus

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case description
        case mappedToPhases = "mapped_to_phases"
        case status
    }
}

enum RequirementStatus: String, Codable, Sendable {
    case active
    case validated
    case deferred
}
