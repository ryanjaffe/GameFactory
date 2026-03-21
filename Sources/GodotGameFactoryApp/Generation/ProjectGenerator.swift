import Foundation

struct ProjectGenerator {
    let statusSummary = "local scaffold generation ready"

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func buildProjectPlan(using settings: AppSettings) throws -> ProjectPlan {
        let projectName = settings.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseDirectory = settings.baseDirectory.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !projectName.isEmpty else {
            throw ProjectGenerationError.invalidProjectName
        }

        guard !baseDirectory.isEmpty else {
            throw ProjectGenerationError.invalidBaseDirectory
        }

        let expandedBaseDirectory = NSString(string: baseDirectory).expandingTildeInPath
        let baseURL = URL(fileURLWithPath: expandedBaseDirectory, isDirectory: true)
        let requestedURL = baseURL.appendingPathComponent(projectName, isDirectory: true)
        let finalURL = availableProjectURL(for: requestedURL)
        let usedSuffixedFolder = finalURL.path != requestedURL.path
        let directories = ["scenes", "scripts", "art", "tests", "artifacts"].map {
            finalURL.appendingPathComponent($0, isDirectory: true)
        }
        let files = starterFiles(for: settings, projectURL: finalURL)

        return ProjectPlan(
            requestedProjectURL: requestedURL,
            finalProjectURL: finalURL,
            usedSuffixedFolder: usedSuffixedFolder,
            directoriesToCreate: directories,
            filesToCreate: files.map { PlannedFile(url: $0.url, contents: $0.contents, isExecutable: $0.isExecutable) }
        )
    }

    func generateProject(using settings: AppSettings) throws -> ProjectGenerationResult {
        let plan = try buildProjectPlan(using: settings)
        let requestedURL = plan.requestedProjectURL
        let finalURL = plan.finalProjectURL

        var messages: [String] = []
        if finalURL.path == requestedURL.path {
            messages.append("Target folder available: \(finalURL.path)")
        } else {
            messages.append("Target folder already exists: \(requestedURL.lastPathComponent)")
            messages.append("Using non-destructive folder name: \(finalURL.lastPathComponent)")
        }

        try fileManager.createDirectory(at: finalURL, withIntermediateDirectories: true)
        messages.append("Created project root: \(finalURL.path)")

        var createdDirectories: [URL] = [finalURL]

        for directoryURL in plan.directoriesToCreate {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            createdDirectories.append(directoryURL)
            messages.append("Created folder: \(directoryURL.lastPathComponent)/")
        }

        var createdFiles: [URL] = []

        for file in plan.filesToCreate {
            try file.contents.write(to: file.url, atomically: true, encoding: .utf8)
            if file.isExecutable {
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.url.path)
            }
            createdFiles.append(file.url)
            messages.append("Created file: \(file.url.lastPathComponent)")
        }

        messages.append("Project scaffold complete: \(finalURL.path)")

