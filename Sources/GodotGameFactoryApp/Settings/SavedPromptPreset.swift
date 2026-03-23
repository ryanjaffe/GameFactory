import Foundation

struct SavedPromptPreset: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let mode: PromptPackMode
    let includeProjectSummary: Bool
    let includeWorkflowFiles: Bool
    let includeStarterContext: Bool
    let includeNotesOrContext: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        mode: PromptPackMode,
        includeProjectSummary: Bool,
        includeWorkflowFiles: Bool,
        includeStarterContext: Bool,
        includeNotesOrContext: Bool
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.includeProjectSummary = includeProjectSummary
        self.includeWorkflowFiles = includeWorkflowFiles
        self.includeStarterContext = includeStarterContext
        self.includeNotesOrContext = includeNotesOrContext
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
