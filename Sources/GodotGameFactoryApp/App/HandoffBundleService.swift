import Foundation

struct HandoffBundleService {
    func buildBundle(from input: HandoffBundleInput) -> String {
        let workflowFiles = input.workflowFiles.isEmpty
            ? "- none detected"
            : input.workflowFiles.map { "- \($0)" }.joined(separator: "\n")

        let auditSection = input.auditSummaryText.map {
            """
            ## Audit

            \($0)
            """
        } ?? """
        ## Audit

        No recent audit is available for this project.
        """

        let assetSection = """
        ## Assets

        \(input.assetInventorySummaryText)

        \(input.recentAssetImportText ?? "Recent imports: none recorded in the current app session.")
        """

        let workflowSettingsSection = input.workflowSettingsSummaryText.map {
            """
            ## Workflow Settings

            \($0)
            """
        } ?? ""

        let projectSessionNotesSection = input.projectSessionNotesText.map {
            """
            ## Project Session Notes

            \($0)
            """
        } ?? ""

        let recentActivitySection = input.recentActivitySummaryText.map {
            """
            ## Recent Activity

            \($0)
            """
        } ?? ""

        let validationSection = input.validationSummaryText.map {
            """
            ## Validation

            \($0)
            """
        } ?? ""

        let nextSteps = input.nextSteps.map { "- \($0)" }.joined(separator: "\n")

        return """
        # Project Handoff Bundle

        ## Summary

        Project: \(input.projectName)
        Path: \(input.projectPath)
        Template: \(input.templateName)
        Git: \(input.gitStatus)
        GitHub/Origin: \(input.gitHubStatus)

        Workflow files present:
        \(workflowFiles)

        ## File Tree

        \(input.fileTreeText)

        \(auditSection)

        \(assetSection)

        \(workflowSettingsSection)

        \(projectSessionNotesSection)

        \(recentActivitySection)

        \(validationSection)

        ## Starter Prompt

        \(input.starterPrompt)

        ## Next Steps

        \(nextSteps)
        """
    }
}

struct HandoffBundleInput {
    let projectName: String
    let projectPath: String
    let templateName: String
    let gitStatus: String
    let gitHubStatus: String
    let workflowFiles: [String]
    let fileTreeText: String
    let auditSummaryText: String?
    let assetInventorySummaryText: String
    let recentAssetImportText: String?
    let workflowSettingsSummaryText: String?
    let projectSessionNotesText: String?
    let recentActivitySummaryText: String?
    let validationSummaryText: String?
    let starterPrompt: String
    let nextSteps: [String]
}
