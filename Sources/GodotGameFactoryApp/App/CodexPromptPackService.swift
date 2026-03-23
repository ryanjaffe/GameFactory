import Foundation

enum CodexPromptSectionKind {
    case projectSummary
    case workflowFiles
    case starterContext
    case notesOrContext
}

struct CodexPromptSection {
    let kind: CodexPromptSectionKind
    let body: String
}

struct CodexPromptPackService {
    private let assetPromptContextService: AssetPromptContextService

    init(assetPromptContextService: AssetPromptContextService = AssetPromptContextService()) {
        self.assetPromptContextService = assetPromptContextService
    }

    func promptPack(
        for projectURL: URL,
        template: ProjectTemplate,
        workflowSettings: ProjectWorkflowSettings? = nil
    ) -> [CodexPrompt] {
        CodexPromptKind.allCases.map { kind in
            CodexPrompt(
                kind: kind,
                title: kind.title,
                body: promptBody(
                    for: kind,
                    projectURL: projectURL,
                    template: template,
                    workflowSettings: workflowSettings
                )
            )
        }
    }

    func starterPrompt(
        for projectURL: URL,
        template: ProjectTemplate,
        workflowSettings: ProjectWorkflowSettings? = nil
    ) -> CodexPrompt {
        CodexPrompt(
            kind: .starter,
            title: CodexPromptKind.starter.title,
            body: promptBody(
                for: .starter,
                projectURL: projectURL,
                template: template,
                workflowSettings: workflowSettings
            )
        )
    }

    private func promptBody(
        for kind: CodexPromptKind,
        projectURL: URL,
        template: ProjectTemplate,
        workflowSettings: ProjectWorkflowSettings?
    ) -> String {
        promptSections(
            for: kind,
            projectURL: projectURL,
            template: template,
            workflowSettings: workflowSettings
        )
        .map(\.body)
        .joined(separator: "\n\n")
    }

