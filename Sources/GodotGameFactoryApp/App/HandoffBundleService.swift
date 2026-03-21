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

        let assetSection = input.assetImportSummaryText.map {
            """
            ## Imported Assets

            \($0)
            """
        } ?? """
        ## Imported Assets

        No recent asset import is available for this project.
        """

        let workflowSettingsSection = input.workflowSettingsSummaryText.map {
            """
            ## Workflow Settings

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
    let assetImportSummaryText: String?
    let workflowSettingsSummaryText: String?
    let starterPrompt: String
    let nextSteps: [String]
}
