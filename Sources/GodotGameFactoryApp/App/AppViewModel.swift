import SwiftUI

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
    @Published var dryRunEnabled = false
    @Published var presetNameDraft = ""
    @Published var selectedPresetName = ""
    @Published var selectedPromptKind: CodexPromptKind = .starter
    @Published private(set) var lastCreatedProjectURL: URL?
    @Published private(set) var lastCreatedTemplate: ProjectTemplate?
    @Published private(set) var lastCreatedSummary: ProjectCreationSummary?
    @Published private(set) var recentProjects: [RecentProject]
    @Published private(set) var codexHandoffMessage: String?
    @Published private(set) var presets: [ProjectPreset]
    @Published private(set) var selectedWorkflowProjectURL: URL?
    @Published private(set) var selectedWorkflowProjectName: String?
    @Published private(set) var selectedWorkflowFile: WorkflowFileKind?
    @Published private(set) var workflowEditorText = ""
    @Published private(set) var workflowEditorFilePath = ""
    @Published private(set) var workflowFileNotFound = false
    @Published private(set) var workflowFileHasUnsavedChanges = false

    private let logger: AppLogger
    private let settingsStore: AppSettingsStore
    private let presetStore: ProjectPresetStore
    private let recentProjectsStore: RecentProjectsStore
    private let generator: ProjectGenerator
    private let gitService: GitService
    private let gitHubService: GitHubService
    private let postCreateActionService: PostCreateActionService
    private let codexPromptPackService: CodexPromptPackService
    private let codexHandoffService: CodexHandoffService
    private let folderPickerService: FolderPickerService
    private let godotPathPickerService: GodotPathPickerService
    private let godotLaunchService: GodotLaunchService
    private let workflowFileService: WorkflowFileService
    private var hasFinishedInitializing = false
    private var hasLoggedSaveFailure = false
    private var hasSavedSettings = false
    private var workflowEditorOriginalText = ""

    var hasLastCreatedProject: Bool {
        lastCreatedProjectURL != nil
    }

    var canPreviewOrCreateProject: Bool {
        !settings.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !settings.baseDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    var workflowFileTargetProjectURL: URL? {
        selectedWorkflowProjectURL ?? lastCreatedProjectURL
    }

    var workflowFileTargetProjectName: String {
        if let selectedWorkflowProjectName {
            return selectedWorkflowProjectName
        }

        if let lastCreatedSummary {
            return lastCreatedSummary.projectName
        }

        return workflowFileTargetProjectURL?.lastPathComponent ?? "No project selected"
    }

    var workflowFileTargetProjectPath: String {
        workflowFileTargetProjectURL?.path ?? "No project selected yet."
    }

    var hasWorkflowFileTarget: Bool {
        workflowFileTargetProjectURL != nil
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

    var hasOpenedWorkflowFile: Bool {
        selectedWorkflowFile != nil
    }

    var lastCreatedProjectPath: String {
        lastCreatedProjectURL?.path ?? "No project created yet."
    }

    var lastCreatedCodexStarterPrompt: String? {
        prompt(for: .starter)?.body
    }

    var lastCreatedSummaryText: String? {
        lastCreatedSummary?.summaryText
    }

    var lastCreatedFileTreeText: String? {
        lastCreatedSummary?.fileTreeText
    }

    var availablePromptPack: [CodexPrompt] {
        guard let lastCreatedProjectURL, let lastCreatedTemplate else {
            return []
        }

        return codexPromptPackService.promptPack(for: lastCreatedProjectURL, template: lastCreatedTemplate)
    }

    var hasPromptPack: Bool {
        !availablePromptPack.isEmpty
    }

    var canSavePreset: Bool {
        !presetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var selectedPrompt: CodexPrompt? {
        availablePromptPack.first(where: { $0.kind == selectedPromptKind }) ?? availablePromptPack.first
    }

    init(
        settingsStore: AppSettingsStore = AppSettingsStore(),
        presetStore: ProjectPresetStore = ProjectPresetStore(),
        recentProjectsStore: RecentProjectsStore = RecentProjectsStore(),
        logger: AppLogger = AppLogger(),
        generator: ProjectGenerator = ProjectGenerator(),
        gitService: GitService = GitService(),
        gitHubService: GitHubService = GitHubService(),
        postCreateActionService: PostCreateActionService = PostCreateActionService(),
        codexPromptPackService: CodexPromptPackService = CodexPromptPackService(),
        codexHandoffService: CodexHandoffService = CodexHandoffService(),
        folderPickerService: FolderPickerService = FolderPickerService(),
        godotPathPickerService: GodotPathPickerService = GodotPathPickerService(),
        godotLaunchService: GodotLaunchService = GodotLaunchService(),
        workflowFileService: WorkflowFileService = WorkflowFileService()
    ) {
        self.settingsStore = settingsStore
        self.presetStore = presetStore
        self.recentProjectsStore = recentProjectsStore
        self.logger = logger
        self.generator = generator
        self.gitService = gitService
        self.gitHubService = gitHubService
        self.postCreateActionService = postCreateActionService
        self.codexPromptPackService = codexPromptPackService
        self.codexHandoffService = codexHandoffService
        self.folderPickerService = folderPickerService
        self.godotPathPickerService = godotPathPickerService
        self.godotLaunchService = godotLaunchService
        self.workflowFileService = workflowFileService
        self.settings = settingsStore.load()
        self.presets = presetStore.load()
        self.recentProjects = recentProjectsStore.load()
        self.logEntries = logger.entries
        self.selectedPresetName = presets.first?.name ?? ""

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
        hasFinishedInitializing = true
    }

    func createProject() {
        if dryRunEnabled {
            previewProject()
            return
        }

        let trimmedName = settings.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseDirectory = settings.baseDirectory.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            log("Create Project blocked: project name is required")
            return
        }

        guard !trimmedBaseDirectory.isEmpty else {
            log("Create Project blocked: base directory is required")
            return
        }

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
            clearWorkflowEditor()
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
        } catch {
            log("Project generation failed: \(error.localizedDescription)")
        }
    }

    func previewProject() {
        let trimmedName = settings.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBaseDirectory = settings.baseDirectory.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            log("Preview blocked: project name is required")
            return
        }

        guard !trimmedBaseDirectory.isEmpty else {
            log("Preview blocked: base directory is required")
            return
        }

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
        } catch {
            log("Preview failed: \(error.localizedDescription)")
        }
    }

    func chooseBaseDirectory() {
        guard let selectedFolderURL = folderPickerService.chooseFolder() else {
            return
        }

        settings.baseDirectory = selectedFolderURL.path
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

        selectedWorkflowProjectURL = project.projectURL
        selectedWorkflowProjectName = project.projectName
        clearWorkflowEditor()
        log("Workflow file target set to \(project.projectName).")
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

        if loadResult.isMissing {
            workflowEditorText = ""
            workflowEditorOriginalText = ""
            workflowFileNotFound = true
            workflowFileHasUnsavedChanges = false
            log("Workflow file not found: \(kind.fileName)")
            return
        }

        guard let contents = loadResult.contents else {
            workflowEditorText = ""
            workflowEditorOriginalText = ""
            workflowFileNotFound = false
            workflowFileHasUnsavedChanges = false
            log("Workflow file open failed: could not read \(kind.fileName).")
            return
        }

        workflowEditorText = contents
        workflowEditorOriginalText = contents
        workflowFileNotFound = false
        workflowFileHasUnsavedChanges = false
        log("Opened workflow file: \(kind.fileName)")
    }

    func updateWorkflowEditorText(_ text: String) {
        workflowEditorText = text
        workflowFileHasUnsavedChanges = text != workflowEditorOriginalText
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
        } catch {
            log("Workflow file save failed: \(error.localizedDescription)")
        }
    }

    func revertWorkflowFile() {
        guard let selectedWorkflowFile else {
            log("Workflow file revert skipped: no file is open.")
            return
        }

        openWorkflowFile(selectedWorkflowFile)
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
        performGodotLaunch(projectURL: lastCreatedProjectURL, source: "Post-create action")
    }

    func copyLastCreatedCodexStarterPrompt() {
        guard let lastCreatedProjectURL, let lastCreatedTemplate else {
            log("Prompt action skipped: no prompt pack is available yet.")
            return
        }

        let prompt = codexPromptPackService.starterPrompt(for: lastCreatedProjectURL, template: lastCreatedTemplate)

        switch postCreateActionService.copyPrompt(prompt.body, title: prompt.title) {
        case let .success(message):
            log(message)
        case let .failure(error):
            log("Prompt action failed: \(error.localizedDescription)")
        }
    }

    func copySelectedPrompt() {
        guard let prompt = selectedPrompt else {
            log("Prompt action skipped: no prompt pack is available yet.")
            return
        }

        switch postCreateActionService.copyPrompt(prompt.body, title: prompt.title) {
        case let .success(message):
            log(message)
        case let .failure(error):
            log("Prompt action failed: \(error.localizedDescription)")
        }
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

    func openRecentProjectInFinder(_ project: RecentProject) {
        switch postCreateActionService.openInFinder(projectURL: project.projectURL) {
        case let .success(message):
            log(message)
        case let .failure(error):
            log("Recent project action failed: \(error.localizedDescription)")
        }
    }

    func openRecentProjectInGodot(_ project: RecentProject) {
        performGodotLaunch(projectURL: project.projectURL, source: "Recent project action")
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

    private func performGodotLaunch(projectURL: URL?, source: String) {
        guard let projectURL else {
            log("\(source) skipped: no project is available yet.")
            return
        }

        switch godotLaunchService.openProject(at: projectURL, configuredExecutablePath: settings.godotExecutablePath) {
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

    private func skipReasonLike(_ messages: [String]) -> String? {
        messages.last(where: { $0.contains("skipped") || $0.contains("Skipping") })
    }

    private func performCodexHandoff(projectURL: URL, template: ProjectTemplate) {
        switch codexHandoffService.openInCodex(projectURL: projectURL, template: template) {
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
    }
}
