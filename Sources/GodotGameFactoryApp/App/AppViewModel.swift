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

    var activeHandoffBundleText: String? {
        buildHandoffBundleText()
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

        if pendingWorkflowFileRepairConfirmation == selectedWorkflowFile {
            return "Confirm Restore Default"
        }

        return "Restore Default"
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
        workflowSettingsService: ProjectWorkflowSettingsService = ProjectWorkflowSettingsService()
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
        self.settings = settingsStore.load()
        self.presets = presetStore.load()
        self.recentProjects = recentProjectsStore.load()
        self.assetStarterPacks = assetStarterPackService.availablePacks()
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
        } catch {
            log("Workflow file save failed: \(error.localizedDescription)")
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
        } catch {
            log("Asset import failed: \(error.localizedDescription)")
        }
    }

    func applyAssetStarterPack(_ pack: AssetStarterPack) {
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
        } catch {
            log("Asset starter pack failed: \(error.localizedDescription)")
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
        case let .failure(error):
            log("Handoff bundle failed: \(error.localizedDescription)")
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
        } catch {
            pendingWorkflowFileRepairConfirmation = nil
            log("Workflow file repair failed: \(error.localizedDescription)")
        }
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
        case let .failure(error):
            log("Prompt action failed: \(error.localizedDescription)")
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

        let input = HandoffBundleInput(
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

        return handoffBundleService.buildBundle(from: input)
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
