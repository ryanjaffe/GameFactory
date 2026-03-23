import Foundation

struct HandoffBundleSettings: Codable {
    let selectedMode: HandoffBundleMode
    let includeProjectSessionNotes: Bool
    let includeRecentActivity: Bool
    let recentActivityLimit: Int

    static let `default` = HandoffBundleSettings(
        selectedMode: .default,
        includeProjectSessionNotes: false,
        includeRecentActivity: false,
        recentActivityLimit: 5
    )
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
            recentActivityLimit: max(1, min(settings.recentActivityLimit, 10))
        )
    }
}
