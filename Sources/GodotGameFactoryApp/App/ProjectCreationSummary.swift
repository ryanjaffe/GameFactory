import Foundation

struct ProjectCreationSummary {
    let projectName: String
    let finalProjectURL: URL
    let template: ProjectTemplate
    let gitStatus: ProjectIntegrationStatus
    let gitHubStatus: ProjectIntegrationStatus
    let createdDirectories: [URL]
    let createdFiles: [URL]

    var workflowFiles: [String] {
        relativePaths()
            .filter { ["AGENTS.md", "run_validation.sh"].contains($0) }
            .sorted()
    }

    var templateStarterFiles: [String] {
        relativePaths()
            .filter {
                $0.hasPrefix("scenes/") || $0.hasPrefix("scripts/") || $0.hasPrefix("tests/")
            }
            .filter { !workflowFiles.contains($0) }
            .sorted()
    }

    var summaryText: String {
        let workflowList = workflowFiles.map { "- \($0)" }.joined(separator: "\n")
        let starterList = templateStarterFiles.isEmpty
            ? "- none"
            : templateStarterFiles.map { "- \($0)" }.joined(separator: "\n")
        let nextSteps = nextStepsLines().map { "- \($0)" }.joined(separator: "\n")

        return """
        Project Summary

        Project: \(projectName)
        Path: \(finalProjectURL.path)
        Template: \(template.rawValue)
        Git: \(gitStatus.displayText)
        GitHub: \(gitHubStatus.displayText)

        Workflow files:
        \(workflowList)

        Template starter files:
        \(starterList)

        Next steps:
        \(nextSteps)
        """
    }

    var fileTreeText: String {
        let rootFiles = relativeRootFiles()
        let keyDirectories = ["scenes", "scripts", "tests", "artifacts"]

        var lines = [finalProjectURL.lastPathComponent + "/"]

        for file in rootFiles {
            lines.append("├── \(file)")
        }

        for (index, directory) in keyDirectories.enumerated() {
            let isLastDirectory = index == keyDirectories.count - 1
            let branch = isLastDirectory ? "└──" : "├──"
            lines.append("\(branch) \(directory)/")

            let nestedFiles = relativeNestedFiles(in: directory)
            if nestedFiles.isEmpty {
                lines.append("\(isLastDirectory ? "    " : "│   ")└── (empty)")
                continue
            }

            for (nestedIndex, nestedFile) in nestedFiles.enumerated() {
                let nestedBranch = nestedIndex == nestedFiles.count - 1 ? "└──" : "├──"
                let nestedPrefix = isLastDirectory ? "    " : "│   "
                lines.append("\(nestedPrefix)\(nestedBranch) \(nestedFile)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func nextStepsLines() -> [String] {
        var steps = [
            "Review `AGENTS.md` before making changes.",
            "Run `./run_validation.sh` after your first edit.",
        ]

        switch gitStatus {
        case .succeeded:
            steps.append("Local Git is ready for the next commit.")
        case let .skipped(reason), let .failed(reason):
            steps.append("Resolve local Git status: \(reason).")
        }

        switch gitHubStatus {
        case .succeeded:
            steps.append("GitHub remote is ready for push and follow-up work.")
        case let .skipped(reason):
            steps.append("GitHub setup is optional. Current status: \(reason).")
        case let .failed(reason):
            steps.append("Review GitHub setup before sharing the project: \(reason).")
        }

        return steps
    }

    private func relativePaths() -> [String] {
        createdFiles
            .map { $0.path.replacingOccurrences(of: finalProjectURL.path + "/", with: "") }
            .sorted()
    }

    private func relativeRootFiles() -> [String] {
        relativePaths()
            .filter { !$0.contains("/") }
            .sorted()
    }

    private func relativeNestedFiles(in section: String) -> [String] {
        let sectionPrefix = section + "/"
        return createdFiles
            .compactMap { fileURL in
                let relative = fileURL.path.replacingOccurrences(of: finalProjectURL.path + "/", with: "")
                guard relative.hasPrefix(sectionPrefix) else {
                    return nil
                }
                return String(relative.dropFirst(sectionPrefix.count))
            }
            .sorted()
    }
}

enum ProjectIntegrationStatus: Equatable {
    case succeeded
    case skipped(String)
    case failed(String)

    var label: String {
        switch self {
        case .succeeded:
            return "Ready"
        case .skipped:
            return "Skipped"
        case .failed:
            return "Failed"
        }
    }

    var detail: String? {
        switch self {
        case .succeeded:
            return nil
        case let .skipped(reason), let .failed(reason):
            return reason
        }
    }

    var displayText: String {
        guard let detail else {
            return label
        }

        return "\(label) (\(detail))"
    }

    var shortDetail: String {
        switch self {
        case .succeeded:
            return "Completed"
        case let .skipped(reason), let .failed(reason):
            return reason
        }
    }

    var systemImageName: String {
        switch self {
        case .succeeded:
            return "checkmark.circle.fill"
        case .skipped:
            return "minus.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .succeeded:
            return "success"
        case .skipped:
            return "skipped"
        case .failed:
            return "failed"
        }
    }
}
