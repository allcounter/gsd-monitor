import Foundation

struct Editor: Identifiable, Codable, Sendable {
    let id: String // bundle identifier or path for custom editors
    let name: String
    let path: URL
    var isCustom: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, path, isCustom
    }

    init(id: String, name: String, path: URL, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.isCustom = isCustom
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let pathString = try container.decode(String.self, forKey: .path)
        path = URL(fileURLWithPath: pathString)
        isCustom = (try? container.decode(Bool.self, forKey: .isCustom)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path.path, forKey: .path)
        try container.encode(isCustom, forKey: .isCustom)
    }
}
