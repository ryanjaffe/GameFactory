import Foundation

struct InspectedProjectSummary {
    let projectURL: URL
    let projectName: String
    let detectedTemplate: ProjectTemplate?
    let hasProjectGodot: Bool
    let hasAgentsFile: Bool
    let hasReadmeFile: Bool
    let hasValidationScript: Bool
    let hasGitDirectory: Bool
    let originRemoteStatus: OriginRemoteStatus
    let hasScenesDirectory: Bool
    let hasScriptsDirectory: Bool
    let hasArtDirectory: Bool
    let hasTestsDirectory: Bool
    let hasArtifactsDirectory: Bool
    let rootFiles: [String]
    let nestedFiles: [String]

    var isValidProject: Bool {
        hasProjectGodot
    }

    var templateDisplayName: String {
        detectedTemplate?.rawValue ?? "Unknown"
    }

    var validationMessage: String {
        if isValidProject {
            return "Project looks valid for inspection."
        }

        return "This folder does not look like a Godot project because `project.godot` is missing."
    }

    var codexTemplate: ProjectTemplate {
        detectedTemplate ?? .blank
    }

    var summaryText: String {
        """
        Existing Project Summary

        Project: \(projectName)
        Path: \(projectURL.path)
        Template: \(templateDisplayName)
        project.godot: \(yesNo(hasProjectGodot))
        AGENTS.md: \(yesNo(hasAgentsFile))
        README.md: \(yesNo(hasReadmeFile))
        run_validation.sh: \(yesNo(hasValidationScript))
        Git: \(yesNo(hasGitDirectory))
        Origin: \(originRemoteStatus.displayText)
        scenes/: \(yesNo(hasScenesDirectory))
        scripts/: \(yesNo(hasScriptsDirectory))
        art/: \(yesNo(hasArtDirectory))
        tests/: \(yesNo(hasTestsDirectory))
        artifacts/: \(yesNo(hasArtifactsDirectory))
        """
    }

    var fileTreeText: String {
        let keyDirectories = directoryEntries()
        var lines = [projectURL.lastPathComponent + "/"]

        for file in rootFiles {
            lines.append("├── \(file)")
        }

        for (index, entry) in keyDirectories.enumerated() {
            let isLast = index == keyDirectories.count - 1
            let branch = isLast ? "└──" : "├──"
            lines.append("\(branch) \(entry.name)/")

            if entry.files.isEmpty {
                lines.append("\(isLast ? "    " : "│   ")└── (empty)")
                continue
            }

            for (nestedIndex, file) in entry.files.enumerated() {
                let nestedBranch = nestedIndex == entry.files.count - 1 ? "└──" : "├──"
                let prefix = isLast ? "    " : "│   "
                lines.append("\(prefix)\(nestedBranch) \(file)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func directoryEntries() -> [(name: String, files: [String])] {
        ["scenes", "scripts", "art", "tests", "artifacts"].map { directory in
            let prefix = directory + "/"
            let files = nestedFiles
                .filter { $0.hasPrefix(prefix) }
                .map { String($0.dropFirst(prefix.count)) }
                .sorted()
            return (name: directory, files: files)
        }
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }
}

enum OriginRemoteStatus: Equatable {
    case present(String)
    case absent
    case unknown(String)

    var displayText: String {
        switch self {
        case .present:
            return "Present"
        case .absent:
            return "Missing"
        case let .unknown(reason):
            return "Unknown (\(reason))"
        }
    }

    var detailText: String? {
        switch self {
        case let .present(remoteURL):
            return remoteURL
        case .absent:
            return nil
        case let .unknown(reason):
            return reason
        }
    }
}
