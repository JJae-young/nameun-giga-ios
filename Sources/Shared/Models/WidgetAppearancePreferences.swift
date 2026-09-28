import Foundation

enum DataViewAppearanceMode: String, CaseIterable, Codable, Equatable {
    case system
    case light
    case dark

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .system
    }
}

enum DataViewVisualTheme: String, CaseIterable, Codable, Equatable {
    case classicBlue
    case softPastel

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .classicBlue
    }
}

struct WidgetAppearancePreferences: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let defaultValue = WidgetAppearancePreferences()

    var schemaVersion: Int
    var appearanceMode: DataViewAppearanceMode
    var visualTheme: DataViewVisualTheme

    init(
        schemaVersion: Int = currentSchemaVersion,
        appearanceMode: DataViewAppearanceMode = .system,
        visualTheme: DataViewVisualTheme = .classicBlue
    ) {
        self.schemaVersion = schemaVersion
        self.appearanceMode = appearanceMode
        self.visualTheme = visualTheme
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appearanceMode
        case visualTheme
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = (try? container.decode(Int.self, forKey: .schemaVersion))
            ?? Self.currentSchemaVersion
        appearanceMode = (try? container.decode(DataViewAppearanceMode.self, forKey: .appearanceMode))
            ?? .system
        visualTheme = (try? container.decode(DataViewVisualTheme.self, forKey: .visualTheme))
            ?? .classicBlue
    }
}
