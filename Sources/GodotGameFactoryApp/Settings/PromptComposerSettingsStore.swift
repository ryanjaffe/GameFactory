import Foundation

struct PromptComposerSettings: Codable {
    let selectedPromptKind: CodexPromptKind
    let selectedPromptMode: PromptPackMode
    let includeProjectSummary: Bool
    let includeWorkflowFiles: Bool
    let includeStarterContext: Bool
    let includeNotesOrContext: Bool
    let includeRecentActivityContext: Bool
    let recentActivityContextLimit: Int
    let includeProjectSessionNotes: Bool
    let includeValidationResultInPrompt: Bool

    private enum CodingKeys: String, CodingKey {
        case selectedPromptKind
        case selectedPromptMode
        case includeProjectSummary
        case includeWorkflowFiles
        case includeStarterContext
        case includeNotesOrContext
        case includeRecentActivityContext
        case recentActivityContextLimit
        case includeProjectSessionNotes
        case includeValidationResultInPrompt
    }

    static let `default` = PromptComposerSettings(
        selectedPromptKind: .starter,
        selectedPromptMode: .standard,
        includeProjectSummary: true,
        includeWorkflowFiles: true,
        includeStarterContext: true,
        includeNotesOrContext: true,
        includeRecentActivityContext: false,
        recentActivityContextLimit: 5,
        includeProjectSessionNotes: false,
        includeValidationResultInPrompt: false
    )

    init(
        selectedPromptKind: CodexPromptKind,
        selectedPromptMode: PromptPackMode,
        includeProjectSummary: Bool,
        includeWorkflowFiles: Bool,
        includeStarterContext: Bool,
        includeNotesOrContext: Bool,
        includeRecentActivityContext: Bool,
        recentActivityContextLimit: Int,
        includeProjectSessionNotes: Bool,
        includeValidationResultInPrompt: Bool
    ) {
        self.selectedPromptKind = selectedPromptKind
        self.selectedPromptMode = selectedPromptMode
        self.includeProjectSummary = includeProjectSummary
        self.includeWorkflowFiles = includeWorkflowFiles
        self.includeStarterContext = includeStarterContext
        self.includeNotesOrContext = includeNotesOrContext
        self.includeRecentActivityContext = includeRecentActivityContext
        self.recentActivityContextLimit = recentActivityContextLimit
        self.includeProjectSessionNotes = includeProjectSessionNotes
        self.includeValidationResultInPrompt = includeValidationResultInPrompt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedPromptKind = try container.decodeIfPresent(CodexPromptKind.self, forKey: .selectedPromptKind) ?? Self.default.selectedPromptKind
        selectedPromptMode = try container.decodeIfPresent(PromptPackMode.self, forKey: .selectedPromptMode) ?? Self.default.selectedPromptMode
        includeProjectSummary = try container.decodeIfPresent(Bool.self, forKey: .includeProjectSummary) ?? Self.default.includeProjectSummary
        includeWorkflowFiles = try container.decodeIfPresent(Bool.self, forKey: .includeWorkflowFiles) ?? Self.default.includeWorkflowFiles
        includeStarterContext = try container.decodeIfPresent(Bool.self, forKey: .includeStarterContext) ?? Self.default.includeStarterContext
        includeNotesOrContext = try container.decodeIfPresent(Bool.self, forKey: .includeNotesOrContext) ?? Self.default.includeNotesOrContext
        includeRecentActivityContext = try container.decodeIfPresent(Bool.self, forKey: .includeRecentActivityContext) ?? Self.default.includeRecentActivityContext
        recentActivityContextLimit = try container.decodeIfPresent(Int.self, forKey: .recentActivityContextLimit) ?? Self.default.recentActivityContextLimit
        includeProjectSessionNotes = try container.decodeIfPresent(Bool.self, forKey: .includeProjectSessionNotes) ?? Self.default.includeProjectSessionNotes
        includeValidationResultInPrompt = try container.decodeIfPresent(Bool.self, forKey: .includeValidationResultInPrompt) ?? Self.default.includeValidationResultInPrompt
    }
}

struct PromptComposerSettingsStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let settingsKey = "GodotGameFactory.promptComposerSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PromptComposerSettings {
        guard let data = defaults.data(forKey: settingsKey) else {
            return .default
        }

        guard let decoded = try? decoder.decode(PromptComposerSettings.self, from: data) else {
            return .default
        }

        return sanitized(decoded)
    }

    @discardableResult
    func save(_ settings: PromptComposerSettings) -> Bool {
        let sanitizedSettings = sanitized(settings)

        guard let data = try? encoder.encode(sanitizedSettings) else {
            return false
        }

        defaults.set(data, forKey: settingsKey)
        return true
    }

    private func sanitized(_ settings: PromptComposerSettings) -> PromptComposerSettings {
        PromptComposerSettings(
            selectedPromptKind: settings.selectedPromptKind,
            selectedPromptMode: settings.selectedPromptMode,
            includeProjectSummary: settings.includeProjectSummary,
            includeWorkflowFiles: settings.includeWorkflowFiles,
            includeStarterContext: settings.includeStarterContext,
            includeNotesOrContext: settings.includeNotesOrContext,
            includeRecentActivityContext: settings.includeRecentActivityContext,
            recentActivityContextLimit: max(1, min(settings.recentActivityContextLimit, 10)),
            includeProjectSessionNotes: settings.includeProjectSessionNotes,
            includeValidationResultInPrompt: settings.includeValidationResultInPrompt
        )
    }
}