        return ProjectGenerationResult(
            finalProjectURL: finalURL,
            createdDirectories: createdDirectories,
            createdFiles: createdFiles,
            messages: messages
        )
    }

    private func availableProjectURL(for requestedURL: URL) -> URL {
        guard fileManager.fileExists(atPath: requestedURL.path) else {
            return requestedURL
        }

        let parentDirectory = requestedURL.deletingLastPathComponent()
        let baseName = requestedURL.lastPathComponent
        var suffix = 2

        while true {
            let candidate = parentDirectory.appendingPathComponent("\(baseName)-\(suffix)", isDirectory: true)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }

    private func starterFiles(for settings: AppSettings, projectURL: URL) -> [(url: URL, contents: String, isExecutable: Bool)] {
        let projectName = settings.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let gitHubUsername = settings.gitHubUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        var files = [
            (projectURL.appendingPathComponent("README.md"), readmeContents(projectName: projectName, template: settings.template)),
            (projectURL.appendingPathComponent(".gitignore"), gitignoreContents()),
            (
                projectURL.appendingPathComponent("AGENTS.md"),
                agentsContents(
                    projectName: projectName,
                    gitHubUsername: gitHubUsername,
                    repoVisibility: settings.repoVisibility,
                    template: settings.template
                )
            ),
            (
                projectURL.appendingPathComponent("run_validation.sh"),
                runValidationScriptContents(template: settings.template)
            ),
            (projectURL.appendingPathComponent("project.godot"), projectFileContents(projectName: projectName)),
        ]

        files.append(contentsOf: ProjectTemplateSupport.additionalFiles(for: settings.template, projectURL: projectURL))
        return files.map { url, contents in
            let isExecutable = url.lastPathComponent == "run_validation.sh"
            return (url: url, contents: contents, isExecutable: isExecutable)
        }
    }

    private func readmeContents(projectName: String, template: ProjectTemplate) -> String {
        let templateNotes = ProjectTemplateSupport.readmeNotes(for: template)
            .map { "- \($0)" }
            .joined(separator: "\n")

        return """
        # \(projectName)

        This project was generated by Godot Game Factory.

        ## Structure

        - `scenes/` for Godot scenes
        - `scripts/` for gameplay and utility scripts
        - `art/` for source art assets
        - `tests/` for validation and test helpers
        - `artifacts/` for generated outputs and exports

        ## Notes

        - `project.godot` is a starter placeholder. Open the project in Godot to finalize engine-managed settings.
        - Review `AGENTS.md` before using Codex in this project.
        - Run `./run_validation.sh` after small changes and store output in `artifacts/`.
        \(templateNotes.isEmpty ? "" : "\n## Template Notes\n\n\(templateNotes)")
        """
    }

    private func gitignoreContents() -> String {
        """
        .DS_Store
        .godot/
        .import/
        export_presets.cfg
        artifacts/
        """
    }

    private func agentsContents(
        projectName: String,
        gitHubUsername: String,
        repoVisibility: RepoVisibility,
        template: ProjectTemplate
    ) -> String {
        let usernameLine = gitHubUsername.isEmpty ? "- GitHub username is not configured yet" : "- Preferred GitHub username: \(gitHubUsername)"
        let validationTarget = ProjectTemplateSupport.validationTarget(for: template) ?? "no starter scene is configured yet"
        let validationNotes = ProjectTemplateSupport.validationNotesFilename(for: template)

        return """
        ## Purpose

        This repository contains the Godot project `\(projectName)`.

        Agents should optimize for:
        - small, safe changes
        - Godot-friendly file organization
        - readable scenes and scripts
        - clear validation steps

        ## Workflow

        - Start with the smallest useful change.
        - Make small changes only.
        - Avoid renaming or moving files unless necessary.
        - Prefer edits in `scenes/` and `scripts/` over broad refactors.
        - Validate after changes with `./run_validation.sh`.
        - Use `artifacts/` for validation logs, notes, or command output.
        - Document any Godot editor steps required to complete a change.

        ## Project Setup

        - Template: \(template.rawValue)
        - Repository visibility preference: \(repoVisibility.rawValue)
        \(usernameLine)

        ## File Guide

        - `scenes/` contains `.tscn` scene files.
        - `scripts/` contains GDScript or support code.
        - `art/` contains project art assets.
        - `tests/` contains test or validation helpers.
        - `artifacts/` contains generated outputs that should usually stay local.
        - `run_validation.sh` is the starter validation entrypoint.
        - `\(validationNotes)` contains template-aware validation notes.

        ## Safety

        - Do not overwrite user-authored scenes or scripts without checking.
        - Do not delete assets or project folders by default.
        - Surface Godot, git, or tool failures clearly.
        - Respect the generated project structure unless there is a strong reason to change it.

        ## Validation Focus

        - Starter validation target: \(validationTarget)
        - If you add logs or reports, write them to `artifacts/`.
        """
    }

    private func runValidationScriptContents(template: ProjectTemplate) -> String {
        let validationTarget = ProjectTemplateSupport.validationTarget(for: template)
        let templateLine = "Template: \(template.rawValue)"
        let targetLine = validationTarget.map { "Starter target: \($0)" } ?? "Starter target: none configured yet"
        let sceneCheck = validationTarget.map {
            """
            if [[ -f "\($0)" ]]; then
              echo "[validation] Starter scene present: \($0)"
            else
              echo "[validation] Starter scene not found yet: \($0)"
            fi
            """
        } ?? """
        echo "[validation] No starter scene configured for this template yet."
        """

        return """
        #!/bin/zsh
        set -euo pipefail

        mkdir -p artifacts

        echo "[validation] Starting starter validation"
        echo "[validation] \(templateLine)"
        echo "[validation] \(targetLine)"
        echo "[validation] This is a lightweight editable starter script."
        echo "[validation] Write follow-up notes or logs to artifacts/."

        if [[ -f "project.godot" ]]; then
          echo "[validation] project.godot found"
        else
          echo "[validation] project.godot missing"
        fi

        \(sceneCheck)

        echo "[validation] Starter validation complete"
        """
    }

    private func projectFileContents(projectName: String) -> String {
        """
        ; Minimal placeholder generated by Godot Game Factory.
        ; Open this folder in Godot to let the editor finalize project settings.

        config_version=5

        [application]

        config/name="\(projectName)"
        """
    }
}

struct ProjectPlan {
    let requestedProjectURL: URL
    let finalProjectURL: URL
    let usedSuffixedFolder: Bool
    let directoriesToCreate: [URL]
    let filesToCreate: [PlannedFile]
}

struct PlannedFile {
    let url: URL
    let contents: String
    let isExecutable: Bool
}

struct ProjectGenerationResult {
    let finalProjectURL: URL
    let createdDirectories: [URL]
    let createdFiles: [URL]
    let messages: [String]
}

enum ProjectGenerationError: LocalizedError {
    case invalidProjectName
    case invalidBaseDirectory

    var errorDescription: String? {
        switch self {
        case .invalidProjectName:
            return "Project name is required."
        case .invalidBaseDirectory:
            return "Base directory is required."
        }
    }
}
