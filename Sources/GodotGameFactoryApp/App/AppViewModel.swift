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
    @Published var selectedPromptKind: CodexPromptKind = .starter
    @Published private(set) var lastCreatedProjectURL: URL?
    @Published private(set) var lastCreatedTemplate: ProjectTemplate?
    @Published private(set) var lastCreatedSummary: ProjectCreationSummary?

    private let logger: AppLogger
    private let settingsStore: AppSettingsStore
    private let generator: ProjectGenerator
    private let gitService: GitService
    private let gitHubService: GitHubService
    private let postCreateActionService: PostCreateActionService
    private let codexPromptPackService: CodexPromptPackService
    private let folderPickerService: FolderPickerService
    private var hasFinishedInitializing = false
    private var hasLoggedSaveFailure = false
    private var hasSavedSettings = false

    var hasLastCreatedProject: Bool {
        lastCreatedProjectURL != nil
    }

    var hasProjectSummary: Bool {
        lastCreatedSummary != nil
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

    var selectedPrompt: CodexPrompt? {
        availablePromptPack.first(where: { $0.kind == selectedPromptKind }) ?? availablePromptPack.first
    }

    init(
        settingsStore: AppSettingsStore = AppSettingsStore(),
        logger: AppLogger = AppLogger(),
        generator: ProjectGenerator = ProjectGenerator(),
        gitService: GitService = GitService(),
        gitHubService: GitHubService = GitHubService(),
        postCreateActionService: PostCreateActionService = PostCreateActionService(),
        codexPromptPackService: CodexPromptPackService = CodexPromptPackService(),
        folderPickerService: FolderPickerService = FolderPickerService()
    ) {
        self.settingsStore = settingsStore
        self.logger = logger
        self.generator = generator
        self.gitService = gitService
        self.gitHubService = gitHubService
        self.postCreateActionService = postCreateActionService
        self.codexPromptPackService = codexPromptPackService
        self.folderPickerService = folderPickerService
        self.settings = settingsStore.load()
        self.logEntries = logger.entries

        log("App initialized")
        log(self.settings == AppSettings.default ? "Using default settings" : "Loaded saved settings")
        log("Generator service ready: \(generator.statusSummary)")
        log("Git service ready: \(gitService.statusSummary)")
        log("GitHub service ready: \(gitHubService.statusSummary)")
        log("New Project form ready")
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

    func copyLastCreatedCodexStarterPrompt() {
        guard let prompt = prompt(for: .starter) else {
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
}
