import AppKit
import Foundation

struct PostCreateActionService {
    private let workspace: NSWorkspace
    private let pasteboard: NSPasteboard
    private let processRunner: ProcessRunner

    init(
        workspace: NSWorkspace = .shared,
        pasteboard: NSPasteboard = .general,
        processRunner: ProcessRunner = ProcessRunner()
    ) {
        self.workspace = workspace
        self.pasteboard = pasteboard
        self.processRunner = processRunner
    }

    func openInFinder(projectURL: URL) -> Result<String, Error> {
        workspace.activateFileViewerSelecting([projectURL])
        return .success("Opened project in Finder.")
    }

    func copyProjectPath(projectURL: URL) -> Result<String, Error> {
        copyText(projectURL.path, successMessage: "Copied project path.")
    }

    func openInTerminal(projectURL: URL) -> Result<String, Error> {
        let command = terminalOpenCommand(for: projectURL)
        do {
            let result = try processRunner.run(
                executableURL: URL(fileURLWithPath: command.executablePath),
                arguments: command.arguments,
                currentDirectoryURL: projectURL
            )

            guard result.exitCode == 0 else {
                return .failure(PostCreateActionError.commandFailed(command: "open -a Terminal", details: result.standardError))
            }

            return .success("Opened project in Terminal.")
        } catch {
            return .failure(error)
        }
    }

    func copyCodexStarterPrompt(projectURL: URL, template: ProjectTemplate) -> Result<String, Error> {
        let prompt = starterPrompt(for: projectURL, template: template)
        return copyText(prompt, successMessage: "Copied Codex starter prompt.")
    }

    func copySummary(_ summaryText: String) -> Result<String, Error> {
        copyText(summaryText, successMessage: "Copied project summary.")
    }

    func copyFileTree(_ fileTreeText: String) -> Result<String, Error> {
        copyText(fileTreeText, successMessage: "Copied project file tree.")
    }

    func copyPrompt(_ promptText: String, title: String) -> Result<String, Error> {
        copyText(promptText, successMessage: "Copied \(title.lowercased()).")
    }

    func starterPrompt(for projectURL: URL, template: ProjectTemplate) -> String {
        let validationTarget = ProjectTemplateSupport.validationTarget(for: template) ?? "no starter scene is configured yet"
        return """
        Read [AGENTS.md](\(projectURL.appendingPathComponent("AGENTS.md").path)) first.

        Work in the generated project at `\(projectURL.path)`.
        Selected template: `\(template.rawValue)`.

        Inspect the scaffold before making changes.
        Review `./run_validation.sh` and the starter validation target `\(validationTarget)`.
        Make small changes only.
        Run `./run_validation.sh` after changes and keep any logs in `artifacts/`.
        """
    }

    func terminalOpenCommand(for projectURL: URL) -> TerminalOpenCommand {
        TerminalOpenCommand(
            executablePath: "/usr/bin/open",
            arguments: ["-a", "Terminal", projectURL.path]
        )
    }

    private func copyText(_ text: String, successMessage: String) -> Result<String, Error> {
        pasteboard.clearContents()
        let didCopy = pasteboard.setString(text, forType: .string)
        guard didCopy else {
            return .failure(PostCreateActionError.clipboardWriteFailed)
        }
        return .success(successMessage)
    }
}

struct TerminalOpenCommand {
    let executablePath: String
    let arguments: [String]
}

enum PostCreateActionError: LocalizedError {
    case clipboardWriteFailed
    case missingTemplateContext
    case commandFailed(command: String, details: String)

    var errorDescription: String? {
        switch self {
        case .clipboardWriteFailed:
            return "Clipboard write failed."
        case .missingTemplateContext:
            return "Starter prompt template context is unavailable."
        case let .commandFailed(command, details):
            let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedDetails.isEmpty ? "\(command) failed." : "\(command) failed: \(trimmedDetails)"
        }
    }
}
