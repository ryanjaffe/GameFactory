import Foundation

struct ProjectPresetStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let presetsKey = "GodotGameFactory.projectPresets"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [ProjectPreset] {
        guard let data = defaults.data(forKey: presetsKey) else {
            return []
        }

        guard let decoded = try? decoder.decode([ProjectPreset].self, from: data) else {
            return []
        }

        return decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    func save(_ presets: [ProjectPreset]) -> Bool {
        let sortedPresets = presets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        guard let data = try? encoder.encode(sortedPresets) else {
            return false
        }

        defaults.set(data, forKey: presetsKey)
        return true
    }

    func savePreset(named desiredName: String, from settings: AppSettings) -> PresetSaveResult {
        let trimmedName = desiredName.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingPresets = load()
        let existingNames = Set(existingPresets.map(\.name))
        let resolvedName = uniqueName(for: trimmedName, existingNames: existingNames)
        let preset = ProjectPreset.from(name: resolvedName, settings: settings)
        let updatedPresets = existingPresets + [preset]
        _ = save(updatedPresets)

        return PresetSaveResult(
            preset: preset,
            wasRenamed: resolvedName != trimmedName,
            presets: updatedPresets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        )
    }

    func deletePreset(named name: String) -> [ProjectPreset] {
        let updatedPresets = load().filter { $0.name != name }
        _ = save(updatedPresets)
        return updatedPresets
    }

    private func uniqueName(for desiredName: String, existingNames: Set<String>) -> String {
        guard existingNames.contains(desiredName) else {
            return desiredName
        }

        var suffix = 2
        while existingNames.contains("\(desiredName) \(suffix)") {
            suffix += 1
        }

        return "\(desiredName) \(suffix)"
    }
}

struct PresetSaveResult {
    let preset: ProjectPreset
    let wasRenamed: Bool
    let presets: [ProjectPreset]
}
