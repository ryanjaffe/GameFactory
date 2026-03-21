import Foundation

struct WorkflowFileRepairService {
    private let generator: ProjectGenerator
    private let fileManager: FileManager

    init(generator: ProjectGenerator = ProjectGenerator(), fileManager: FileManager = .default) {
        self.generator = generator
        self.fileManager = fileManager
    }

    func regenerateFile(
        kind: WorkflowFileKind,
        projectURL: URL,
        projectName: String,
        gitHubUsername: String,
        repoVisibility: RepoVisibility,
        template: ProjectTemplate,
        validationTargetOverride: String?
    ) throws -> WorkflowFileRepairResult {
        let fileURL = projectURL.appendingPathComponent(kind.fileName)
        let alreadyExisted = fileManager.fileExists(atPath: fileURL.path)

        let plannedFile = generator.defaultWorkflowFile(
            kind: kind,
            projectName: projectName,
            projectURL: projectURL,
            gitHubUsername: gitHubUsername,
            repoVisibility: repoVisibility,
            template: template,
            validationTargetOverride: validationTargetOverride
        )

        try plannedFile.contents.write(to: plannedFile.url, atomically: true, encoding: .utf8)
        if plannedFile.isExecutable {
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: plannedFile.url.path)
        }

        return WorkflowFileRepairResult(
            fileURL: plannedFile.url,
            restoredExistingFile: alreadyExisted,
            isExecutable: plannedFile.isExecutable
        )
    }
}

struct WorkflowFileRepairResult {
    let fileURL: URL
    let restoredExistingFile: Bool
    let isExecutable: Bool
}
