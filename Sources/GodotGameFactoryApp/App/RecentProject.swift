import Foundation

struct RecentProject: Identifiable, Equatable, Codable {
    let path: String
    let projectName: String
    let template: ProjectTemplate
    let createdAt: Date
    let gitInitialized: Bool
    let gitHubStatus: ProjectIntegrationStatus

    var id: String { path }

    var projectURL: URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    var createdAtDisplayText: String {
        Self.dateFormatter.string(from: createdAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
