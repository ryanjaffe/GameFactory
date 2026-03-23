import SwiftUI

enum PromptPackMode: String, CaseIterable, Identifiable, Codable {
    case standard
    case planning
    case implementation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "Standard"
        case .planning:
            return "Planning"
        case .implementation:
            return "Implementation"
        }
    }

    var promptHeader: String? {
        switch self {
        case .standard:
            return nil
        case .planning:
            return "Focus on planning and architecture."
        case .implementation:
            return "Focus on concrete implementation steps."
        }
    }
}

struct PromptPackPresetConfiguration {
    let mode: PromptPackMode
    let includeProjectSummary: Bool
    let includeWorkflowFiles: Bool
    let includeStarterContext: Bool
    let includeNotesOrContext: Bool
}

enum PromptPackPreset: String, CaseIterable, Identifiable {
    case `default`
    case planningReview
    case implementationFocus
    case minimalContext

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default:
            return "Default"
        case .planningReview:
            return "Planning Review"
        case .implementationFocus:
            return "Implementation Focus"
        case .minimalContext:
            return "Minimal Context"
        }
    }

    var configuration: PromptPackPresetConfiguration {
        switch self {
        case .default:
            return PromptPackPresetConfiguration(
                mode: .standard,
                includeProjectSummary: true,
                includeWorkflowFiles: true,
                includeStarterContext: true,
                includeNotesOrContext: true
            )
        case .planningReview:
            return PromptPackPresetConfiguration(
                mode: .planning,
                includeProjectSummary: true,
                includeWorkflowFiles: true,
                includeStarterContext: true,
                includeNotesOrContext: true
            )
        case .implementationFocus:
            return PromptPackPresetConfiguration(
                mode: .implementation,
                includeProjectSummary: true,
                includeWorkflowFiles: true,
                includeStarterContext: true,
                includeNotesOrContext: false
            )
        case .minimalContext:
            return PromptPackPresetConfiguration(
                mode: .standard,
                includeProjectSummary: true,
                includeWorkflowFiles: false,
                includeStarterContext: false,
                includeNotesOrContext: false
            )
        }
    }
}

struct UIStatusMessage {
    enum Kind {
        case success
        case error
    }

    let kind: Kind
    let text: String

    static func success(_ text: String) -> UIStatusMessage {
        UIStatusMessage(kind: .success, text: text)
    }

    static func error(_ text: String) -> UIStatusMessage {
        UIStatusMessage(kind: .error, text: text)
    }
}

struct HandoffBundlePreviewItem: Identifiable {
    let title: String
    let detail: String

    var id: String { title }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            guard hasFinishedInitializing else {
                return
            }

