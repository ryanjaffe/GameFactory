import Foundation

struct GitService {
    let statusSummary = "local git integration ready"

    private let fileManager: FileManager
    private let processRunner: ProcessRunner

    init(
        fileManager: FileManager = .default,
        processRunner: ProcessRunner = ProcessRunner()
    ) {
        self.fileManager = fileManager
        self.processRunner = processRunner
    }

    func previewInitialization(at projectURL: URL) -> GitPreviewResult {
        var messages = ["Preview: checking git availability"]

        guard let gitPath = availableGitPath() else {
            messages.append("Git would be skipped: git is not installed or not on PATH.")
            return GitPreviewResult(messages: messages, willAttempt: false)
        }

        let gitDirectory = projectURL.appendingPathComponent(".git", isDirectory: true)
        guard !fileManager.fileExists(atPath: gitDirectory.path) else {
            messages.append("Git would be skipped: .git already exists at \(projectURL.path).")
            return GitPreviewResult(messages: messages, willAttempt: false)
        }

        messages.append("Git would be attempted using \(gitPath)")
        messages.append("Would run: git init")
        messages.append("Would run: git add .")
        messages.append("Would run: git commit -m \"Initial project scaffold\"")
        return GitPreviewResult(messages: messages, willAttempt: true)
    }

    func initializeRepository(at projectURL: URL) -> GitInitializationResult {
        var messages = ["Checking git availability"]

        guard let gitPath = availableGitPath() else {
            messages.append("Git is not available. Skipping repository setup.")
            messages.append("Next step: install Command Line Tools or Git, then run git init inside \(projectURL.path).")
            return GitInitializationResult(messages: messages, succeeded: false, skipped: true, repositoryReady: false)
        }

        let gitDirectory = projectURL.appendingPathComponent(".git", isDirectory: true)
        guard !fileManager.fileExists(atPath: gitDirectory.path) else {
            messages.append("Git is already initialized at \(projectURL.path). Skipping git setup.")
            return GitInitializationResult(messages: messages, succeeded: true, skipped: true, repositoryReady: true)
        }

        messages.append("Git found at \(gitPath)")
        messages.append("Initializing repository")

        do {
            let initResult = try processRunner.run(
                executableURL: URL(fileURLWithPath: gitPath),
                arguments: ["init"],
                currentDirectoryURL: projectURL
            )
            messages.append(contentsOf: formatOutput(prefix: "git init", result: initResult))

            guard initResult.exitCode == 0 else {
                messages.append("Git initialization failed.")
                return GitInitializationResult(messages: messages, succeeded: false, skipped: false, repositoryReady: false)
            }

            messages.append("Staging files")
            let addResult = try processRunner.run(
                executableURL: URL(fileURLWithPath: gitPath),
                arguments: ["add", "."],
                currentDirectoryURL: projectURL
            )
            messages.append(contentsOf: formatOutput(prefix: "git add .", result: addResult))

            guard addResult.exitCode == 0 else {
                messages.append("Git staging failed.")
                return GitInitializationResult(messages: messages, succeeded: false, skipped: false, repositoryReady: true)
            }

            messages.append("Creating initial commit")
            let commitResult = try processRunner.run(
                executableURL: URL(fileURLWithPath: gitPath),
                arguments: [
                    "-c", "user.name=Godot Game Factory",
                    "-c", "user.email=gamefactory@local.invalid",
                    "commit", "-m", "Initial project scaffold",
                ],
                currentDirectoryURL: projectURL
            )
            messages.append(contentsOf: formatOutput(prefix: "git commit", result: commitResult))

            guard commitResult.exitCode == 0 else {
                messages.append("Initial commit failed.")
                return GitInitializationResult(messages: messages, succeeded: false, skipped: false, repositoryReady: true)
            }

            messages.append("Git repository initialized successfully.")
            return GitInitializationResult(messages: messages, succeeded: true, skipped: false, repositoryReady: true)
        } catch {
            messages.append("Git setup failed with process error: \(error.localizedDescription)")
            return GitInitializationResult(messages: messages, succeeded: false, skipped: false, repositoryReady: fileManager.fileExists(atPath: gitDirectory.path))
        }
    }

    private func availableGitPath() -> String? {
        if let directPath = processRunner.which("git"), !directPath.isEmpty {
            return directPath
        }
        return nil
    }

    private func formatOutput(prefix: String, result: ProcessOutput) -> [String] {
        var messages: [String] = ["\(prefix) exit code: \(result.exitCode)"]

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
}

struct GitInitializationResult {
    let messages: [String]
    let succeeded: Bool
    let skipped: Bool
    let repositoryReady: Bool
}

struct GitPreviewResult {
    let messages: [String]
    let willAttempt: Bool
}

struct ProcessOutput {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
}

struct ProcessRunner {
    func which(_ executable: String) -> String? {
        let envPath = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for directory in envPath.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(executable)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate.path
            }
        }
        return nil
    }

    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL
    ) throws -> ProcessOutput {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return ProcessOutput(
            exitCode: process.terminationStatus,
            standardOutput: String(decoding: stdoutData, as: UTF8.self),
            standardError: String(decoding: stderrData, as: UTF8.self)
        )
    }
}
