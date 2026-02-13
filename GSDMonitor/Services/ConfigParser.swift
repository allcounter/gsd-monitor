import Foundation

struct ConfigParser: Sendable {
    func parse(_ data: Data) throws -> PlanningConfig {
        let decoder = JSONDecoder()
        return try decoder.decode(PlanningConfig.self, from: data)
    }
}