            if settingsStore.save(settings) {
                hasSavedSettings = true
            } else if !hasLoggedSaveFailure {
                log("Settings save failed. The app will continue using in-memory values.")
                hasLoggedSaveFailure = true
            }
        }
    }
    @Published private(set) var logEntries: [LogEntry]
    @Published var logSearchText = ""
    @Published var dryRunEnabled = false
    @Published var presetNameDraft = ""
    @Published var selectedPresetName = ""
    @Published var selectedPromptKind: CodexPromptKind = .starter {
        didSet { clearPromptPreview() }
    }
    @Published var promptPackPreviewText = ""
    @Published var promptPresetNameDraft = ""
    @Published var promptCustomContextText = "" {
        didSet { clearPromptPreview() }
    }
    @Published var includeRecentActivityContext = false {
        didSet { clearPromptPreview() }
    }
    @Published var recentActivityContextLimit = 5 {
        didSet {
            let clampedValue = max(1, min(recentActivityContextLimit, 10))
            if recentActivityContextLimit != clampedValue {
                recentActivityContextLimit = clampedValue
                return
            }
            clearPromptPreview()
        }
    }
    @Published var selectedPromptPreset: PromptPackPreset = .default
    @Published var selectedSavedPromptPresetID = ""
    @Published var selectedPromptMode: PromptPackMode = .standard {
        didSet { clearPromptPreview() }
    }
    @Published var includeProjectSummary = true {
        didSet { clearPromptPreview() }
    }
    @Published var includeWorkflowFiles = true {
        didSet { clearPromptPreview() }
    }
    @Published var includeStarterContext = true {
        didSet { clearPromptPreview() }
    }
    @Published var includeNotesOrContext = true {
        didSet { clearPromptPreview() }
    }
    @Published private(set) var lastCreatedProjectURL: URL?
    @Published private(set) var lastCreatedTemplate: ProjectTemplate?
    @Published private(set) var lastCreatedSummary: ProjectCreationSummary?
    @Published private(set) var recentProjects: [RecentProject]
    @Published private(set) var codexHandoffMessage: String?
    @Published private(set) var presets: [ProjectPreset]
    @Published private(set) var savedPromptPresets: [SavedPromptPreset]
    @Published private(set) var inspectedProjectSummary: InspectedProjectSummary?
    @Published private(set) var lastProjectAudit: ProjectAuditSummary?
    @Published private(set) var lastAssetImport: AssetImportSummary?
    @Published private(set) var assetStarterPacks: [AssetStarterPack]
    @Published private(set) var selectedWorkflowProjectURL: URL?
    @Published private(set) var selectedWorkflowProjectName: String?
    @Published private(set) var selectedWorkflowProjectTemplate: ProjectTemplate?
    @Published private(set) var selectedWorkflowFile: WorkflowFileKind?
    @Published private(set) var workflowEditorText = ""
    @Published private(set) var workflowEditorFilePath = ""
    @Published private(set) var workflowFileNotFound = false
    @Published private(set) var workflowFileHasUnsavedChanges = false
    @Published private(set) var pendingWorkflowFileRepairConfirmation: WorkflowFileKind?
    @Published var workflowSettingsValidationTarget = "" {
        didSet { updateWorkflowSettingsDirtyStateIfNeeded() }
    }
    @Published var workflowSettingsGodotPathOverride = "" {
        didSet { updateWorkflowSettingsDirtyStateIfNeeded() }
    }
    @Published var workflowSettingsHandoffNote = "" {
        didSet { updateWorkflowSettingsDirtyStateIfNeeded() }
    }
    @Published var workflowSettingsProjectNote = "" {
        didSet { updateWorkflowSettingsDirtyStateIfNeeded() }
    }
    @Published private(set) var workflowSettingsConfigPath = ""
    @Published private(set) var workflowSettingsStatusMessage = ""
    @Published private(set) var workflowSettingsHasUnsavedChanges = false
    @Published private(set) var workflowSettingsUsingDefaults = true
    @Published private(set) var createProjectStatus: UIStatusMessage?
    @Published private(set) var promptPackStatus: UIStatusMessage?
    @Published private(set) var handoffBundleStatus: UIStatusMessage?
    @Published private(set) var assetImportStatus: UIStatusMessage?
    @Published private(set) var workflowFileStatus: UIStatusMessage?
    @Published private(set) var activeProjectStatus: UIStatusMessage?

    private let logger: AppLogger
    private let settingsStore: AppSettingsStore
    private let presetStore: ProjectPresetStore
    private let savedPromptPresetStore: SavedPromptPresetStore
    private let recentProjectsStore: RecentProjectsStore
    private let generator: ProjectGenerator
    private let gitService: GitService
    private let gitHubService: GitHubService
    private let postCreateActionService: PostCreateActionService
    private let codexPromptPackService: CodexPromptPackService
    private let codexHandoffService: CodexHandoffService
    private let folderPickerService: FolderPickerService
    private let existingProjectPickerService: ExistingProjectPickerService
    private let godotPathPickerService: GodotPathPickerService
    private let godotLaunchService: GodotLaunchService
    private let projectInspectorService: ProjectInspectorService
    private let projectAuditService: ProjectAuditService
    private let assetImportPickerService: AssetImportPickerService
    private let assetImportService: AssetImportService
    private let assetPromptContextService: AssetPromptContextService
    private let assetStarterPackService: AssetStarterPackService
    private let handoffBundleService: HandoffBundleService
    private let workflowFileService: WorkflowFileService
    private let workflowFileRepairService: WorkflowFileRepairService
    private let workflowSettingsService: ProjectWorkflowSettingsService
    private let promptPresetTransferService: PromptPresetTransferService
    private var hasFinishedInitializing = false
    private var hasLoggedSaveFailure = false
    private var hasSavedSettings = false
    private var workflowEditorOriginalText = ""
    private var workflowSettingsOriginal = ProjectWorkflowSettings.defaults(for: nil)
    private var workflowSettingsLoadedProjectURL: URL?
    private var isUpdatingWorkflowSettingsDraft = false

    var hasLastCreatedProject: Bool {
        lastCreatedProjectURL != nil
    }

    var filteredLogEntries: [LogEntry] {
        let trimmedSearchText = logSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else {
            return logEntries
        }

        return logEntries.filter { entry in
            entry.message.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    var createProjectValidationIssues: [String] {
        let trimmedName = settings.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseDirectory = settings.baseDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        var issues: [String] = []

        if trimmedName.isEmpty {
            issues.append("Project name is required.")
        }

        if trimmedBaseDirectory.isEmpty {
            issues.append("Base directory is required.")
        } else {
            var isDirectory: ObjCBool = false
            if !FileManager.default.fileExists(atPath: trimmedBaseDirectory, isDirectory: &isDirectory) {
                issues.append("Base directory does not exist.")
            } else if !isDirectory.boolValue {
                issues.append("Base directory must be a folder.")
            }
        }

        return issues
    }

    var createProjectValidationSummary: String? {
        guard !createProjectValidationIssues.isEmpty else {
            return nil
        }

        return createProjectValidationIssues.joined(separator: "\n")
    }

    var canCreateProject: Bool {
        createProjectValidationIssues.isEmpty
    }

    var hasProjectSummary: Bool {
        lastCreatedSummary != nil
    }

    var hasPresets: Bool {
        !presets.isEmpty
    }

    var selectedPreset: ProjectPreset? {
        presets.first(where: { $0.name == selectedPresetName })
    }

    var hasRecentProjects: Bool {
        !recentProjects.isEmpty
    }

    var hasInspectedProject: Bool {
        inspectedProjectSummary != nil
    }

    var hasProjectAudit: Bool {
        lastProjectAudit != nil
    }

    var hasAssetImportSummary: Bool {
        lastAssetImport != nil
    }

    var hasAssetStarterPacks: Bool {
        !assetStarterPacks.isEmpty
    }

    func starterPackValidationIssues(for pack: AssetStarterPack) -> [String] {
        var issues: [String] = []

        guard let activeProjectURL else {
            issues.append("An active project is required.")
            return issues
        }

        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: activeProjectURL.path, isDirectory: &isDirectory) {
            issues.append("The active project folder no longer exists.")
        } else if !isDirectory.boolValue {
            issues.append("The active project path must be a folder.")
        }

        if pack.files.isEmpty {
            issues.append("This starter pack has no files to import.")
        }

        return issues
    }

    func canApplyStarterPack(_ pack: AssetStarterPack) -> Bool {
        starterPackValidationIssues(for: pack).isEmpty
    }

    var hasHandoffBundleTarget: Bool {
        activeProjectURL != nil
    }

    var workflowFileTargetProjectURL: URL? {
        activeProjectURL
    }

    var workflowFileTargetProjectName: String {
        activeProjectName
    }

    var workflowFileTargetProjectPath: String {
        activeProjectPath
    }

    var activeProjectURL: URL? {
        explicitWorkflowSelectionURL ?? inspectedProjectSummary?.projectURL ?? lastCreatedProjectURL
    }

    var activeProjectName: String {
        if explicitWorkflowSelectionURL != nil, let selectedWorkflowProjectName {
            return selectedWorkflowProjectName
        }

        if let inspectedProjectSummary {
            return inspectedProjectSummary.projectName
        }

        return lastCreatedSummary?.projectName ?? lastCreatedProjectURL?.lastPathComponent ?? "No project selected"
    }

    var activeProjectPath: String {
        activeProjectURL?.path ?? "No project selected yet."
    }

    var activeProjectContextLabel: String {
        switch activeProjectSource {
        case .recent:
            return "Active Project (Recent)"
        case .inspected:
            return "Active Project (Inspected)"
        case .lastCreated:
            return "Active Project (Last Created)"
        case .none:
            return "Active Project"
        }
    }

    var activeProjectTemplate: ProjectTemplate? {
        if explicitWorkflowSelectionURL != nil {
            return selectedWorkflowProjectTemplate
        }

        return inspectedProjectSummary?.detectedTemplate ?? lastCreatedTemplate
    }

    var hasActiveProject: Bool {
        activeProjectURL != nil
    }

    var activeProjectSourceDisplayText: String {
        switch activeProjectSource {
        case .recent:
            return "Selected recent project"
        case .inspected:
            return "Inspected project"
        case .lastCreated:
            return "Last created project"
        case .none:
            return "No active project"
        }
    }

    var activeProjectTemplateDisplayText: String {
        activeProjectTemplate?.rawValue ?? "Unknown template"
    }

    var activeProjectContextDetailText: String {
        "\(activeProjectSourceDisplayText) • \(activeProjectTemplateDisplayText)"
    }

    var activeHandoffBundleText: String? {
        buildHandoffBundleText()
    }

    var handoffBundlePreviewItems: [HandoffBundlePreviewItem] {
        guard let input = buildHandoffBundleInput() else {
            return []
        }

        let workflowFileDetail = input.workflowFiles.isEmpty
            ? "No workflow files detected."
            : input.workflowFiles.joined(separator: ", ")
        let auditDetail = input.auditSummaryText == nil
            ? "No recent audit is available."
            : "Included when copied."
        let assetsDetail = input.recentAssetImportText ?? "No recent imports recorded in the current app session."
        let workflowSettingsDetail = input.workflowSettingsSummaryText == nil
            ? "No workflow settings summary will be included."
            : "Included when project-local workflow settings differ from defaults."

        return [
            HandoffBundlePreviewItem(title: "Summary", detail: "\(input.projectName) • \(input.templateName)"),
            HandoffBundlePreviewItem(title: "Workflow Files", detail: workflowFileDetail),
            HandoffBundlePreviewItem(title: "File Tree", detail: "Included from the active project."),
            HandoffBundlePreviewItem(title: "Audit", detail: auditDetail),
            HandoffBundlePreviewItem(title: "Assets", detail: assetsDetail),
            HandoffBundlePreviewItem(title: "Workflow Settings", detail: workflowSettingsDetail),
            HandoffBundlePreviewItem(title: "Starter Prompt", detail: "Included from the active project's current prompt pack."),
            HandoffBundlePreviewItem(title: "Next Steps", detail: input.nextSteps.joined(separator: " • "))
        ]
    }

    var hasWorkflowFileTarget: Bool {
        workflowFileTargetProjectURL != nil
    }

    var hasWorkflowSettingsTarget: Bool {
        activeProjectURL != nil
    }

    var canSaveWorkflowSettings: Bool {
        hasWorkflowSettingsTarget && workflowSettingsHasUnsavedChanges
    }

    var canRevertWorkflowSettings: Bool {
        hasWorkflowSettingsTarget
    }

    var canEditWorkflowFile: Bool {
        hasWorkflowFileTarget && selectedWorkflowFile != nil && !workflowFileNotFound
    }

    var canSaveWorkflowFile: Bool {
        canEditWorkflowFile && workflowFileHasUnsavedChanges
    }

    var canRevertWorkflowFile: Bool {
        hasWorkflowFileTarget && selectedWorkflowFile != nil
    }

    var canRepairSelectedWorkflowFile: Bool {
        hasWorkflowFileTarget && selectedWorkflowFile != nil && !workflowFileHasUnsavedChanges
    }

    var workflowRepairActionTitle: String {
        guard let selectedWorkflowFile else {
            return "Restore Default"
        }

        if workflowFileNotFound {
            return "Regenerate Missing \(selectedWorkflowFile.fileName)"
        }

        return "Restore Default"
    }

    var pendingWorkflowRepairFileName: String? {
        pendingWorkflowFileRepairConfirmation?.fileName
    }

    var hasOpenedWorkflowFile: Bool {
        selectedWorkflowFile != nil
    }

    var lastCreatedProjectPath: String {
        lastCreatedProjectURL?.path ?? "No project created yet."
    }

    var lastCreatedCodexStarterPrompt: String? {
        guard let lastCreatedProjectURL, let lastCreatedTemplate else {
            return nil
        }

        return codexPromptPackService.starterPrompt(
            for: lastCreatedProjectURL,
            template: lastCreatedTemplate,
            workflowSettings: workflowSettingsForProject(lastCreatedProjectURL, template: lastCreatedTemplate)
        ).body
    }

    var activeCodexStarterPrompt: String? {
        guard let activeProjectURL, let activeProjectTemplate else {
            return nil
        }

        return codexPromptPackService.starterPrompt(
            for: activeProjectURL,
            template: activeProjectTemplate,
            workflowSettings: workflowSettingsForProject(activeProjectURL, template: activeProjectTemplate)
        ).body
    }

    var lastCreatedSummaryText: String? {
        lastCreatedSummary?.summaryText
    }

    var lastCreatedFileTreeText: String? {
        lastCreatedSummary?.fileTreeText
    }

    var availablePromptPack: [CodexPrompt] {
        guard let activeProjectURL, let activeProjectTemplate else {
            return []
        }

        return codexPromptPackService.promptPack(
            for: activeProjectURL,
            template: activeProjectTemplate,
            workflowSettings: workflowSettingsForProject(activeProjectURL, template: activeProjectTemplate)
        )
    }

    var hasPromptPack: Bool {
        !availablePromptPack.isEmpty
    }

    var canSavePreset: Bool {
        !presetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSavePromptPreset: Bool {
        !promptPresetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedSavedPromptPreset: SavedPromptPreset? {
        savedPromptPresets.first(where: { $0.id == selectedSavedPromptPresetID })
    }

    var selectedPrompt: CodexPrompt? {
        availablePromptPack.first(where: { $0.kind == selectedPromptKind }) ?? availablePromptPack.first
    }

    var hasPromptPreview: Bool {
        !promptPackPreviewText.isEmpty
    }

    var previewCharacterCount: Int {
        promptPackPreviewText.count
    }

    var previewLineCount: Int {
        guard hasPromptPreview else {
            return 0
        }

        return promptPackPreviewText.components(separatedBy: .newlines).count
    }

    var previewWordCount: Int {
        guard hasPromptPreview else {
            return 0
        }

        return promptPackPreviewText
            .split { $0.isWhitespace || $0.isNewline }
            .count
    }

    var promptPreviewSizeWarning: String? {
        guard hasPromptPreview else {
            return nil
        }

        if previewCharacterCount >= 8000 {
            return "Very large prompt preview."
        }

        if previewCharacterCount >= 4000 {
            return "Large prompt preview."
        }

        return nil
    }

    init(
        settingsStore: AppSettingsStore = AppSettingsStore(),
        presetStore: ProjectPresetStore = ProjectPresetStore(),
        savedPromptPresetStore: SavedPromptPresetStore = SavedPromptPresetStore(),
        recentProjectsStore: RecentProjectsStore = RecentProjectsStore(),
        logger: AppLogger = AppLogger(),
        generator: ProjectGenerator = ProjectGenerator(),
        gitService: GitService = GitService(),
        gitHubService: GitHubService = GitHubService(),
        postCreateActionService: PostCreateActionService = PostCreateActionService(),
        codexPromptPackService: CodexPromptPackService = CodexPromptPackService(),
        codexHandoffService: CodexHandoffService = CodexHandoffService(),
        folderPickerService: FolderPickerService = FolderPickerService(),
        existingProjectPickerService: ExistingProjectPickerService = ExistingProjectPickerService(),
        godotPathPickerService: GodotPathPickerService = GodotPathPickerService(),
        godotLaunchService: GodotLaunchService = GodotLaunchService(),
        projectInspectorService: ProjectInspectorService = ProjectInspectorService(),
        projectAuditService: ProjectAuditService = ProjectAuditService(),
        assetImportPickerService: AssetImportPickerService = AssetImportPickerService(),
        assetImportService: AssetImportService = AssetImportService(),
        assetPromptContextService: AssetPromptContextService = AssetPromptContextService(),
        assetStarterPackService: AssetStarterPackService = AssetStarterPackService(),
        handoffBundleService: HandoffBundleService = HandoffBundleService(),
        workflowFileService: WorkflowFileService = WorkflowFileService(),
        workflowFileRepairService: WorkflowFileRepairService = WorkflowFileRepairService(),
        workflowSettingsService: ProjectWorkflowSettingsService = ProjectWorkflowSettingsService(),
        promptPresetTransferService: PromptPresetTransferService = PromptPresetTransferService()
    ) {
        self.settingsStore = settingsStore
        self.presetStore = presetStore
        self.savedPromptPresetStore = savedPromptPresetStore
        self.recentProjectsStore = recentProjectsStore
        self.logger = logger
        self.generator = generator
        self.gitService = gitService
        self.gitHubService = gitHubService
        self.postCreateActionService = postCreateActionService
        self.codexPromptPackService = codexPromptPackService
        self.codexHandoffService = codexHandoffService
        self.folderPickerService = folderPickerService
        self.existingProjectPickerService = existingProjectPickerService
        self.godotPathPickerService = godotPathPickerService
        self.godotLaunchService = godotLaunchService
        self.projectInspectorService = projectInspectorService
        self.projectAuditService = projectAuditService
        self.assetImportPickerService = assetImportPickerService
        self.assetImportService = assetImportService
        self.assetPromptContextService = assetPromptContextService
        self.assetStarterPackService = assetStarterPackService
        self.handoffBundleService = handoffBundleService
        self.workflowFileService = workflowFileService
        self.workflowFileRepairService = workflowFileRepairService
        self.workflowSettingsService = workflowSettingsService
        self.promptPresetTransferService = promptPresetTransferService
        self.settings = settingsStore.load()
        self.presets = presetStore.load()
        self.savedPromptPresets = savedPromptPresetStore.load()
        self.recentProjects = recentProjectsStore.load()
        self.assetStarterPacks = assetStarterPackService.availablePacks()
        self.logEntries = logger.entries
        self.selectedPresetName = presets.first?.name ?? ""
        self.selectedSavedPromptPresetID = savedPromptPresets.first?.id ?? ""

        log("App initialized")
        log(self.settings == AppSettings.default ? "Using default settings" : "Loaded saved settings")
        log("Generator service ready: \(generator.statusSummary)")
        log("Git service ready: \(gitService.statusSummary)")
        log("GitHub service ready: \(gitHubService.statusSummary)")
        log("New Project form ready")
        if !recentProjects.isEmpty {
            log("Loaded \(recentProjects.count) recent projects")
        }
        if !presets.isEmpty {
            log("Loaded \(presets.count) presets")
        }
        if !savedPromptPresets.isEmpty {
            log("Loaded \(savedPromptPresets.count) saved prompt presets")
        }
        hasFinishedInitializing = true
    }

    func createProject() {
        if dryRunEnabled {
            previewProject()
            return
        }

        guard canCreateProject else {
            logCreateProjectValidationIssues(prefix: "Create Project blocked")
            return
        }

        let trimmedName = settings.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseDirectory = settings.baseDirectory.trimmingCharacters(in: .whitespacesAndNewlines)

        log("Create Project pressed")
        if !hasSavedSettings && settingsStore.save(settings) {
            hasSavedSettings = true
        }
        log("Validated project name: \(trimmedName)")
        log("Validated base directory: \(trimmedBaseDirectory)")
        log("Selected template: \(settings.template.rawValue)")
        log("Generating local scaffold on disk")

        do {
            let result = try generator.generateProject(using: settings)
            lastCreatedProjectURL = result.finalProjectURL
            lastCreatedTemplate = settings.template
            selectedWorkflowProjectURL = result.finalProjectURL
            selectedWorkflowProjectName = trimmedName
            selectedWorkflowProjectTemplate = settings.template
            clearWorkflowEditor()
            clearProjectAudit()
            clearAssetImport()
            loadWorkflowSettings(for: result.finalProjectURL, template: settings.template)
            for message in result.messages {
                log(message)
            }
            log("Final project path: \(result.finalProjectURL.path)")

            let gitResult = gitService.initializeRepository(at: result.finalProjectURL)
            for message in gitResult.messages {
                log(message)
            }

            let gitStatus = integrationStatus(from: gitResult)

            guard gitResult.succeeded else {
                lastCreatedSummary = ProjectCreationSummary(
                    projectName: trimmedName,
                    finalProjectURL: result.finalProjectURL,
                    template: settings.template,
                    gitStatus: gitStatus,
                    gitHubStatus: .skipped("Local Git setup did not complete successfully"),
                    createdDirectories: result.createdDirectories,
                    createdFiles: result.createdFiles
                )
                if let lastCreatedSummary {
                    recordRecentProject(from: lastCreatedSummary)
                }
                log("GitHub setup skipped: local Git setup did not complete successfully.")
                createProjectStatus = .error("Project created, but local Git setup failed.")
                return
            }

            let gitHubResult = gitHubService.connectRepository(
                at: result.finalProjectURL,
                projectName: trimmedName,
                gitHubUsername: settings.gitHubUsername,
                visibility: settings.repoVisibility
            )
            for message in gitHubResult.messages {
                log(message)
            }

            lastCreatedSummary = ProjectCreationSummary(
                projectName: trimmedName,
                finalProjectURL: result.finalProjectURL,
                template: settings.template,
                gitStatus: gitStatus,
                gitHubStatus: integrationStatus(from: gitHubResult),
                createdDirectories: result.createdDirectories,
                createdFiles: result.createdFiles
            )
            if let lastCreatedSummary {
                recordRecentProject(from: lastCreatedSummary)
            }
            createProjectStatus = .success("Created \(trimmedName) at \(result.finalProjectURL.path).")
        } catch {
            log("Project generation failed: \(error.localizedDescription)")
            createProjectStatus = .error("Project creation failed. \(error.localizedDescription)")
        }
    }

    func previewProject() {
        guard canCreateProject else {
            logCreateProjectValidationIssues(prefix: "Preview blocked")
            return
        }

        let trimmedName = settings.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseDirectory = settings.baseDirectory.trimmingCharacters(in: .whitespacesAndNewlines)

        log("Dry run preview started")
        log("Previewing project name: \(trimmedName)")
        log("Previewing base directory: \(trimmedBaseDirectory)")
        log("Previewing template: \(settings.template.rawValue)")

        do {
            let plan = try generator.buildProjectPlan(using: settings)
            log("Preview final project path: \(plan.finalProjectURL.path)")

            if plan.usedSuffixedFolder {
                log("Preview collision handling: would use suffixed folder \(plan.finalProjectURL.lastPathComponent)")
            } else {
                log("Preview collision handling: requested folder is available")
            }

            log("Preview folders to create:")
            for directoryURL in plan.directoriesToCreate {
                log("  - \(directoryURL.lastPathComponent)/")
            }

            log("Preview files to create:")
            for file in plan.filesToCreate {
                log("  - \(file.url.lastPathComponent)")
            }

            let gitPreview = gitService.previewInitialization(at: plan.finalProjectURL)
            for message in gitPreview.messages {
                log(message)
            }

            let gitHubPreview = gitHubService.previewConnection(
                at: plan.finalProjectURL,
                projectName: trimmedName,
                gitHubUsername: settings.gitHubUsername,
                visibility: settings.repoVisibility,
                localGitWillBeReady: gitPreview.willAttempt
            )
            for message in gitHubPreview.messages {
                log(message)
            }

            log("Dry run preview complete. No files or folders were created.")
            createProjectStatus = .success("Preview ready for \(plan.finalProjectURL.path).")
        } catch {
            log("Preview failed: \(error.localizedDescription)")
            createProjectStatus = .error("Preview failed. \(error.localizedDescription)")
        }
    }

    func chooseBaseDirectory() {
        guard let selectedFolderURL = folderPickerService.chooseFolder() else {
            return
        }

        settings.baseDirectory = selectedFolderURL.path
    }

    func openExistingProject() {
        guard !workflowSettingsHasUnsavedChanges else {
            log("Project switch blocked: save or revert workflow settings first.")
            return
        }

        guard let selectedProjectURL = existingProjectPickerService.chooseProjectFolder() else {
            return
        }

        clearExplicitWorkflowSelection()
        let summary = projectInspectorService.inspectProject(at: selectedProjectURL)
        inspectedProjectSummary = summary
        clearProjectAudit()
        clearAssetImport()
        loadWorkflowSettings(for: selectedProjectURL, template: summary.detectedTemplate)

        if summary.isValidProject {
            log("Inspected existing project: \(summary.projectURL.path)")
        } else {
            log("Existing project inspection warning: \(summary.validationMessage)")
        }
    }

    func chooseGodotExecutablePath() {
        guard let selectedExecutableURL = godotPathPickerService.chooseGodotExecutable() else {
            return
        }

        settings.godotExecutablePath = selectedExecutableURL.path
    }

    func selectRecentProjectForWorkflowFiles(_ project: RecentProject) {
        guard !workflowFileHasUnsavedChanges else {
            log("Workflow file selection blocked: save or revert current changes first.")
            return
        }

        guard !workflowSettingsHasUnsavedChanges else {
            log("Project switch blocked: save or revert workflow settings first.")
            return
        }

        selectedWorkflowProjectURL = project.projectURL
        selectedWorkflowProjectName = project.projectName
        selectedWorkflowProjectTemplate = project.template
        clearWorkflowEditor()
        clearProjectAudit()
        clearAssetImport()
        loadWorkflowSettings(for: project.projectURL, template: project.template)
        log("Workflow file target set to \(project.projectName).")
    }

    func useInspectedProjectForWorkflowFiles() {
        guard let inspectedProjectSummary else {
            log("Workflow file target skipped: no inspected project is available.")
            return
        }

        guard !workflowFileHasUnsavedChanges else {
            log("Workflow file selection blocked: save or revert current changes first.")
            return
        }

        guard !workflowSettingsHasUnsavedChanges else {
            log("Project switch blocked: save or revert workflow settings first.")
            return
        }

        selectedWorkflowProjectURL = inspectedProjectSummary.projectURL
        selectedWorkflowProjectName = inspectedProjectSummary.projectName
        selectedWorkflowProjectTemplate = inspectedProjectSummary.detectedTemplate
        clearWorkflowEditor()
        clearProjectAudit()
        clearAssetImport()
        loadWorkflowSettings(for: inspectedProjectSummary.projectURL, template: inspectedProjectSummary.detectedTemplate)
        log("Workflow file target set to inspected project \(inspectedProjectSummary.projectName).")
    }

    func openWorkflowFile(_ kind: WorkflowFileKind) {
        guard let projectURL = workflowFileTargetProjectURL else {
            log("Workflow file action skipped: no project is selected.")
            return
        }

        guard !workflowFileHasUnsavedChanges || selectedWorkflowFile == kind else {
            log("Workflow file switch blocked: save or revert current changes first.")
            return
        }

        let loadResult = workflowFileService.loadFile(kind, projectURL: projectURL)
        selectedWorkflowFile = kind
        workflowEditorFilePath = loadResult.fileURL.path
        pendingWorkflowFileRepairConfirmation = nil

        if loadResult.isMissing {
            workflowEditorText = ""
            workflowEditorOriginalText = ""
            workflowFileNotFound = true
            workflowFileHasUnsavedChanges = false
            log("Workflow file not found: \(kind.fileName)")
            workflowFileStatus = .error("\(kind.fileName) is missing.")
            return
        }

        guard let contents = loadResult.contents else {
            workflowEditorText = ""
            workflowEditorOriginalText = ""
            workflowFileNotFound = false
            workflowFileHasUnsavedChanges = false
            log("Workflow file open failed: could not read \(kind.fileName).")
            workflowFileStatus = .error("Could not read \(kind.fileName).")
            return
        }

        workflowEditorText = contents
        workflowEditorOriginalText = contents
        workflowFileNotFound = false
        workflowFileHasUnsavedChanges = false
        log("Opened workflow file: \(kind.fileName)")
        workflowFileStatus = .success("Opened \(kind.fileName).")
    }

    func updateWorkflowEditorText(_ text: String) {
        workflowEditorText = text
        workflowFileHasUnsavedChanges = text != workflowEditorOriginalText
        if workflowFileHasUnsavedChanges {
            pendingWorkflowFileRepairConfirmation = nil
        }
    }

    func saveWorkflowFile() {
        guard let projectURL = workflowFileTargetProjectURL, let selectedWorkflowFile else {
            log("Workflow file save skipped: no file is open.")
            return
        }

        guard !workflowFileNotFound else {
            log("Workflow file save skipped: file not found.")
            return
        }

        do {
            let fileURL = try workflowFileService.saveFile(workflowEditorText, kind: selectedWorkflowFile, projectURL: projectURL)
            workflowEditorOriginalText = workflowEditorText
            workflowFileHasUnsavedChanges = false
            workflowEditorFilePath = fileURL.path
            log("Saved workflow file: \(selectedWorkflowFile.fileName)")
            workflowFileStatus = .success("Saved \(selectedWorkflowFile.fileName).")
        } catch {
            log("Workflow file save failed: \(error.localizedDescription)")
            workflowFileStatus = .error("Could not save \(selectedWorkflowFile.fileName). \(error.localizedDescription)")
        }
    }

    func runProjectAudit() {
        guard let activeProjectURL else {
            log("Project audit skipped: no project is selected.")
            return
        }

        let audit = projectAuditService.runAudit(projectURL: activeProjectURL, template: activeProjectTemplate)
        lastProjectAudit = audit
        log("Project audit complete for \(audit.projectName).")
    }

    func importAssets() {
        guard let activeProjectURL else {
            log("Asset import skipped: no project is selected.")
            return
        }

        let selectedFiles = assetImportPickerService.chooseFiles()
        guard !selectedFiles.isEmpty else {
            return
        }

        do {
            let importSummary = try assetImportService.importAssets(from: selectedFiles, into: activeProjectURL)
            lastAssetImport = importSummary
            for importedFile in importSummary.importedFiles {
                log("Imported asset: \(importedFile.destinationURL.lastPathComponent)")
            }
            assetImportStatus = .success("Imported \(importSummary.importedFiles.count) asset(s).")
        } catch {
            log("Asset import failed: \(error.localizedDescription)")
            assetImportStatus = .error("Asset import failed. \(error.localizedDescription)")
        }
    }

    func applyAssetStarterPack(_ pack: AssetStarterPack) {
        let validationIssues = starterPackValidationIssues(for: pack)
        guard validationIssues.isEmpty else {
            for issue in validationIssues {
                log("Asset starter pack blocked: \(issue)")
            }
            assetImportStatus = .error(validationIssues.joined(separator: " "))
            return
        }

        guard let activeProjectURL else {
            log("Asset starter pack skipped: no project is selected.")
            return
        }

        do {
            let importSummary = try assetImportService.importGeneratedAssets(
                pack.files,
                into: activeProjectURL,
                packTitle: pack.title
            )
            lastAssetImport = importSummary
            log("Applied asset starter pack: \(pack.title)")
            for importedFile in importSummary.importedFiles {
                log("Imported asset: \(importedFile.destinationURL.lastPathComponent)")
            }
            assetImportStatus = .success("Applied \(pack.title).")
        } catch {
            log("Asset starter pack failed: \(error.localizedDescription)")
            assetImportStatus = .error("Could not apply \(pack.title). \(error.localizedDescription)")
        }
    }

    func copyHandoffBundle() {
        guard let bundleText = buildHandoffBundleText() else {
            log("Handoff bundle skipped: no project is selected.")
            return
        }

        switch postCreateActionService.copyHandoffBundle(bundleText) {
        case let .success(message):
            log(message)
            handoffBundleStatus = .success("Copied handoff bundle.")
        case let .failure(error):
            log("Handoff bundle failed: \(error.localizedDescription)")
            handoffBundleStatus = .error("Could not copy handoff bundle. \(error.localizedDescription)")
        }
    }

    func revealActiveProjectInFinder() {
        guard let activeProjectURL else {
            log("Finder reveal skipped: no project is selected.")
            activeProjectStatus = .error("No active project is available to reveal.")
            return
        }

        switch postCreateActionService.openInFinder(projectURL: activeProjectURL) {
        case let .success(message):
            log(message)
            activeProjectStatus = .success("Revealed \(activeProjectName) in Finder.")
        case let .failure(error):
            log("Finder reveal failed: \(error.localizedDescription)")
            activeProjectStatus = .error("Could not reveal the active project. \(error.localizedDescription)")
        }
    }

    func copyActiveProjectPath() {
        guard let activeProjectURL else {
            log("Copy project path skipped: no project is selected.")
            activeProjectStatus = .error("No active project to copy.")
            return
        }

        switch postCreateActionService.copyProjectPath(projectURL: activeProjectURL) {
        case let .success(message):
            log(message)
            activeProjectStatus = .success("Copied project path.")
        case let .failure(error):
            log("Copy project path failed: \(error.localizedDescription)")
            activeProjectStatus = .error("Could not copy project path. \(error.localizedDescription)")
        }
    }

    func copyActiveProjectName() {
        guard hasActiveProject else {
            log("Copy project name skipped: no project is selected.")
            activeProjectStatus = .error("No active project to copy.")
            return
        }

        switch postCreateActionService.copyProjectName(activeProjectName) {
        case let .success(message):
            log(message)
            activeProjectStatus = .success("Copied project name.")
        case let .failure(error):
            log("Copy project name failed: \(error.localizedDescription)")
            activeProjectStatus = .error("Could not copy project name. \(error.localizedDescription)")
        }
    }

    func revertWorkflowFile() {
        guard let selectedWorkflowFile else {
            log("Workflow file revert skipped: no file is open.")
            return
        }

        openWorkflowFile(selectedWorkflowFile)
    }

    func repairSelectedWorkflowFile() {
        guard let projectURL = workflowFileTargetProjectURL, let selectedWorkflowFile else {
            log("Workflow file repair skipped: no file is selected.")
            return
        }

        guard !workflowFileHasUnsavedChanges else {
            log("Workflow file repair blocked: save or revert current changes first.")
            return
        }

        if !workflowFileNotFound, pendingWorkflowFileRepairConfirmation != selectedWorkflowFile {
            pendingWorkflowFileRepairConfirmation = selectedWorkflowFile
            workflowFileStatus = .error("Restore default will overwrite the current \(selectedWorkflowFile.fileName). Confirm or cancel below.")
            log("Restore default requested for \(selectedWorkflowFile.fileName). Press Confirm Restore Default to overwrite it.")
            return
        }

        let template = activeProjectTemplate ?? .blank
        if activeProjectTemplate == nil {
            log("Workflow file repair note: template is unknown, using Blank defaults.")
        }

        let workflowSettings = workflowSettingsForProject(projectURL, template: activeProjectTemplate)

        do {
            let result = try workflowFileRepairService.regenerateFile(
                kind: selectedWorkflowFile,
                projectURL: projectURL,
                projectName: activeProjectName,
                gitHubUsername: settings.gitHubUsername,
                repoVisibility: settings.repoVisibility,
                template: template,
                validationTargetOverride: workflowSettings.trimmedValidationTarget
            )
            pendingWorkflowFileRepairConfirmation = nil
            openWorkflowFile(selectedWorkflowFile)
            let actionVerb = result.restoredExistingFile ? "Restored default" : "Regenerated missing"
            if result.isExecutable {
                log("\(actionVerb) \(selectedWorkflowFile.fileName) and ensured it is executable.")
            } else {
                log("\(actionVerb) \(selectedWorkflowFile.fileName).")
            }
            workflowFileStatus = .success(result.restoredExistingFile ? "Restored default \(selectedWorkflowFile.fileName)." : "Regenerated \(selectedWorkflowFile.fileName).")
        } catch {
            pendingWorkflowFileRepairConfirmation = nil
            log("Workflow file repair failed: \(error.localizedDescription)")
            workflowFileStatus = .error("Could not restore \(selectedWorkflowFile.fileName). \(error.localizedDescription)")
        }
    }

    func cancelWorkflowFileRepairConfirmation() {
        guard pendingWorkflowFileRepairConfirmation != nil else {
            return
        }

        pendingWorkflowFileRepairConfirmation = nil
        workflowFileStatus = nil
        log("Workflow file restore canceled.")
    }

    func saveWorkflowSettings() {
        guard let activeProjectURL else {
            log("Workflow settings save skipped: no project is selected.")
            return
        }

        do {
            let fileURL = try workflowSettingsService.saveSettings(currentWorkflowSettingsDraft, for: activeProjectURL)
            workflowSettingsOriginal = currentWorkflowSettingsDraft
            workflowSettingsConfigPath = fileURL.path
            workflowSettingsStatusMessage = "Saved \(fileURL.lastPathComponent)."
            workflowSettingsUsingDefaults = false
            workflowSettingsHasUnsavedChanges = false
            log("Saved workflow settings: \(fileURL.lastPathComponent)")
        } catch {
            log("Workflow settings save failed: \(error.localizedDescription)")
        }
    }

    func revertWorkflowSettings() {
        guard let activeProjectURL else {
            log("Workflow settings revert skipped: no project is selected.")
            return
        }

        loadWorkflowSettings(for: activeProjectURL, template: activeProjectTemplate)
        log("Reverted workflow settings from disk.")
    }

    func saveCurrentAsPreset() {
        let trimmedName = presetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            log("Preset save blocked: preset name is required")
            return
        }

        let saveResult = presetStore.savePreset(named: trimmedName, from: settings)
        presets = saveResult.presets
        selectedPresetName = saveResult.preset.name
        presetNameDraft = saveResult.preset.name

        if saveResult.wasRenamed {
            log("Preset name already existed. Saved as '\(saveResult.preset.name)'.")
        } else {
            log("Saved preset '\(saveResult.preset.name)'.")
        }
    }

    func applySelectedPreset() {
        guard let selectedPreset else {
            log("Preset apply skipped: no preset is selected.")
            return
        }

        settings = selectedPreset.applying(to: settings)
        presetNameDraft = selectedPreset.name
        log("Applied preset '\(selectedPreset.name)'.")
    }

    func deleteSelectedPreset() {
        guard !selectedPresetName.isEmpty else {
            log("Preset delete skipped: no preset is selected.")
            return
        }

        let deletedPresetName = selectedPresetName
        presets = presetStore.deletePreset(named: deletedPresetName)
        selectedPresetName = presets.first?.name ?? ""
        if presetNameDraft == deletedPresetName {
            presetNameDraft = ""
        }
        log("Deleted preset '\(deletedPresetName)'.")
    }

    private func log(_ message: String) {
        let entry = logger.log(message)
        logEntries.append(entry)
    }

    func openLastCreatedProjectInFinder() {
        performPostCreateAction {
            postCreateActionService.openInFinder(projectURL: $0)
        }
    }

    func copyLastCreatedProjectPath() {
        performPostCreateAction {
            postCreateActionService.copyProjectPath(projectURL: $0)
        }
    }

    func openLastCreatedProjectInTerminal() {
        performPostCreateAction {
            postCreateActionService.openInTerminal(projectURL: $0)
        }
    }

    func openLastCreatedProjectInGodot() {
        performGodotLaunch(
            projectURL: lastCreatedProjectURL,
            template: lastCreatedTemplate,
            source: "Post-create action"
        )
    }

    func openInspectedProjectInGodot() {
        performGodotLaunch(
            projectURL: inspectedProjectSummary?.projectURL,
            template: inspectedProjectSummary?.detectedTemplate,
            source: "Project inspector action"
        )
    }

    func copyLastCreatedCodexStarterPrompt() {
        guard let lastCreatedProjectURL, let lastCreatedTemplate else {
            log("Prompt action skipped: no prompt pack is available yet.")
            return
        }

        let prompt = codexPromptPackService.starterPrompt(
            for: lastCreatedProjectURL,
            template: lastCreatedTemplate,
            workflowSettings: workflowSettingsForProject(lastCreatedProjectURL, template: lastCreatedTemplate)
        )

        switch postCreateActionService.copyPrompt(prompt.body, title: prompt.title) {
        case let .success(message):
            log(message)
            promptPackStatus = .success("Copied \(prompt.title).")
        case let .failure(error):
            log("Prompt action failed: \(error.localizedDescription)")
            promptPackStatus = .error("Could not copy \(prompt.title). \(error.localizedDescription)")
        }
    }

    func copyActiveCodexStarterPrompt() {
        guard let activeProjectURL, let activeProjectTemplate else {
            log("Prompt action skipped: no prompt pack is available yet.")
            return
        }

        let prompt = codexPromptPackService.starterPrompt(
            for: activeProjectURL,
            template: activeProjectTemplate,
            workflowSettings: workflowSettingsForProject(activeProjectURL, template: activeProjectTemplate)
        )

        switch postCreateActionService.copyPrompt(prompt.body, title: prompt.title) {
        case let .success(message):
            log(message)
            promptPackStatus = .success("Copied \(prompt.title).")
        case let .failure(error):
            log("Prompt action failed: \(error.localizedDescription)")
            promptPackStatus = .error("Could not copy \(prompt.title). \(error.localizedDescription)")
        }
    }

    func openInspectedProjectInCodex() {
        guard let inspectedProjectSummary else {
            log("Codex handoff skipped: no inspected project is available yet.")
            return
        }

        if inspectedProjectSummary.detectedTemplate == nil {
            log("Codex handoff note: template is unknown, using the generic Blank prompt.")
        }

        performCodexHandoff(projectURL: inspectedProjectSummary.projectURL, template: inspectedProjectSummary.codexTemplate)
    }

    func copySelectedPrompt() {
        let promptTitle = selectedPrompt?.title ?? selectedPromptKind.title

        guard let promptBody = promptPreviewOrGeneratedText() else {
            log("Prompt action skipped: no prompt pack is available yet.")
            promptPackStatus = .error("No active project prompt is available.")
            return
        }

        switch postCreateActionService.copyPrompt(promptBody, title: promptTitle) {
        case let .success(message):
            log(message)
            promptPackStatus = .success("Copied prompt.")
        case let .failure(error):
            log("Prompt action failed: \(error.localizedDescription)")
            promptPackStatus = .error("Could not copy prompt. \(error.localizedDescription)")
        }
    }

    func generatePromptPreview() {
        guard let previewText = generatedPromptPreviewText() else {
            log("Prompt preview skipped: no prompt pack is available yet.")
            promptPackStatus = .error("No active project prompt is available.")
            return
        }

        promptPackPreviewText = previewText
        log("Prompt preview generated for \(selectedPromptKind.title) in \(selectedPromptMode.title.lowercased()) mode.")
        promptPackStatus = .success("Prompt preview generated.")
    }

    func applyPromptPreset(_ preset: PromptPackPreset) {
        selectedPromptPreset = preset

        let configuration = preset.configuration
        applyPromptPresetConfiguration(configuration)
    }

    func saveCurrentPromptPreset(named desiredName: String) {
        let trimmedName = desiredName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            promptPackStatus = .error("Preset name is required.")
            log("Saved prompt preset skipped: preset name is required.")
            return
        }

        let preset = SavedPromptPreset(
            id: savedPromptPresets.first(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame })?.id ?? UUID().uuidString,
            name: trimmedName,
            promptKind: selectedPromptKind,
            mode: selectedPromptMode,
            includeProjectSummary: includeProjectSummary,
            includeWorkflowFiles: includeWorkflowFiles,
            includeStarterContext: includeStarterContext,
            includeNotesOrContext: includeNotesOrContext,
            includeRecentActivityContext: includeRecentActivityContext,
            recentActivityContextLimit: recentActivityContextLimit
        )

        let isUpdate = savedPromptPresets.contains { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }
        let updatedPresets = savedPromptPresets.filter { $0.name.localizedCaseInsensitiveCompare(trimmedName) != .orderedSame } + [preset]

        guard savedPromptPresetStore.save(updatedPresets) else {
            promptPackStatus = .error("Could not save preset.")
            log("Saved prompt preset failed for '\(trimmedName)'.")
            return
        }

        savedPromptPresets = savedPromptPresetStore.load()
        selectedSavedPromptPresetID = preset.id
        promptPresetNameDraft = preset.name
        promptPackStatus = .success(isUpdate ? "Updated preset." : "Saved preset.")
        log("\(isUpdate ? "Updated" : "Saved") prompt preset '\(preset.name)'.")
    }

    func applySavedPromptPreset(_ preset: SavedPromptPreset) {
        selectedSavedPromptPresetID = preset.id
        promptPresetNameDraft = preset.name
        if let promptKind = preset.promptKind {
            selectedPromptKind = promptKind
        }
        applyPromptPresetConfiguration(preset.configuration)
        if let includeRecentActivityContext = preset.includeRecentActivityContext {
            self.includeRecentActivityContext = includeRecentActivityContext
        }
        if let recentActivityContextLimit = preset.recentActivityContextLimit {
            self.recentActivityContextLimit = recentActivityContextLimit
        }
        promptPackStatus = .success("Applied preset.")
        log("Applied prompt preset '\(preset.name)'.")
    }

    func deleteSavedPromptPreset(_ preset: SavedPromptPreset) {
        let updatedPresets = savedPromptPresets.filter { $0.id != preset.id }
        guard savedPromptPresetStore.save(updatedPresets) else {
            promptPackStatus = .error("Could not delete preset.")
            log("Delete prompt preset failed for '\(preset.name)'.")
            return
        }

        savedPromptPresets = savedPromptPresetStore.load()
        if selectedSavedPromptPresetID == preset.id {
            selectedSavedPromptPresetID = savedPromptPresets.first?.id ?? ""
        }
        promptPackStatus = .success("Deleted preset.")
        log("Deleted prompt preset '\(preset.name)'.")
    }

    func exportSavedPromptPresets() {
        do {
            guard let destinationURL = try promptPresetTransferService.exportPresets(savedPromptPresets) else {
                return
            }

            promptPackStatus = .success("Exported presets.")
            log("Exported \(savedPromptPresets.count) prompt preset(s) to \(destinationURL.path).")
        } catch {
            promptPackStatus = .error("Export failed. \(error.localizedDescription)")
            log("Prompt preset export failed: \(error.localizedDescription)")
        }
    }

    func importSavedPromptPresets() {
        do {
            guard let importedPresets = try promptPresetTransferService.importPresets() else {
                return
            }

            let mergedPresets = mergeImportedPromptPresets(importedPresets, into: savedPromptPresets)
            guard savedPromptPresetStore.save(mergedPresets) else {
                promptPackStatus = .error("Import failed. Could not save presets.")
                log("Prompt preset import failed: merged presets could not be saved.")
                return
            }

            savedPromptPresets = savedPromptPresetStore.load()
            if let selectedSavedPromptPreset, savedPromptPresets.contains(selectedSavedPromptPreset) {
                selectedSavedPromptPresetID = selectedSavedPromptPreset.id
            } else {
                selectedSavedPromptPresetID = savedPromptPresets.first?.id ?? ""
            }

            promptPackStatus = .success("Imported \(importedPresets.count) preset(s).")
            log("Imported \(importedPresets.count) prompt preset(s).")
        } catch {
            promptPackStatus = .error("Import failed. \(error.localizedDescription)")
            log("Prompt preset import failed: \(error.localizedDescription)")
        }
    }

    private func applyPromptPresetConfiguration(_ configuration: PromptPackPresetConfiguration) {
        selectedPromptMode = configuration.mode
        includeProjectSummary = configuration.includeProjectSummary
        includeWorkflowFiles = configuration.includeWorkflowFiles
        includeStarterContext = configuration.includeStarterContext
        includeNotesOrContext = configuration.includeNotesOrContext
        clearPromptPreview()
    }

    func copyLastCreatedSummary() {
        guard let summaryText = lastCreatedSummaryText else {
            log("Summary action skipped: no created project summary is available yet.")
            return
        }

        switch postCreateActionService.copySummary(summaryText) {
        case let .success(message):
            log(message)
        case let .failure(error):
            log("Summary action failed: \(error.localizedDescription)")
        }
    }

    func copyInspectedProjectSummary() {
        guard let summaryText = inspectedProjectSummary?.summaryText else {
            log("Summary action skipped: no inspected project summary is available yet.")
            return
        }

        switch postCreateActionService.copySummary(summaryText) {
        case let .success(message):
            log(message)
        case let .failure(error):
            log("Summary action failed: \(error.localizedDescription)")
        }
    }

    func copyLastCreatedFileTree() {
        guard let fileTreeText = lastCreatedFileTreeText else {
            log("Summary action skipped: no created project summary is available yet.")
            return
        }

        switch postCreateActionService.copyFileTree(fileTreeText) {
        case let .success(message):
            log(message)
        case let .failure(error):
            log("Summary action failed: \(error.localizedDescription)")
        }
    }

    func copyInspectedProjectFileTree() {
        guard let fileTreeText = inspectedProjectSummary?.fileTreeText else {
            log("Summary action skipped: no inspected project summary is available yet.")
            return
        }

        switch postCreateActionService.copyFileTree(fileTreeText) {
        case let .success(message):
            log(message)
        case let .failure(error):
            log("Summary action failed: \(error.localizedDescription)")
        }
    }

    func openRecentProjectInFinder(_ project: RecentProject) {
        switch postCreateActionService.openInFinder(projectURL: project.projectURL) {
        case let .success(message):
            log(message)
        case let .failure(error):
            log("Recent project action failed: \(error.localizedDescription)")
        }
    }

    func openRecentProjectInGodot(_ project: RecentProject) {
        performGodotLaunch(
            projectURL: project.projectURL,
            template: project.template,
            source: "Recent project action"
        )
    }

    func copyRecentProjectPath(_ project: RecentProject) {
        switch postCreateActionService.copyProjectPath(projectURL: project.projectURL) {
        case let .success(message):
            log(message)
        case let .failure(error):
            log("Recent project action failed: \(error.localizedDescription)")
        }
    }

    func openLastCreatedProjectInCodex() {
        guard let lastCreatedProjectURL, let lastCreatedTemplate else {
            log("Codex handoff skipped: no created project is available yet.")
            return
        }

        performCodexHandoff(projectURL: lastCreatedProjectURL, template: lastCreatedTemplate)
    }

    func openRecentProjectInCodex(_ project: RecentProject) {
        performCodexHandoff(projectURL: project.projectURL, template: project.template)
    }

    private func performPostCreateAction(
        _ action: (URL) -> Result<String, Error>
    ) {
        guard let lastCreatedProjectURL else {
            log("Post-create action skipped: no created project is available yet.")
            return
        }

        switch action(lastCreatedProjectURL) {
        case let .success(message):
            log(message)
        case let .failure(error):
            log("Post-create action failed: \(error.localizedDescription)")
        }
    }

    private func performGodotLaunch(projectURL: URL?, template: ProjectTemplate?, source: String) {
        guard let projectURL else {
            log("\(source) skipped: no project is available yet.")
            return
        }

        let workflowSettings = workflowSettingsForProject(projectURL, template: template)

        switch godotLaunchService.openProject(
            at: projectURL,
            projectOverridePath: workflowSettings.trimmedGodotPathOverride,
            configuredExecutablePath: settings.godotExecutablePath
        ) {
        case let .success(message):
            log(message)
        case let .failure(error):
            log("Godot launch failed: \(error.localizedDescription)")
        }
    }

    private func integrationStatus(from result: GitInitializationResult) -> ProjectIntegrationStatus {
        if result.succeeded {
            return result.skipped ? .skipped("Already initialized") : .succeeded
        }

        if result.skipped {
            return .skipped("Git unavailable")
        }

        if let failureReason = result.messages.last(where: { $0.contains("failed") || $0.contains("error") }) {
            return .failed(failureReason)
        }

        return .failed("Initialization failed")
    }

    private func integrationStatus(from result: GitHubSetupResult) -> ProjectIntegrationStatus {
        if result.succeeded {
            return result.skipped ? .skipped("Origin already exists") : .succeeded
        }

        if result.skipped {
            if result.messages.last(where: { $0.contains("no GitHub username") }) != nil {
                return .skipped("No GitHub username")
            }
            if result.messages.last(where: { $0.contains("not authenticated") }) != nil {
                return .skipped("gh not authenticated")
            }
            if result.messages.last(where: { $0.contains("not available") }) != nil {
                return .skipped("gh unavailable")
            }
            if result.messages.last(where: { $0.contains("origin remote") || $0.contains("Origin remote already exists") }) != nil {
                return .skipped("Origin already exists")
            }
            if skipReasonLike(result.messages) != nil {
                return .skipped("Setup skipped")
            }
            return .skipped("Setup skipped")
        }

        if let failureReason = result.messages.last(where: { $0.contains("failed") || $0.contains("error") }) {
            return .failed(failureReason)
        }

        return .failed("Setup failed")
    }

    private func prompt(for kind: CodexPromptKind) -> CodexPrompt? {
        availablePromptPack.first(where: { $0.kind == kind })
    }

    private func clearPromptPreview() {
        promptPackPreviewText = ""
    }

    private func promptPreviewOrGeneratedText() -> String? {
        if hasPromptPreview {
            return promptPackPreviewText
        }

        return generatedPromptPreviewText()
    }

    private func generatedPromptPreviewText() -> String? {
        guard
            let activeProjectURL,
            let activeProjectTemplate,
            prompt(for: selectedPromptKind) != nil
        else {
            return nil
        }

        let sections = codexPromptPackService.promptSections(
            for: selectedPromptKind,
            projectURL: activeProjectURL,
            template: activeProjectTemplate,
            workflowSettings: workflowSettingsForProject(activeProjectURL, template: activeProjectTemplate)
        )
        .filter { includedPromptSections.contains($0.kind) }

        var body = sections.map(\.body).joined(separator: "\n\n")

        let trimmedCustomContext = promptCustomContextText.trimmingCharacters(in: .whitespacesAndNewlines)
        if includeNotesOrContext, !trimmedCustomContext.isEmpty {
            body += "\n\nAdditional Context\n\(trimmedCustomContext)"
        }

        if let recentActivityContextText {
            body += "\n\n\(recentActivityContextText)"
        }

        guard let promptHeader = selectedPromptMode.promptHeader else {
            return body
        }

        return "\(promptHeader)\n\n\(body)"
    }

    private var includedPromptSections: Set<CodexPromptSectionKind> {
        var sections = Set<CodexPromptSectionKind>()

        if includeProjectSummary {
            sections.insert(.projectSummary)
        }
        if includeWorkflowFiles {
            sections.insert(.workflowFiles)
        }
        if includeStarterContext {
            sections.insert(.starterContext)
        }
        if includeNotesOrContext {
            sections.insert(.notesOrContext)
        }

        return sections
    }

    private var recentActivityContextText: String? {
        guard includeRecentActivityContext else {
            return nil
        }

        let recentMessages = logEntries
            .suffix(recentActivityContextLimit)
            .map(\.message)

        guard !recentMessages.isEmpty else {
            return nil
        }

        let lines = recentMessages.map { "- \($0)" }.joined(separator: "\n")
        return "Recent Activity\n\(lines)"
    }

    private func mergeImportedPromptPresets(
        _ importedPresets: [SavedPromptPreset],
        into existingPresets: [SavedPromptPreset]
    ) -> [SavedPromptPreset] {
        var mergedByName = Dictionary(
            uniqueKeysWithValues: existingPresets.map {
                ($0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), $0)
            }
        )

        for preset in importedPresets {
            let trimmedName = preset.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                continue
            }

            let normalizedKey = trimmedName.lowercased()
            let resolvedPreset: SavedPromptPreset

            if let existingPreset = mergedByName[normalizedKey] {
                resolvedPreset = SavedPromptPreset(
                    id: existingPreset.id,
                    name: trimmedName,
                    promptKind: preset.promptKind,
                    mode: preset.mode,
                    includeProjectSummary: preset.includeProjectSummary,
                    includeWorkflowFiles: preset.includeWorkflowFiles,
                    includeStarterContext: preset.includeStarterContext,
                    includeNotesOrContext: preset.includeNotesOrContext,
                    includeRecentActivityContext: preset.includeRecentActivityContext,
                    recentActivityContextLimit: preset.recentActivityContextLimit
                )
            } else {
                resolvedPreset = SavedPromptPreset(
                    id: preset.id,
                    name: trimmedName,
                    promptKind: preset.promptKind,
                    mode: preset.mode,
                    includeProjectSummary: preset.includeProjectSummary,
                    includeWorkflowFiles: preset.includeWorkflowFiles,
                    includeStarterContext: preset.includeStarterContext,
                    includeNotesOrContext: preset.includeNotesOrContext,
                    includeRecentActivityContext: preset.includeRecentActivityContext,
                    recentActivityContextLimit: preset.recentActivityContextLimit
                )
            }

            mergedByName[normalizedKey] = resolvedPreset
        }

        return Array(mergedByName.values)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func logCreateProjectValidationIssues(prefix: String) {
        guard !createProjectValidationIssues.isEmpty else {
            return
        }

        for issue in createProjectValidationIssues {
            log("\(prefix): \(issue)")
        }
    }

    private func skipReasonLike(_ messages: [String]) -> String? {
        messages.last(where: { $0.contains("skipped") || $0.contains("Skipping") })
    }

    private func performCodexHandoff(projectURL: URL, template: ProjectTemplate) {
        let workflowSettings = workflowSettingsForProject(projectURL, template: template)

        switch codexHandoffService.openInCodex(
            projectURL: projectURL,
            template: template,
            workflowSettings: workflowSettings
        ) {
        case let .success(outcome):
            for message in outcome.messages {
                log(message)
            }
            codexHandoffMessage = outcome.nextStepMessage
            log("Codex handoff ready for \(projectURL.lastPathComponent).")
        case let .failure(error):
            codexHandoffMessage = "Codex handoff could not start. \(error.localizedDescription)"
            log("Codex handoff failed: \(error.localizedDescription)")
        }
    }

    private func recordRecentProject(from summary: ProjectCreationSummary) {
        let recentProject = RecentProject(
            path: summary.finalProjectURL.path,
            projectName: summary.projectName,
            template: summary.template,
            createdAt: Date(),
            gitInitialized: summary.gitStatus.indicatesSuccess,
            gitHubStatus: summary.gitHubStatus
        )

        let updatedProjects = recentProjectsStore.record(recentProject)
        recentProjects = updatedProjects
    }

    private func clearWorkflowEditor() {
        selectedWorkflowFile = nil
        workflowEditorText = ""
        workflowEditorOriginalText = ""
        workflowEditorFilePath = ""
        workflowFileNotFound = false
        workflowFileHasUnsavedChanges = false
        pendingWorkflowFileRepairConfirmation = nil
    }

    private func clearExplicitWorkflowSelection() {
        selectedWorkflowProjectURL = nil
        selectedWorkflowProjectName = nil
        selectedWorkflowProjectTemplate = nil
    }

    private func clearProjectAudit() {
        lastProjectAudit = nil
    }

    private func clearAssetImport() {
        lastAssetImport = nil
    }

    private func buildHandoffBundleText() -> String? {
        guard let input = buildHandoffBundleInput() else {
            return nil
        }

        return handoffBundleService.buildBundle(from: input)
    }

    private func buildHandoffBundleInput() -> HandoffBundleInput? {
        guard let activeProjectURL else {
            return nil
        }

        let inspectedSummary = projectInspectorService.inspectProject(at: activeProjectURL)
        let template = activeProjectTemplate ?? inspectedSummary.detectedTemplate
        let workflowSettings = workflowSettingsForProject(activeProjectURL, template: template)
        let starterPrompt = codexPromptPackService.starterPrompt(
            for: activeProjectURL,
            template: template ?? .blank,
            workflowSettings: workflowSettings
        ).body

        let workflowFiles = [
            inspectedSummary.hasAgentsFile ? "AGENTS.md" : nil,
            inspectedSummary.hasReadmeFile ? "README.md" : nil,
            inspectedSummary.hasValidationScript ? "run_validation.sh" : nil,
        ].compactMap { $0 }
        let assetInventory = assetPromptContextService.inventorySummary(for: activeProjectURL)

        return HandoffBundleInput(
            projectName: activeProjectName,
            projectPath: activeProjectURL.path,
            templateName: template?.rawValue ?? "Unknown",
            gitStatus: activeGitStatusDescription(from: inspectedSummary),
            gitHubStatus: activeGitHubStatusDescription(from: inspectedSummary),
            workflowFiles: workflowFiles,
            fileTreeText: inspectedSummary.fileTreeText,
            auditSummaryText: relevantAuditSummaryText(for: activeProjectURL),
            assetInventorySummaryText: assetInventory.bundleSummaryText,
            recentAssetImportText: relevantRecentAssetImportText(for: activeProjectURL),
            workflowSettingsSummaryText: workflowSettingsSummaryText(for: activeProjectURL, template: template),
            starterPrompt: starterPrompt,
            nextSteps: handoffNextSteps(for: inspectedSummary, template: template)
        )
    }

    private func activeGitStatusDescription(from inspectedSummary: InspectedProjectSummary) -> String {
        if let recentProject = activeRecentProject {
            return recentProject.gitInitialized ? "Ready" : "Warn (missing .git)"
        }

        if activeProjectURL == lastCreatedProjectURL, let lastCreatedSummary {
            return lastCreatedSummary.gitStatus.displayText
        }

        return inspectedSummary.hasGitDirectory ? "Ready" : "Warn (missing .git)"
    }

    private func activeGitHubStatusDescription(from inspectedSummary: InspectedProjectSummary) -> String {
        if let recentProject = activeRecentProject {
            return recentProject.gitHubStatus.displayText
        }

        if activeProjectURL == lastCreatedProjectURL, let lastCreatedSummary {
            return lastCreatedSummary.gitHubStatus.displayText
        }

        switch inspectedSummary.originRemoteStatus {
        case let .present(remoteURL):
            return "Origin present (\(remoteURL))"
        case .absent:
            return "Origin missing"
        case let .unknown(reason):
            return "Origin unknown (\(reason))"
        }
    }

    private func relevantAuditSummaryText(for projectURL: URL) -> String? {
        guard lastProjectAudit?.projectURL == projectURL else {
            return nil
        }

        return lastProjectAudit?.summaryText
    }

    private func relevantRecentAssetImportText(for projectURL: URL) -> String? {
        guard lastAssetImport?.projectURL == projectURL else {
            return nil
        }

        guard let lastAssetImport else {
            return nil
        }

        return """
        \(lastAssetImport.sourceKind.displayText)
        \(lastAssetImport.recentImportText)
        """
    }

    private func handoffNextSteps(for inspectedSummary: InspectedProjectSummary, template: ProjectTemplate?) -> [String] {
        var steps = ["Read `AGENTS.md` first if it is present.", "Run `./run_validation.sh` after the first change if it is available."]

        if !inspectedSummary.hasAgentsFile {
            steps.append("Add or restore `AGENTS.md` before a Codex handoff.")
        }

        if !inspectedSummary.hasValidationScript {
            steps.append("Restore `run_validation.sh` before handing the project off.")
        }

        if !inspectedSummary.hasGitDirectory {
            steps.append("Initialize Git if this project should be tracked.")
        }

        if template == nil {
            steps.append("Template is unknown, so review the scaffold manually before editing.")
        }

        return steps
    }

    private var explicitWorkflowSelectionURL: URL? {
        guard let selectedWorkflowProjectURL else {
            return nil
        }

        guard selectedWorkflowProjectURL != lastCreatedProjectURL else {
            return nil
        }

        return selectedWorkflowProjectURL
    }

    private var activeRecentProject: RecentProject? {
        guard let explicitWorkflowSelectionURL else {
            return nil
        }

        return recentProjects.first(where: { $0.path == explicitWorkflowSelectionURL.path })
    }

    private var activeProjectSource: ActiveProjectSource {
        if activeRecentProject != nil {
            return .recent
        }

        if inspectedProjectSummary != nil {
            return .inspected
        }

        if lastCreatedProjectURL != nil {
            return .lastCreated
        }

        return .none
    }

    private enum ActiveProjectSource {
        case recent
        case inspected
        case lastCreated
        case none
    }

    private var currentWorkflowSettingsDraft: ProjectWorkflowSettings {
        ProjectWorkflowSettings(
            validationTarget: workflowSettingsValidationTarget,
            godotPathOverride: workflowSettingsGodotPathOverride,
            handoffNote: workflowSettingsHandoffNote,
            projectNote: workflowSettingsProjectNote
        )
    }

    private func updateWorkflowSettingsDirtyStateIfNeeded() {
        guard !isUpdatingWorkflowSettingsDraft else {
            return
        }

        workflowSettingsHasUnsavedChanges = currentWorkflowSettingsDraft != workflowSettingsOriginal
    }

    private func loadWorkflowSettings(for projectURL: URL, template: ProjectTemplate?) {
        let document = workflowSettingsService.loadSettings(for: projectURL, template: template)
        workflowSettingsLoadedProjectURL = projectURL
        workflowSettingsOriginal = document.settings
        workflowSettingsConfigPath = document.fileURL.path
        workflowSettingsStatusMessage = document.statusMessage
        workflowSettingsUsingDefaults = document.usedDefaults
        applyWorkflowSettingsDraft(document.settings)
    }

    private func applyWorkflowSettingsDraft(_ settings: ProjectWorkflowSettings) {
        isUpdatingWorkflowSettingsDraft = true
        workflowSettingsValidationTarget = settings.validationTarget
        workflowSettingsGodotPathOverride = settings.godotPathOverride
        workflowSettingsHandoffNote = settings.handoffNote
        workflowSettingsProjectNote = settings.projectNote
        workflowSettingsHasUnsavedChanges = false
        isUpdatingWorkflowSettingsDraft = false
    }

    private func workflowSettingsForProject(_ projectURL: URL, template: ProjectTemplate?) -> ProjectWorkflowSettings {
        if workflowSettingsLoadedProjectURL?.path == projectURL.path {
            return currentWorkflowSettingsDraft
        }

        return workflowSettingsService.loadSettings(for: projectURL, template: template).settings
    }

    private func workflowSettingsSummaryText(for projectURL: URL, template: ProjectTemplate?) -> String? {
        let settings = workflowSettingsForProject(projectURL, template: template)
        let defaults = ProjectWorkflowSettings.defaults(for: template)
        let lines = settings.summaryLines(defaults: defaults)
        guard !lines.isEmpty else {
            return nil
        }

        return lines.joined(separator: "\n")
    }
}
