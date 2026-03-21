import Foundation

struct ProjectWorkflowSettings: Codable, Equatable {
    var validationTarget: String
    var godotPathOverride: String
    var handoffNote: String
    var projectNote: String

    static func defaults(for template: ProjectTemplate?) -> ProjectWorkflowSettings {
        ProjectWorkflowSettings(
            validationTarget: template.flatMap { ProjectTemplateSupport.validationTarget(for: $0) } ?? "",
            godotPathOverride: "",
            handoffNote: "",
            projectNote: ""
        )
    }

    var trimmedValidationTarget: String {
        validationTarget.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedGodotPathOverride: String {
        godotPathOverride.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedHandoffNote: String {
        handoffNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedProjectNote: String {
        projectNote.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func effectiveValidationTarget(for template: ProjectTemplate) -> String {
        let trimmedValue = trimmedValidationTarget
        if !trimmedValue.isEmpty {
            return trimmedValue
        }

        return ProjectTemplateSupport.validationTarget(for: template) ?? "no starter scene is configured yet"
    }

    func summaryLines(defaults: ProjectWorkflowSettings) -> [String] {
        var lines: [String] = []

        if trimmedValidationTarget != defaults.trimmedValidationTarget {
            lines.append("Validation target: \(trimmedValidationTarget.isEmpty ? "(blank)" : trimmedValidationTarget)")
        }

        if !trimmedGodotPathOverride.isEmpty {
            lines.append("Godot path override: \(trimmedGodotPathOverride)")
        }

        if !trimmedHandoffNote.isEmpty {
            lines.append("Handoff note: \(trimmedHandoffNote)")
        }

        if !trimmedProjectNote.isEmpty {
            lines.append("Project note: \(trimmedProjectNote)")
        }

        return lines
    }
}

struct ProjectWorkflowSettingsDocument: Equatable {
    let projectURL: URL
    let fileURL: URL
    let settings: ProjectWorkflowSettings
    let usedDefaults: Bool
    let statusMessage: String
}
