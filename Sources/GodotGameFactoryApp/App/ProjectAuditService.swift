import Foundation

struct ProjectAuditService {
    private let fileManager: FileManager
    private let inspectorService: ProjectInspectorService

    init(
        fileManager: FileManager = .default,
        inspectorService: ProjectInspectorService = ProjectInspectorService()
    ) {
        self.fileManager = fileManager
        self.inspectorService = inspectorService
    }

    func runAudit(projectURL: URL, template: ProjectTemplate?) -> ProjectAuditSummary {
        let inspectedSummary = inspectorService.inspectProject(at: projectURL)
        let expectedTemplate = template ?? inspectedSummary.detectedTemplate
        let validationScriptURL = projectURL.appendingPathComponent("run_validation.sh")

        var checks: [ProjectAuditCheck] = [
            fileCheck(
                id: "project-godot",
                title: "project.godot",
                exists: inspectedSummary.hasProjectGodot,
                failureDetail: "`project.godot` is missing."
            ),
            fileCheck(
                id: "agents",
                title: "AGENTS.md",
                exists: inspectedSummary.hasAgentsFile,
                failureDetail: "`AGENTS.md` is missing."
            ),
            fileCheck(
                id: "readme",
                title: "README.md",
                exists: inspectedSummary.hasReadmeFile,
                failureDetail: "`README.md` is missing."
            ),
            fileCheck(
                id: "validation-script",
                title: "run_validation.sh",
                exists: inspectedSummary.hasValidationScript,
                failureDetail: "`run_validation.sh` is missing."
            ),
            executableCheck(scriptURL: validationScriptURL, scriptExists: inspectedSummary.hasValidationScript),
            directoryCheck(id: "scenes", title: "scenes/", exists: inspectedSummary.hasScenesDirectory),
            directoryCheck(id: "scripts", title: "scripts/", exists: inspectedSummary.hasScriptsDirectory),
            directoryCheck(id: "art", title: "art/", exists: inspectedSummary.hasArtDirectory),
            directoryCheck(id: "tests", title: "tests/", exists: inspectedSummary.hasTestsDirectory),
            artifactsCheck(exists: inspectedSummary.hasArtifactsDirectory),
            gitDirectoryCheck(exists: inspectedSummary.hasGitDirectory),
            originCheck(originStatus: inspectedSummary.originRemoteStatus),
            templateStarterCheck(projectURL: projectURL, template: expectedTemplate),
        ]

        checks.append(
            ProjectAuditCheck(
                id: "template-detected",
                title: "Template Detection",
                status: expectedTemplate == nil ? .skipped : .pass,
                detail: expectedTemplate?.rawValue ?? "Template is unknown. Template-specific checks were skipped."
            )
        )

        return ProjectAuditSummary(
            projectURL: projectURL,
            projectName: projectURL.lastPathComponent,
            template: expectedTemplate,
            checks: checks
        )
    }

    private func fileCheck(id: String, title: String, exists: Bool, failureDetail: String) -> ProjectAuditCheck {
        ProjectAuditCheck(
            id: id,
            title: title,
            status: exists ? .pass : .fail,
            detail: exists ? "\(title) is present." : failureDetail
        )
    }

    private func executableCheck(scriptURL: URL, scriptExists: Bool) -> ProjectAuditCheck {
        guard scriptExists else {
            return ProjectAuditCheck(
                id: "validation-executable",
                title: "run_validation.sh Executable",
                status: .skipped,
                detail: "Skipped because `run_validation.sh` is missing."
            )
        }

        let isExecutable = fileManager.isExecutableFile(atPath: scriptURL.path)
        return ProjectAuditCheck(
            id: "validation-executable",
            title: "run_validation.sh Executable",
            status: isExecutable ? .pass : .warn,
            detail: isExecutable ? "`run_validation.sh` is executable." : "`run_validation.sh` exists but is not executable."
        )
    }

    private func directoryCheck(id: String, title: String, exists: Bool) -> ProjectAuditCheck {
        ProjectAuditCheck(
            id: id,
            title: title,
            status: exists ? .pass : .warn,
            detail: exists ? "\(title) exists." : "\(title) is missing."
        )
    }

    private func artifactsCheck(exists: Bool) -> ProjectAuditCheck {
        ProjectAuditCheck(
            id: "artifacts",
            title: "artifacts/",
            status: exists ? .pass : .warn,
            detail: exists ? "`artifacts/` exists." : "`artifacts/` is missing. It is expected for logs and validation output."
        )
    }

    private func gitDirectoryCheck(exists: Bool) -> ProjectAuditCheck {
        ProjectAuditCheck(
            id: "git-directory",
            title: ".git",
            status: exists ? .pass : .warn,
            detail: exists ? "Git repository is present." : "Git repository is missing."
        )
    }

    private func originCheck(originStatus: OriginRemoteStatus) -> ProjectAuditCheck {
        switch originStatus {
        case let .present(remoteURL):
            return ProjectAuditCheck(
                id: "origin-remote",
                title: "Origin Remote",
                status: .pass,
                detail: "Origin remote is configured: \(remoteURL)"
            )
        case .absent:
            return ProjectAuditCheck(
                id: "origin-remote",
                title: "Origin Remote",
                status: .warn,
                detail: "Origin remote is not configured."
            )
        case let .unknown(reason):
            return ProjectAuditCheck(
                id: "origin-remote",
                title: "Origin Remote",
                status: .skipped,
                detail: "Origin status could not be checked: \(reason)"
            )
        }
    }

    private func templateStarterCheck(projectURL: URL, template: ProjectTemplate?) -> ProjectAuditCheck {
        guard let template else {
            return ProjectAuditCheck(
                id: "template-starters",
                title: "Template Starter Files",
                status: .skipped,
                detail: "Template is unknown, so template-specific file checks were skipped."
            )
        }

        let starterFiles = templateStarterPaths(for: template)
        guard !starterFiles.isEmpty else {
            return ProjectAuditCheck(
                id: "template-starters",
                title: "Template Starter Files",
                status: .skipped,
                detail: "No template-specific starter files are defined for this template."
            )
        }

        let missingFiles = starterFiles.filter {
            !fileManager.fileExists(atPath: projectURL.appendingPathComponent($0).path)
        }

        return ProjectAuditCheck(
            id: "template-starters",
            title: "Template Starter Files",
            status: missingFiles.isEmpty ? .pass : .warn,
            detail: missingFiles.isEmpty
                ? "Template-specific starter files are present."
                : "Missing template-specific files: \(missingFiles.joined(separator: ", "))"
        )
    }

    private func templateStarterPaths(for template: ProjectTemplate) -> [String] {
        switch template {
        case .blank:
            return ["tests/validation_notes.md"]
        case .platformerStarter:
            return ["scenes/platformer_playground.tscn", "scripts/platformer_player.gd", "tests/platformer_starter_notes.md"]
        case .topDownStarter:
            return ["scenes/top_down_playground.tscn", "scripts/top_down_player.gd", "tests/top_down_starter_notes.md"]
        case .starter3D:
            return ["scenes/starter_3d_playground.tscn", "scripts/player_controller_3d.gd", "tests/starter_3d_notes.md"]
        case .dialogueNarrativeStarter:
            return ["scenes/dialogue_playground.tscn", "scripts/dialogue_controller.gd", "tests/dialogue_outline.txt", "tests/dialogue_starter_notes.md"]
        }
    }
}
