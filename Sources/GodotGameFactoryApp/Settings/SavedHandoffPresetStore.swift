import Foundation

struct SavedHandoffPresetStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let presetsKey = "GodotGameFactory.savedHandoffPresets"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [SavedHandoffPreset] {
        guard let data = defaults.data(forKey: presetsKey) else {
            return []
        }

        guard let decoded = try? decoder.decode([SavedHandoffPreset].self, from: data) else {
            return []
        }

        return decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    func save(_ presets: [SavedHandoffPreset]) -> Bool {
        let sortedPresets = presets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        guard let data = try? encoder.encode(sortedPresets) else {
            return false
        }

        defaults.set(data, forKey: presetsKey)
        return true
    }
}
