import Foundation

struct GitHubService {
    let statusSummary = "optional GitHub integration ready"

    private let fileManager: FileManager
    private let processRunner: ProcessRunner

    init(
        fileManager: FileManager = .default,
        processRunner: ProcessRunner = ProcessRunner()
    ) {
        self.fileManager = fileManager
        self.processRunner = processRunner
    }

    func previewConnection(
        at projectURL: URL,
        projectName: String,
        gitHubUsername: String,
        visibility: RepoVisibility,
        localGitWillBeReady: Bool
    ) -> GitHubPreviewResult {
        let trimmedUsername = gitHubUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        var messages = ["Preview: checking GitHub username"]

        guard !trimmedUsername.isEmpty else {
            messages.append("GitHub would be skipped: no GitHub username was provided.")
            return GitHubPreviewResult(messages: messages, willAttempt: false)
        }

        guard localGitWillBeReady else {
            messages.append("GitHub would be skipped: local Git setup would not run successfully.")
            return GitHubPreviewResult(messages: messages, willAttempt: false)
        }

        guard let ghPath = processRunner.which("gh") else {
            messages.append("GitHub would be skipped: GitHub CLI is not installed or not on PATH.")
            return GitHubPreviewResult(messages: messages, willAttempt: false)
        }

        let gitDirectory = projectURL.appendingPathComponent(".git", isDirectory: true)
        if fileManager.fileExists(atPath: gitDirectory.path),
           let existingOrigin = existingOriginURL(in: projectURL) {
            messages.append("GitHub would be skipped: origin already exists at \(existingOrigin).")
            return GitHubPreviewResult(messages: messages, willAttempt: false)
        }

        let repositoryName = "\(trimmedUsername)/\(projectName)"
        let visibilityDescription = visibility == .publicRepo ? "public" : "private"

        messages.append("GitHub would be attempted using \(ghPath)")
        messages.append("Would create repository: \(repositoryName) (\(visibilityDescription))")
        messages.append("Would configure remote: origin")
        messages.append("Would push initial commit with: git push -u origin HEAD")
        messages.append("Dry run does not check gh authentication.")
        return GitHubPreviewResult(messages: messages, willAttempt: true)
    }

