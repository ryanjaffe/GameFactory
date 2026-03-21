import Foundation

struct ProjectAuditSummary {
    let projectURL: URL
    let projectName: String
    let template: ProjectTemplate?
    let checks: [ProjectAuditCheck]

    var summaryText: String {
        let passCount = checks.filter { $0.status == .pass }.count
        let warnCount = checks.filter { $0.status == .warn }.count
        let failCount = checks.filter { $0.status == .fail }.count
        let skippedCount = checks.filter { $0.status == .skipped }.count

        return """
        Audit Summary

        Project: \(projectName)
        Path: \(projectURL.path)
        Template: \(template?.rawValue ?? "Unknown")
        Pass: \(passCount)
        Warn: \(warnCount)
        Fail: \(failCount)
        Skipped: \(skippedCount)
        """
    }
}

struct ProjectAuditCheck: Identifiable, Equatable {
    let id: String
    let title: String
    let status: ProjectAuditStatus
    let detail: String
}

enum ProjectAuditStatus: String, Equatable {
    case pass = "Pass"
    case warn = "Warn"
    case fail = "Fail"
    case skipped = "Skipped"

    var systemImageName: String {
        switch self {
        case .pass:
            return "checkmark.circle.fill"
        case .warn:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.circle.fill"
        case .skipped:
            return "minus.circle.fill"
        }
    }
}
