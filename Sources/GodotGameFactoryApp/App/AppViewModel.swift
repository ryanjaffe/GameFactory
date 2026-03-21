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
    @Published private(set) var lastCreatedProjectURL: URL?
    @Published private(set) var lastCreatedTemplate: ProjectTemplate?

    private let logger: AppLogger
    private let settingsStore: AppSettingsStore
    private let generator: ProjectGenerator
    private let gitService: GitService
    private let gitHubService: GitHubService
    private let postCreateActionService: PostCreateActionService
    private var hasFinishedInitializing = false
    private var hasLoggedSaveFailure = false
    private var hasSavedSettings = false

    var hasLastCreatedProject: Bool {
        lastCreatedProjectURL != nil
    }

    var lastCreatedProjectPath: String {
        lastCreatedProjectURL?.path ?? "No project created yet."
    }

    var lastCreatedCodexStarterPrompt: String? {
        guard let lastCreatedProjectURL, let lastCreatedTemplate else {
            return nil
        }

        return postCreateActionService.starterPrompt(for: lastCreatedProjectURL, template: lastCreatedTemplate)
    }

    init(
        settingsStore: AppSettingsStore = AppSettingsStore(),
        logger: AppLogger = AppLogger(),
        generator: ProjectGenerator = ProjectGenerator(),
        gitService: GitService = GitService(),
        gitHubService: GitHubService = GitHubService(),
        postCreateActionService: PostCreateActionService = PostCreateActionService()
    ) {
        self.settingsStore = settingsStore
        self.logger = logger
        self.generator = generator
        self.gitService = gitService
        self.gitHubService = gitHubService
        self.postCreateActionService = postCreateActionService
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

            guard gitResult.succeeded else {
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
        performPostCreateAction {
            guard let lastCreatedTemplate else {
                return .failure(PostCreateActionError.missingTemplateContext)
            }
            return postCreateActionService.copyCodexStarterPrompt(projectURL: $0, template: lastCreatedTemplate)
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
}
