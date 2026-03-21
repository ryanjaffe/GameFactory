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
        createdFiles
            .map { $0.lastPathComponent }
            .filter { ["AGENTS.md", "run_validation.sh"].contains($0) }
            .sorted()
    }

    var summaryText: String {
        let workflowList = workflowFiles.joined(separator: ", ")

        return """
        Project: \(projectName)
        Path: \(finalProjectURL.path)
        Template: \(template.rawValue)
        Git: \(gitStatus.displayText)
        GitHub: \(gitHubStatus.displayText)
        Workflow files: \(workflowList)
        """
    }

    var fileTreeText: String {
        let rootFiles = relativeRootFiles()
        let sections = ["scenes", "scripts", "tests", "artifacts"]

        var lines = [finalProjectURL.lastPathComponent + "/"]
        lines.append(contentsOf: rootFiles.map { "\($0)" })

        for section in sections {
            lines.append("\(section)/")

            let nested = relativeNestedFiles(in: section)
            if nested.isEmpty {
                lines.append("  (empty)")
            } else {
                lines.append(contentsOf: nested.map { "  \($0)" })
            }
        }

        return lines.joined(separator: "\n")
    }

    private func relativeRootFiles() -> [String] {
        createdFiles
            .filter { $0.deletingLastPathComponent().path == finalProjectURL.path }
            .map(\.lastPathComponent)
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
