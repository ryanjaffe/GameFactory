import Foundation

struct CodexHandoffService {
    private let promptPackService: CodexPromptPackService
    private let copyPromptAction: (String, String) -> Result<String, Error>
    private let openTerminalAction: (URL) -> Result<String, Error>

    init(
        promptPackService: CodexPromptPackService = CodexPromptPackService(),
        actionService: PostCreateActionService = PostCreateActionService()
    ) {
        self.promptPackService = promptPackService
        self.copyPromptAction = { promptText, title in
            actionService.copyPrompt(promptText, title: title)
        }
        self.openTerminalAction = { projectURL in
            actionService.openInTerminal(projectURL: projectURL)
        }
    }

    init(
        promptPackService: CodexPromptPackService = CodexPromptPackService(),
        copyPromptAction: @escaping (String, String) -> Result<String, Error>,
        openTerminalAction: @escaping (URL) -> Result<String, Error>
    ) {
        self.promptPackService = promptPackService
        self.copyPromptAction = copyPromptAction
        self.openTerminalAction = openTerminalAction
    }

    func plan(for projectURL: URL, template: ProjectTemplate) -> CodexHandoffPlan {
        let starterPrompt = promptPackService.starterPrompt(for: projectURL, template: template)

        return CodexHandoffPlan(
            projectURL: projectURL,
            template: template,
            prompt: starterPrompt,
            nextStepMessage: """
            Codex handoff is ready. In Codex, read AGENTS.md first, inspect the scaffold, then run ./run_validation.sh after your first change.
            """
        )
    }

    func openInCodex(projectURL: URL, template: ProjectTemplate) -> Result<CodexHandoffOutcome, Error> {
        let handoffPlan = plan(for: projectURL, template: template)

        switch copyPromptAction(handoffPlan.prompt.body, handoffPlan.prompt.title) {
        case let .failure(error):
            return .failure(error)
        case let .success(copyMessage):
            var messages = [copyMessage]

            switch openTerminalAction(projectURL) {
            case let .success(terminalMessage):
                messages.append(terminalMessage)
                return .success(
                    CodexHandoffOutcome(
                        messages: messages,
                        nextStepMessage: handoffPlan.nextStepMessage
                    )
                )
            case .failure:
                messages.append("Opened prompt handoff, but Terminal could not be launched automatically.")
                return .success(
                    CodexHandoffOutcome(
                        messages: messages,
                        nextStepMessage: """
                        Starter prompt copied. Open the project in Terminal manually at `\(projectURL.path)`, then read AGENTS.md first and run ./run_validation.sh after your first change.
                        """
                    )
                )
            }
        }
    }
}

struct CodexHandoffPlan {
    let projectURL: URL
    let template: ProjectTemplate
    let prompt: CodexPrompt
    let nextStepMessage: String
}

struct CodexHandoffOutcome {
    let messages: [String]
    let nextStepMessage: String
}
