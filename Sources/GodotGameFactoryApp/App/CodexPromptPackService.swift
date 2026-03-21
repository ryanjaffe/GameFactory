import Foundation

struct CodexPromptPackService {
    func promptPack(for projectURL: URL, template: ProjectTemplate) -> [CodexPrompt] {
        CodexPromptKind.allCases.map { kind in
            CodexPrompt(
                kind: kind,
                title: kind.title,
                body: promptBody(for: kind, projectURL: projectURL, template: template)
            )
        }
    }

    private func promptBody(for kind: CodexPromptKind, projectURL: URL, template: ProjectTemplate) -> String {
        let agentsPath = projectURL.appendingPathComponent("AGENTS.md").path
        let validationTarget = ProjectTemplateSupport.validationTarget(for: template) ?? "no starter scene is configured yet"
        let templateContext = templateSpecificContext(for: kind, template: template)

        return """
        Read [AGENTS.md](\(agentsPath)) first.

        Work in the generated project at `\(projectURL.path)`.
        Selected template: `\(template.rawValue)`.
        Validation entrypoint: `./run_validation.sh`.
        Starter validation target: `\(validationTarget)`.

        Inspect the scaffold before editing.
        Make small changes only.
        Avoid renaming or moving files unless necessary.
        Validate after changes with `./run_validation.sh`.

        Task:
        \(templateContext)
        """
    }

    private func templateSpecificContext(for kind: CodexPromptKind, template: ProjectTemplate) -> String {
        switch kind {
        case .starter:
            switch template {
            case .blank:
                return "Review the blank scaffold, identify the next smallest useful gameplay or workflow improvement, implement it, and validate after changes."
            case .platformerStarter:
                return "Inspect the platformer scaffold first, especially `scripts/platformer_player.gd` and `scenes/platformer_playground.tscn`, then make the next smallest useful platformer improvement and validate after changes."
            case .topDownStarter:
                return "Inspect the top-down scaffold first, especially `scripts/top_down_player.gd` and `scenes/top_down_playground.tscn`, then make the next smallest useful top-down improvement and validate after changes."
            }
        case .nextMechanic:
            switch template {
            case .blank:
                return "Implement the next smallest useful mechanic or interaction for this blank project scaffold, keeping the change bounded and easy to inspect."
            case .platformerStarter:
                return "Implement the next small platformer mechanic after the current movement placeholder, such as jump tuning, coyote time notes, or a simple collectible hook, while keeping the change bounded."
            case .topDownStarter:
                return "Implement the next small top-down mechanic after the current movement placeholder, such as interaction range, dash placeholder, or simple obstacle response, while keeping the change bounded."
            }
        case .diagnoseIssue:
            switch template {
            case .blank:
                return "Inspect the blank project scaffold for workflow or structure issues, identify the smallest concrete problem, explain the root cause, fix it safely, and validate after changes."
            case .platformerStarter:
                return "Diagnose a platformer starter issue by inspecting the scaffold, movement placeholder, and validation flow first, then fix only the smallest confirmed problem."
            case .topDownStarter:
                return "Diagnose a top-down starter issue by inspecting the scaffold, movement placeholder, and validation flow first, then fix only the smallest confirmed problem."
            }
        case .instrumentation:
            switch template {
            case .blank:
                return "Add small, clear instrumentation or debug output to help inspect the blank scaffold workflow without introducing noisy or permanent debugging clutter."
            case .platformerStarter:
                return "Add lightweight instrumentation around the platformer starter flow so movement or validation behavior is easier to inspect without turning it into a full debug system."
            case .topDownStarter:
                return "Add lightweight instrumentation around the top-down starter flow so movement or validation behavior is easier to inspect without turning it into a full debug system."
            }
        case .improveValidation:
            switch template {
            case .blank:
                return "Improve the generated validation workflow for the blank scaffold in a small, safe way, keeping `./run_validation.sh` lightweight and editable."
            case .platformerStarter:
                return "Improve the validation workflow for the platformer starter in a small, safe way, especially around `./run_validation.sh` and the starter scene checks."
            case .topDownStarter:
                return "Improve the validation workflow for the top-down starter in a small, safe way, especially around `./run_validation.sh` and the starter scene checks."
            }
        }
    }
}

struct CodexPrompt: Identifiable, Equatable {
    let kind: CodexPromptKind
    let title: String
    let body: String

    var id: String { kind.rawValue }
}

enum CodexPromptKind: String, CaseIterable, Identifiable {
    case starter
    case nextMechanic
    case diagnoseIssue
    case instrumentation
    case improveValidation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starter:
            return "Starter Prompt"
        case .nextMechanic:
            return "Implement Next Mechanic"
        case .diagnoseIssue:
            return "Diagnose Issue"
        case .instrumentation:
            return "Add Instrumentation"
        case .improveValidation:
            return "Improve Validation"
        }
    }
}
