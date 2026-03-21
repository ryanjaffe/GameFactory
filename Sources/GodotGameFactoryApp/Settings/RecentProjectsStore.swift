import Foundation

struct RecentProjectsStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let projectsKey = "GodotGameFactory.recentProjects"
    private let maxProjects: Int

    init(defaults: UserDefaults = .standard, maxProjects: Int = 10) {
        self.defaults = defaults
        self.maxProjects = maxProjects
    }

    func load() -> [RecentProject] {
        guard let data = defaults.data(forKey: projectsKey) else {
            return []
        }

        guard let decoded = try? decoder.decode([RecentProject].self, from: data) else {
            return []
        }

        return Array(decoded.prefix(maxProjects))
    }

    @discardableResult
    func save(_ projects: [RecentProject]) -> Bool {
        let boundedProjects = Array(projects.prefix(maxProjects))

        guard let data = try? encoder.encode(boundedProjects) else {
            return false
        }

        defaults.set(data, forKey: projectsKey)
        return true
    }

    func record(_ project: RecentProject) -> [RecentProject] {
        var projects = load()
        projects.removeAll { $0.path == project.path }
        projects.insert(project, at: 0)
        let boundedProjects = Array(projects.prefix(maxProjects))
        _ = save(boundedProjects)
        return boundedProjects
    }
}
