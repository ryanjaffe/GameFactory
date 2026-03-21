import Foundation

struct GodotLaunchService {
    private let fileManager: FileManager
    private let processRunner: ProcessRunner
    private let openProjectAction: ((URL, String, String) -> Result<String, Error>)?

    init(
        fileManager: FileManager = .default,
        processRunner: ProcessRunner = ProcessRunner()
    ) {
        self.fileManager = fileManager
        self.processRunner = processRunner
        self.openProjectAction = nil
    }

    init(openProjectAction: @escaping (URL, String, String) -> Result<String, Error>) {
        self.fileManager = .default
        self.processRunner = ProcessRunner()
        self.openProjectAction = openProjectAction
    }

    func openProject(
        at projectURL: URL,
        projectOverridePath: String,
        configuredExecutablePath: String
    ) -> Result<String, Error> {
        if let openProjectAction {
            return openProjectAction(projectURL, projectOverridePath, configuredExecutablePath)
        }

        let command = launchCommand(
            for: projectURL,
            projectOverridePath: projectOverridePath,
            configuredExecutablePath: configuredExecutablePath
        )

        switch command {
        case let .success(resolvedCommand):
            do {
                let result = try processRunner.run(
                    executableURL: URL(fileURLWithPath: resolvedCommand.executablePath),
                    arguments: resolvedCommand.arguments,
                    currentDirectoryURL: projectURL
                )

                guard result.exitCode == 0 else {
                    let details = [result.standardOutput, result.standardError]
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return .failure(GodotLaunchError.commandFailed(command: resolvedCommand.displayName, details: details))
                }

                return .success("Opened project in Godot.")
            } catch {
                return .failure(error)
            }
        case let .failure(error):
            return .failure(error)
        }
    }

    func launchCommand(
        for projectURL: URL,
        projectOverridePath: String,
        configuredExecutablePath: String
    ) -> Result<GodotLaunchCommand, GodotLaunchError> {
        let trimmedPath = resolvedExecutablePath(
            projectOverridePath: projectOverridePath,
            configuredExecutablePath: configuredExecutablePath
        )

        if !trimmedPath.isEmpty {
            let configuredURL = URL(fileURLWithPath: NSString(string: trimmedPath).expandingTildeInPath)

            guard fileManager.fileExists(atPath: configuredURL.path) else {
                return .failure(.configuredPathMissing(configuredURL.path))
            }

            if configuredURL.pathExtension == "app" {
                return .success(
                    GodotLaunchCommand(
                        executablePath: "/usr/bin/open",
                        arguments: ["-a", configuredURL.path, projectURL.path],
                        displayName: "open -a \(configuredURL.lastPathComponent)"
                    )
                )
            }

            guard fileManager.isExecutableFile(atPath: configuredURL.path) else {
                return .failure(.configuredPathMissing(configuredURL.path))
            }

            return .success(
                GodotLaunchCommand(
                    executablePath: configuredURL.path,
                    arguments: ["--path", projectURL.path],
                    displayName: configuredURL.lastPathComponent
                )
            )
        }

        let fallback = GodotLaunchCommand(
            executablePath: "/usr/bin/open",
            arguments: ["-a", "Godot", projectURL.path],
            displayName: "open -a Godot"
        )

        return .success(fallback)
    }

    func resolvedExecutablePath(projectOverridePath: String, configuredExecutablePath: String) -> String {
        let trimmedProjectOverride = projectOverridePath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedProjectOverride.isEmpty {
            return trimmedProjectOverride
        }

        return configuredExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct GodotLaunchCommand: Equatable {
    let executablePath: String
    let arguments: [String]
    let displayName: String
}

enum GodotLaunchError: LocalizedError, Equatable {
    case configuredPathMissing(String)
    case commandFailed(command: String, details: String)

    var errorDescription: String? {
        switch self {
        case let .configuredPathMissing(path):
            return "Godot path was not found at \(path). Update the setting or leave it blank to use automatic launch."
        case let .commandFailed(command, details):
            let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedDetails.contains("Unable to find application named") || trimmedDetails.contains("Application isn’t running") {
                return "Godot could not be found. Set a Godot path or install the app so automatic launch can find it."
            }
            return trimmedDetails.isEmpty ? "\(command) failed." : "\(command) failed: \(trimmedDetails)"
        }
    }
}