    func promptSections(
        for kind: CodexPromptKind,
        projectURL: URL,
        template: ProjectTemplate,
        workflowSettings: ProjectWorkflowSettings? = nil
    ) -> [CodexPromptSection] {
        let agentsPath = projectURL.appendingPathComponent("AGENTS.md").path
        let validationTarget = workflowSettings?.effectiveValidationTarget(for: template) ??
            (ProjectTemplateSupport.validationTarget(for: template) ?? "no starter scene is configured yet")
        let templateContext = templateSpecificContext(for: kind, template: template)
        let assetSummary = assetPromptContextService.assetSummary(for: projectURL)
        let handoffNote = workflowSettings?.trimmedHandoffNote ?? ""
        let handoffNoteSection = handoffNote.isEmpty ? nil : CodexPromptSection(
            kind: .notesOrContext,
            body: "Project handoff note: \(handoffNote)"
        )

        let sections: [CodexPromptSection?] = [
            CodexPromptSection(
                kind: .workflowFiles,
                body: """
        Read [AGENTS.md](\(agentsPath)) first.
        Validation entrypoint: `./run_validation.sh`.
        """
            ),
            CodexPromptSection(
                kind: .projectSummary,
                body: """
        Work in the generated project at `\(projectURL.path)`.
        Selected template: `\(template.rawValue)`.
        """
            ),
            CodexPromptSection(
                kind: .starterContext,
                body: """
        Starter validation target: `\(validationTarget)`.
        \(assetSummary)
        """
            ),
            handoffNoteSection,
            CodexPromptSection(
                kind: .notesOrContext,
                body: """
        Inspect the scaffold before editing.
        Make small changes only.
        Avoid renaming or moving files unless necessary.
        Validate after changes with `./run_validation.sh`.
        """
            ),
            CodexPromptSection(
                kind: .starterContext,
                body: """
        Task:
        \(templateContext)
        """
            )
        ]

        return sections.compactMap { $0 }
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
            case .starter3D:
                return "Inspect the 3D scaffold first, especially `scripts/player_controller_3d.gd` and `scenes/starter_3d_playground.tscn`, then make the next smallest useful 3D improvement and validate after changes."
            case .dialogueNarrativeStarter:
                return "Inspect the dialogue scaffold first, especially `scripts/dialogue_controller.gd`, `scenes/dialogue_playground.tscn`, and `tests/dialogue_outline.txt`, then make the next smallest useful narrative improvement and validate after changes."
            }
        case .nextMechanic:
            switch template {
            case .blank:
                return "Implement the next smallest useful mechanic or interaction for this blank project scaffold, keeping the change bounded and easy to inspect."
            case .platformerStarter:
                return "Implement the next small platformer mechanic after the current movement placeholder, such as jump tuning, coyote time notes, or a simple collectible hook, while keeping the change bounded."
            case .topDownStarter:
                return "Implement the next small top-down mechanic after the current movement placeholder, such as interaction range, dash placeholder, or simple obstacle response, while keeping the change bounded."
            case .starter3D:
                return "Implement the next small 3D mechanic after the current movement placeholder, such as look controls, camera follow notes, or a simple interactable hook, while keeping the change bounded."
            case .dialogueNarrativeStarter:
                return "Implement the next small dialogue mechanic after the current placeholder, such as advancing text, a branching choice stub, or speaker metadata, while keeping the change bounded."
            }
        case .diagnoseIssue:
            switch template {
            case .blank:
                return "Inspect the blank project scaffold for workflow or structure issues, identify the smallest concrete problem, explain the root cause, fix it safely, and validate after changes."
            case .platformerStarter:
                return "Diagnose a platformer starter issue by inspecting the scaffold, movement placeholder, and validation flow first, then fix only the smallest confirmed problem."
            case .topDownStarter:
                return "Diagnose a top-down starter issue by inspecting the scaffold, movement placeholder, and validation flow first, then fix only the smallest confirmed problem."
            case .starter3D:
                return "Diagnose a 3D starter issue by inspecting the scaffold, movement placeholder, and validation flow first, then fix only the smallest confirmed problem."
            case .dialogueNarrativeStarter:
                return "Diagnose a dialogue starter issue by inspecting the scaffold, placeholder script, outline data, and validation flow first, then fix only the smallest confirmed problem."
            }
        case .instrumentation:
            switch template {
            case .blank:
                return "Add small, clear instrumentation or debug output to help inspect the blank scaffold workflow without introducing noisy or permanent debugging clutter."
            case .platformerStarter:
                return "Add lightweight instrumentation around the platformer starter flow so movement or validation behavior is easier to inspect without turning it into a full debug system."
            case .topDownStarter:
                return "Add lightweight instrumentation around the top-down starter flow so movement or validation behavior is easier to inspect without turning it into a full debug system."
            case .starter3D:
                return "Add lightweight instrumentation around the 3D starter flow so movement or validation behavior is easier to inspect without turning it into a full debug system."
            case .dialogueNarrativeStarter:
                return "Add lightweight instrumentation around the dialogue starter flow so text progression or branching behavior is easier to inspect without turning it into a full debug system."
            }
        case .improveValidation:
            switch template {
            case .blank:
                return "Improve the generated validation workflow for the blank scaffold in a small, safe way, keeping `./run_validation.sh` lightweight and editable."
            case .platformerStarter:
                return "Improve the validation workflow for the platformer starter in a small, safe way, especially around `./run_validation.sh` and the starter scene checks."
            case .topDownStarter:
                return "Improve the validation workflow for the top-down starter in a small, safe way, especially around `./run_validation.sh` and the starter scene checks."
            case .starter3D:
                return "Improve the validation workflow for the 3D starter in a small, safe way, especially around `./run_validation.sh` and the starter scene checks."
            case .dialogueNarrativeStarter:
                return "Improve the validation workflow for the dialogue starter in a small, safe way, especially around `./run_validation.sh`, the starter scene, and the narrative outline checks."
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

enum CodexPromptKind: String, CaseIterable, Identifiable, Codable {
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