    func connectRepository(
        at projectURL: URL,
        projectName: String,
        gitHubUsername: String,
        visibility: RepoVisibility
    ) -> GitHubSetupResult {
        let trimmedUsername = gitHubUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        var messages = ["Checking GitHub username"]

        guard !trimmedUsername.isEmpty else {
            messages.append("GitHub setup skipped: no GitHub username was provided.")
            return GitHubSetupResult(messages: messages, succeeded: false, skipped: true)
        }

        messages.append("Checking gh availability")
        guard let ghPath = processRunner.which("gh") else {
            messages.append("GitHub CLI is not available. Skipping GitHub setup.")
            messages.append("Next step: install GitHub CLI and run gh auth login, then create or connect a remote manually.")
            return GitHubSetupResult(messages: messages, succeeded: false, skipped: true)
        }

        guard fileManager.fileExists(atPath: projectURL.appendingPathComponent(".git").path) else {
            messages.append("GitHub setup skipped: local Git repository is not available at \(projectURL.path).")
            return GitHubSetupResult(messages: messages, succeeded: false, skipped: true)
        }

        let gitPath = processRunner.which("git")
        guard let gitPath else {
            messages.append("GitHub setup skipped: git is not available for remote inspection or push.")
            return GitHubSetupResult(messages: messages, succeeded: false, skipped: true)
        }

        messages.append("Checking gh authentication")
        do {
            let authResult = try processRunner.run(
                executableURL: URL(fileURLWithPath: ghPath),
                arguments: ["auth", "status"],
                currentDirectoryURL: projectURL
            )
            messages.append(contentsOf: formatOutput(prefix: "gh auth status", result: authResult))

            guard authResult.exitCode == 0 else {
                messages.append("GitHub CLI is installed but not authenticated. Skipping GitHub setup.")
                messages.append("Next step: run gh auth login and try again.")
                return GitHubSetupResult(messages: messages, succeeded: false, skipped: true)
            }

            let originResult = try processRunner.run(
                executableURL: URL(fileURLWithPath: gitPath),
                arguments: ["remote", "get-url", "origin"],
                currentDirectoryURL: projectURL
            )

            if originResult.exitCode == 0 {
                messages.append("Origin remote already exists: \(originResult.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines))")
                messages.append("GitHub setup skipped to avoid replacing the existing origin remote.")
                return GitHubSetupResult(messages: messages, succeeded: true, skipped: true)
            }

            let repositoryName = "\(trimmedUsername)/\(projectName)"
            let visibilityFlag = visibility == .publicRepo ? "--public" : "--private"

            messages.append("Creating GitHub repository")
            let createResult = try processRunner.run(
                executableURL: URL(fileURLWithPath: ghPath),
                arguments: [
                    "repo", "create", repositoryName,
                    visibilityFlag,
                    "--source", ".",
                    "--remote", "origin",
                ],
                currentDirectoryURL: projectURL
            )
            messages.append(contentsOf: formatOutput(prefix: "gh repo create", result: createResult))

            guard createResult.exitCode == 0 else {
                messages.append("GitHub repository creation failed.")
                return GitHubSetupResult(messages: messages, succeeded: false, skipped: false)
            }

            messages.append("Configuring remote")
            let originCheckResult = try processRunner.run(
                executableURL: URL(fileURLWithPath: gitPath),
                arguments: ["remote", "get-url", "origin"],
                currentDirectoryURL: projectURL
            )
            messages.append(contentsOf: formatOutput(prefix: "git remote get-url origin", result: originCheckResult))

            guard originCheckResult.exitCode == 0 else {
                messages.append("Origin remote was not configured as expected after repository creation.")
                return GitHubSetupResult(messages: messages, succeeded: false, skipped: false)
            }

            messages.append("Pushing initial commit")
            let pushResult = try processRunner.run(
                executableURL: URL(fileURLWithPath: gitPath),
                arguments: ["push", "-u", "origin", "HEAD"],
                currentDirectoryURL: projectURL
            )
            messages.append(contentsOf: formatOutput(prefix: "git push -u origin HEAD", result: pushResult))

            guard pushResult.exitCode == 0 else {
                messages.append("GitHub repository was created, but pushing the initial commit failed.")
                return GitHubSetupResult(messages: messages, succeeded: false, skipped: false)
            }

            messages.append("GitHub repository connected successfully.")
            return GitHubSetupResult(messages: messages, succeeded: true, skipped: false)
        } catch {
            messages.append("GitHub setup failed with process error: \(error.localizedDescription)")
            return GitHubSetupResult(messages: messages, succeeded: false, skipped: false)
        }
    }

    private func formatOutput(prefix: String, result: ProcessOutput) -> [String] {
        var messages = ["\(prefix) exit code: \(result.exitCode)"]

        let stdout = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stdout.isEmpty {
            messages.append("\(prefix) stdout: \(stdout)")
        }

        let stderr = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty {
            messages.append("\(prefix) stderr: \(stderr)")
        }

        return messages
    }

    private func existingOriginURL(in projectURL: URL) -> String? {
        let configURL = projectURL.appendingPathComponent(".git/config")
        guard let configContents = try? String(contentsOf: configURL, encoding: .utf8) else {
            return nil
        }

        let lines = configContents.components(separatedBy: .newlines)
        var inOriginSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "[remote \"origin\"]" {
                inOriginSection = true
                continue
            }

            if trimmed.hasPrefix("[") {
                inOriginSection = false
            }

            if inOriginSection, trimmed.hasPrefix("url = ") {
                return String(trimmed.dropFirst("url = ".count))
            }
        }

        return nil
    }
}

struct GitHubSetupResult {
    let messages: [String]
    let succeeded: Bool
    let skipped: Bool
}

struct GitHubPreviewResult {
    let messages: [String]
    let willAttempt: Bool
}
