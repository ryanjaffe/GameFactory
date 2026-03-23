import Foundation

struct HandoffBundleSettings: Codable {
    let selectedMode: HandoffBundleMode
    let includeProjectSessionNotes: Bool
    let includeRecentActivity: Bool
    let includeValidationResult: Bool
    let recentActivityLimit: Int

    private enum CodingKeys: String, CodingKey {
        case selectedMode
        case includeProjectSessionNotes
        case includeRecentActivity
        case includeValidationResult
        case recentActivityLimit
    }

    static let `default` = HandoffBundleSettings(
        selectedMode: .default,
        includeProjectSessionNotes: false,
        includeRecentActivity: false,
        includeValidationResult: false,
        recentActivityLimit: 5
    )

    init(
        selectedMode: HandoffBundleMode,
        includeProjectSessionNotes: Bool,
        includeRecentActivity: Bool,
        includeValidationResult: Bool,
        recentActivityLimit: Int
    ) {
        self.selectedMode = selectedMode
        self.includeProjectSessionNotes = includeProjectSessionNotes
        self.includeRecentActivity = includeRecentActivity
        self.includeValidationResult = includeValidationResult
        self.recentActivityLimit = recentActivityLimit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedMode = try container.decode(HandoffBundleMode.self, forKey: .selectedMode)
        includeProjectSessionNotes = try container.decode(Bool.self, forKey: .includeProjectSessionNotes)
        includeRecentActivity = try container.decode(Bool.self, forKey: .includeRecentActivity)
        includeValidationResult = try container.decodeIfPresent(Bool.self, forKey: .includeValidationResult) ?? Self.default.includeValidationResult
        recentActivityLimit = try container.decode(Int.self, forKey: .recentActivityLimit)
    }
}

struct HandoffBundleSettingsStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let settingsKey = "GodotGameFactory.handoffBundleSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HandoffBundleSettings {
        guard let data = defaults.data(forKey: settingsKey) else {
            return .default
        }

        guard let decoded = try? decoder.decode(HandoffBundleSettings.self, from: data) else {
            return .default
        }

        return sanitized(decoded)
    }

    @discardableResult
    func save(_ settings: HandoffBundleSettings) -> Bool {
        let sanitizedSettings = sanitized(settings)

        guard let data = try? encoder.encode(sanitizedSettings) else {
            return false
        }

        defaults.set(data, forKey: settingsKey)
        return true
    }

    private func sanitized(_ settings: HandoffBundleSettings) -> HandoffBundleSettings {
        HandoffBundleSettings(
            selectedMode: settings.selectedMode,
            includeProjectSessionNotes: settings.includeProjectSessionNotes,
            includeRecentActivity: settings.includeRecentActivity,
            includeValidationResult: settings.includeValidationResult,
            recentActivityLimit: max(1, min(settings.recentActivityLimit, 10))
        )
    }
}
