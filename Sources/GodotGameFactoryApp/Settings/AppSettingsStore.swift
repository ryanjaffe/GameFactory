import Foundation

struct AppSettingsStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let settingsKey = "GodotGameFactory.appSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: settingsKey) else {
            return .default
        }

        guard let decoded = try? decoder.decode(AppSettings.self, from: data) else {
            return .default
        }

        return sanitized(decoded)
    }

    @discardableResult
    func save(_ settings: AppSettings) -> Bool {
        let sanitizedSettings = sanitized(settings)

        guard let data = try? encoder.encode(sanitizedSettings) else {
            return false
        }

        defaults.set(data, forKey: settingsKey)
        return true
    }

    private func sanitized(_ settings: AppSettings) -> AppSettings {
        AppSettings(
            projectName: settings.projectName,
            baseDirectory: settings.baseDirectory.isEmpty ? AppSettings.default.baseDirectory : settings.baseDirectory,
            gitHubUsername: settings.gitHubUsername,
            repoVisibility: settings.repoVisibility,
            template: settings.template
        )
    }
}
