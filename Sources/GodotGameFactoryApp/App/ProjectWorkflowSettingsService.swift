import Foundation

struct ProjectWorkflowSettingsService {
    private let fileManager: FileManager
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func configURL(for projectURL: URL) -> URL {
        projectURL.appendingPathComponent("gamefactory.workflow.json")
    }

    func loadSettings(for projectURL: URL, template: ProjectTemplate?) -> ProjectWorkflowSettingsDocument {
        let fileURL = configURL(for: projectURL)
        let defaultSettings = ProjectWorkflowSettings.defaults(for: template)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return ProjectWorkflowSettingsDocument(
                projectURL: projectURL,
                fileURL: fileURL,
                settings: defaultSettings,
                usedDefaults: true,
                statusMessage: "Using defaults. Save to create \(fileURL.lastPathComponent)."
            )
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let persisted = try decoder.decode(PersistedWorkflowSettings.self, from: data)

            return ProjectWorkflowSettingsDocument(
                projectURL: projectURL,
                fileURL: fileURL,
                settings: persisted.resolved(with: defaultSettings),
                usedDefaults: false,
                statusMessage: "Loaded \(fileURL.lastPathComponent)."
            )
        } catch {
            return ProjectWorkflowSettingsDocument(
                projectURL: projectURL,
                fileURL: fileURL,
                settings: defaultSettings,
                usedDefaults: true,
                statusMessage: "Workflow settings are invalid. Using defaults until you save."
            )
        }
    }

    func saveSettings(_ settings: ProjectWorkflowSettings, for projectURL: URL) throws -> URL {
        let fileURL = configURL(for: projectURL)
        let data = try encoder.encode(
            PersistedWorkflowSettings(
                validationTarget: settings.trimmedValidationTarget,
                godotPathOverride: settings.trimmedGodotPathOverride,
                handoffNote: settings.trimmedHandoffNote,
                projectNote: settings.trimmedProjectNote
            )
        )

        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }
}

private struct PersistedWorkflowSettings: Codable {
    let validationTarget: String?
    let godotPathOverride: String?
    let handoffNote: String?
    let projectNote: String?

    func resolved(with defaults: ProjectWorkflowSettings) -> ProjectWorkflowSettings {
        ProjectWorkflowSettings(
            validationTarget: normalized(validationTarget) ?? defaults.validationTarget,
            godotPathOverride: normalized(godotPathOverride) ?? defaults.godotPathOverride,
            handoffNote: normalized(handoffNote) ?? defaults.handoffNote,
            projectNote: normalized(projectNote) ?? defaults.projectNote
        )
    }

    private func normalized(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
