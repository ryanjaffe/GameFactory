import Foundation

struct SavedPromptPreset: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let promptKind: CodexPromptKind?
    let mode: PromptPackMode
    let includeProjectSummary: Bool
    let includeWorkflowFiles: Bool
    let includeStarterContext: Bool
    let includeNotesOrContext: Bool
    let includeRecentActivityContext: Bool?
    let recentActivityContextLimit: Int?

    init(
        id: String = UUID().uuidString,
        name: String,
        promptKind: CodexPromptKind? = nil,
        mode: PromptPackMode,
        includeProjectSummary: Bool,
        includeWorkflowFiles: Bool,
        includeStarterContext: Bool,
        includeNotesOrContext: Bool,
        includeRecentActivityContext: Bool? = nil,
        recentActivityContextLimit: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.promptKind = promptKind
        self.mode = mode
        self.includeProjectSummary = includeProjectSummary
        self.includeWorkflowFiles = includeWorkflowFiles
        self.includeStarterContext = includeStarterContext
        self.includeNotesOrContext = includeNotesOrContext
        self.includeRecentActivityContext = includeRecentActivityContext
        self.recentActivityContextLimit = recentActivityContextLimit
    }

    var configuration: PromptPackPresetConfiguration {
        PromptPackPresetConfiguration(
            mode: mode,
            includeProjectSummary: includeProjectSummary,
            includeWorkflowFiles: includeWorkflowFiles,
            includeStarterContext: includeStarterContext,
            includeNotesOrContext: includeNotesOrContext
        )
    }
}
