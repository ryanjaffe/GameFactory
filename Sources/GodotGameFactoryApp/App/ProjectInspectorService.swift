import Foundation

struct ProjectInspectorService {
    private let fileManager: FileManager
    private let processRunner: ProcessRunner

    init(
        fileManager: FileManager = .default,
        processRunner: ProcessRunner = ProcessRunner()
    ) {
        self.fileManager = fileManager
        self.processRunner = processRunner
    }

    func inspectProject(at projectURL: URL) -> InspectedProjectSummary {
        let rootFiles = existingRootFiles(in: projectURL)
        let nestedFiles = existingNestedFiles(in: projectURL)
        let detectedTemplate = detectTemplate(in: projectURL, rootFiles: rootFiles, nestedFiles: nestedFiles)

        return InspectedProjectSummary(
            projectURL: projectURL,
            projectName: projectURL.lastPathComponent,
            detectedTemplate: detectedTemplate,
            hasProjectGodot: fileManager.fileExists(atPath: projectURL.appendingPathComponent("project.godot").path),
            hasAgentsFile: fileManager.fileExists(atPath: projectURL.appendingPathComponent("AGENTS.md").path),
            hasReadmeFile: fileManager.fileExists(atPath: projectURL.appendingPathComponent("README.md").path),
            hasValidationScript: fileManager.fileExists(atPath: projectURL.appendingPathComponent("run_validation.sh").path),
            hasGitDirectory: fileManager.fileExists(atPath: projectURL.appendingPathComponent(".git", isDirectory: true).path),
            originRemoteStatus: originRemoteStatus(for: projectURL),
            hasScenesDirectory: fileManager.fileExists(atPath: projectURL.appendingPathComponent("scenes", isDirectory: true).path),
            hasScriptsDirectory: fileManager.fileExists(atPath: projectURL.appendingPathComponent("scripts", isDirectory: true).path),
            hasArtDirectory: fileManager.fileExists(atPath: projectURL.appendingPathComponent("art", isDirectory: true).path),
            hasTestsDirectory: fileManager.fileExists(atPath: projectURL.appendingPathComponent("tests", isDirectory: true).path),
            hasArtifactsDirectory: fileManager.fileExists(atPath: projectURL.appendingPathComponent("artifacts", isDirectory: true).path),
            rootFiles: rootFiles,
            nestedFiles: nestedFiles
        )
    }

    private func detectTemplate(in projectURL: URL, rootFiles: [String], nestedFiles: [String]) -> ProjectTemplate? {
        let agentsURL = projectURL.appendingPathComponent("AGENTS.md")
        if let agentsContents = try? String(contentsOf: agentsURL, encoding: .utf8) {
            if let matchedTemplate = ProjectTemplate.allCases.first(where: { agentsContents.contains($0.rawValue) }) {
                return matchedTemplate
            }
        }

        let markers: [(ProjectTemplate, [String])] = [
            (.platformerStarter, ["scripts/platformer_player.gd", "scenes/platformer_playground.tscn"]),
            (.topDownStarter, ["scripts/top_down_player.gd", "scenes/top_down_playground.tscn"]),
            (.starter3D, ["scripts/player_controller_3d.gd", "scenes/starter_3d_playground.tscn"]),
            (.dialogueNarrativeStarter, ["scripts/dialogue_controller.gd", "scenes/dialogue_playground.tscn"]),
            (.blank, ["tests/validation_notes.md"]),
        ]

        for (template, requiredFiles) in markers {
            if requiredFiles.allSatisfy({ nestedFiles.contains($0) }) {
                return template
            }
        }

        return nil
    }

    private func originRemoteStatus(for projectURL: URL) -> OriginRemoteStatus {
        let gitDirectory = projectURL.appendingPathComponent(".git", isDirectory: true)
        guard fileManager.fileExists(atPath: gitDirectory.path) else {
            return .absent
        }

        guard let gitPath = processRunner.which("git") else {
            return .unknown("git unavailable")
        }

        do {
            let result = try processRunner.run(
                executableURL: URL(fileURLWithPath: gitPath),
                arguments: ["remote", "get-url", "origin"],
                currentDirectoryURL: projectURL
            )

            if result.exitCode == 0 {
                let remoteURL = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                return remoteURL.isEmpty ? .absent : .present(remoteURL)
            }

            return .absent
        } catch {
            return .unknown("git check failed")
        }
    }

    private func existingRootFiles(in projectURL: URL) -> [String] {
        [
            "project.godot",
            "AGENTS.md",
            "README.md",
            "run_validation.sh",
            ".gitignore",
            ".git",
        ].filter {
            fileManager.fileExists(atPath: projectURL.appendingPathComponent($0).path)
        }
    }

    private func existingNestedFiles(in projectURL: URL) -> [String] {
        let candidatePaths = [
            "scenes/platformer_playground.tscn",
            "scenes/top_down_playground.tscn",
            "scenes/starter_3d_playground.tscn",
            "scenes/dialogue_playground.tscn",
            "scripts/platformer_player.gd",
            "scripts/top_down_player.gd",
            "scripts/player_controller_3d.gd",
            "scripts/dialogue_controller.gd",
            "tests/validation_notes.md",
            "tests/platformer_starter_notes.md",
            "tests/top_down_starter_notes.md",
            "tests/starter_3d_notes.md",
            "tests/dialogue_outline.txt",
            "tests/dialogue_starter_notes.md",
            "artifacts/validation.log",
        ]

        return candidatePaths.filter {
            fileManager.fileExists(atPath: projectURL.appendingPathComponent($0).path)
        }
    }
}
