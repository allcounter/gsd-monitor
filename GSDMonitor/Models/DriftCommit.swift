import Foundation

struct DriftCommit: Identifiable, Codable, Sendable {
    let id: String        // Short commit hash (7 chars)
    let message: String
    let date: Date
    let filesChanged: Int

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // Manual initializer for creating instances (e.g., preview data)
    init(id: String, message: String, date: Date, filesChanged: Int) {
        self.id = id
        self.message = message
        self.date = date
        self.filesChanged = filesChanged
    }
}
