import Foundation

struct ProjectPreset: Identifiable, Equatable, Codable {
    let name: String
    let baseDirectory: String
    let gitHubUsername: String
    let repoVisibility: RepoVisibility
    let template: ProjectTemplate

    var id: String { name }

    static func from(name: String, settings: AppSettings) -> ProjectPreset {
        ProjectPreset(
            name: name,
            baseDirectory: settings.baseDirectory,
            gitHubUsername: settings.gitHubUsername,
            repoVisibility: settings.repoVisibility,
            template: settings.template
        )
    }

    func applying(to settings: AppSettings) -> AppSettings {
        AppSettings(
            projectName: settings.projectName,
            baseDirectory: baseDirectory,
            godotExecutablePath: settings.godotExecutablePath,
            gitHubUsername: gitHubUsername,
            repoVisibility: repoVisibility,
            template: template
        )
    }
}
