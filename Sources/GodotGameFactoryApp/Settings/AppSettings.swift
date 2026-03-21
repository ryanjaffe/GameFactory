import Foundation

struct AppSettings: Equatable, Codable {
    var projectName: String
    var baseDirectory: String
    var gitHubUsername: String
    var repoVisibility: RepoVisibility
    var template: ProjectTemplate

    static let `default` = AppSettings(
        projectName: "",
        baseDirectory: "\(NSHomeDirectory())/Documents/CODEX",
        gitHubUsername: "",
        repoVisibility: .privateRepo,
        template: .blank
    )
}

enum RepoVisibility: String, CaseIterable, Identifiable, Codable {
    case privateRepo = "Private"
    case publicRepo = "Public"

    var id: String { rawValue }
}

enum ProjectTemplate: String, CaseIterable, Identifiable, Codable {
    case blank = "Blank"
    case platformerStarter = "2D Platformer Starter"
    case topDownStarter = "Top-Down Starter"

    var id: String { rawValue }
}
