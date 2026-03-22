import Foundation
import XCTest
@testable import GodotGameFactoryApp

@MainActor
final class AppViewModelActiveProjectTests: XCTestCase {
    func testNoProjectSourcesMeansNoActiveProject() {
        let context = makeTestContext()
        defer { context.cleanup() }

        let viewModel = context.makeViewModel()

        XCTAssertNil(viewModel.activeProjectURL)
        XCTAssertFalse(viewModel.hasActiveProject)
        XCTAssertEqual(viewModel.activeProjectContextLabel, "Active Project")
        XCTAssertTrue(viewModel.availablePromptPack.isEmpty)
    }

    func testLastCreatedProjectBecomesActiveWhenItIsOnlySource() throws {
        var context = makeTestContext()
        defer { context.cleanup() }

        let baseDirectory = try context.makeTemporaryDirectory()
        let viewModel = context.makeViewModel()

        viewModel.settings.projectName = "LastCreatedProject"
        viewModel.settings.baseDirectory = baseDirectory.path
        viewModel.settings.gitHubUsername = ""
        viewModel.settings.template = .blank
        viewModel.createProject()

        let expectedURL = baseDirectory.appendingPathComponent("LastCreatedProject", isDirectory: true)
        XCTAssertEqual(viewModel.lastCreatedProjectURL, expectedURL)
        XCTAssertEqual(viewModel.activeProjectURL, expectedURL)
        XCTAssertEqual(viewModel.activeProjectName, "LastCreatedProject")
        XCTAssertEqual(viewModel.activeProjectContextLabel, "Active Project (Last Created)")
    }

    func testInspectedProjectOverridesLastCreatedProject() throws {
        var context = makeTestContext()
        defer { context.cleanup() }

        let baseDirectory = try context.makeTemporaryDirectory()
        let inspectedProjectURL = try context.makeInspectedProject(name: "InspectedProject", template: .dialogueNarrativeStarter)
        let viewModel = context.makeViewModel(existingProjectPickerService: ExistingProjectPickerService(picker: { inspectedProjectURL }))

        viewModel.settings.projectName = "LastCreatedProject"
        viewModel.settings.baseDirectory = baseDirectory.path
        viewModel.settings.gitHubUsername = ""
        viewModel.settings.template = .blank
        viewModel.createProject()
        viewModel.openExistingProject()

        XCTAssertEqual(viewModel.activeProjectURL, inspectedProjectURL)
        XCTAssertEqual(viewModel.activeProjectName, "InspectedProject")
        XCTAssertEqual(viewModel.activeProjectTemplate, .dialogueNarrativeStarter)
        XCTAssertEqual(viewModel.activeProjectContextLabel, "Active Project (Inspected)")
    }

    func testSelectedRecentProjectOverridesInspectedAndLastCreated() throws {
        var context = makeTestContext()
        defer { context.cleanup() }

        let baseDirectory = try context.makeTemporaryDirectory()
        let inspectedProjectURL = try context.makeInspectedProject(name: "InspectedProject", template: .dialogueNarrativeStarter)
        let recentProjectURL = try context.makeTemporaryDirectory().appendingPathComponent("RecentProject", isDirectory: true)
        try FileManager.default.createDirectory(at: recentProjectURL, withIntermediateDirectories: true)

        let recentProject = RecentProject(
            path: recentProjectURL.path,
            projectName: "RecentProject",
            template: .starter3D,
            createdAt: Date(),
            gitInitialized: true,
            gitHubStatus: .succeeded
        )

        let viewModel = context.makeViewModel(
            existingProjectPickerService: ExistingProjectPickerService(picker: { inspectedProjectURL }),
            recentProjects: [recentProject]
        )

        viewModel.settings.projectName = "LastCreatedProject"
        viewModel.settings.baseDirectory = baseDirectory.path
        viewModel.settings.gitHubUsername = ""
        viewModel.settings.template = .blank
        viewModel.createProject()
        viewModel.openExistingProject()
        viewModel.selectRecentProjectForWorkflowFiles(recentProject)

        XCTAssertEqual(viewModel.activeProjectURL, recentProjectURL)
        XCTAssertEqual(viewModel.activeProjectName, "RecentProject")
        XCTAssertEqual(viewModel.activeProjectTemplate, .starter3D)
        XCTAssertEqual(viewModel.activeProjectContextLabel, "Active Project (Recent)")
    }

    func testStarterPromptUsesActiveRecentProjectNotLastCreatedProject() throws {
        var context = makeTestContext()
        defer { context.cleanup() }

        let baseDirectory = try context.makeTemporaryDirectory()
        let inspectedProjectURL = try context.makeInspectedProject(name: "InspectedProject", template: .dialogueNarrativeStarter)
        let recentProjectURL = try context.makeTemporaryDirectory().appendingPathComponent("RecentProject", isDirectory: true)
        try FileManager.default.createDirectory(at: recentProjectURL, withIntermediateDirectories: true)

        let recentProject = RecentProject(
            path: recentProjectURL.path,
            projectName: "RecentProject",
            template: .starter3D,
            createdAt: Date(),
            gitInitialized: true,
            gitHubStatus: .succeeded
        )

        let viewModel = context.makeViewModel(
            existingProjectPickerService: ExistingProjectPickerService(picker: { inspectedProjectURL }),
            recentProjects: [recentProject]
        )

        viewModel.settings.projectName = "LastCreatedProject"
        viewModel.settings.baseDirectory = baseDirectory.path
        viewModel.settings.gitHubUsername = ""
        viewModel.settings.template = .blank
        viewModel.createProject()
        viewModel.openExistingProject()
        viewModel.selectRecentProjectForWorkflowFiles(recentProject)

        let prompt = try XCTUnwrap(viewModel.activeCodexStarterPrompt)

        XCTAssertTrue(prompt.contains(recentProjectURL.path))
        XCTAssertTrue(prompt.contains(ProjectTemplate.starter3D.rawValue))
        XCTAssertFalse(prompt.contains("LastCreatedProject"))
        XCTAssertFalse(prompt.contains(ProjectTemplate.blank.rawValue))
    }
}

@MainActor
private struct TestContext {
    let suiteName: String
    let defaults: UserDefaults
    let fileManager: FileManager = .default
    private(set) var temporaryURLs: [URL] = []

    mutating func makeTemporaryDirectory() throws -> URL {
        let url = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryURLs.append(url)
        return url
    }

    mutating func makeInspectedProject(name: String, template: ProjectTemplate) throws -> URL {
        let parent = try makeTemporaryDirectory()
        let root = parent.appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try "config_version=5".write(to: root.appendingPathComponent("project.godot"), atomically: true, encoding: .utf8)

        switch template {
        case .dialogueNarrativeStarter:
            try fileManager.createDirectory(at: root.appendingPathComponent("scenes", isDirectory: true), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: root.appendingPathComponent("scripts", isDirectory: true), withIntermediateDirectories: true)
            try "".write(to: root.appendingPathComponent("scenes/dialogue_playground.tscn"), atomically: true, encoding: .utf8)
            try "".write(to: root.appendingPathComponent("scripts/dialogue_controller.gd"), atomically: true, encoding: .utf8)
        case .starter3D:
            try fileManager.createDirectory(at: root.appendingPathComponent("scenes", isDirectory: true), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: root.appendingPathComponent("scripts", isDirectory: true), withIntermediateDirectories: true)
            try "".write(to: root.appendingPathComponent("scenes/starter_3d_playground.tscn"), atomically: true, encoding: .utf8)
            try "".write(to: root.appendingPathComponent("scripts/player_controller_3d.gd"), atomically: true, encoding: .utf8)
        default:
            break
        }

        return root
    }

    func makeViewModel(
        existingProjectPickerService: ExistingProjectPickerService = ExistingProjectPickerService(picker: { nil }),
        recentProjects: [RecentProject] = []
    ) -> AppViewModel {
        defaults.removePersistentDomain(forName: suiteName)
        let settingsStore = AppSettingsStore(defaults: defaults)
        let recentProjectsStore = RecentProjectsStore(defaults: defaults)
        if !recentProjects.isEmpty {
            _ = recentProjectsStore.save(recentProjects)
        }

        return AppViewModel(
            settingsStore: settingsStore,
            recentProjectsStore: recentProjectsStore,
            existingProjectPickerService: existingProjectPickerService
        )
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
        for url in temporaryURLs {
            try? fileManager.removeItem(at: url)
        }
    }
}

private func makeTestContext() -> TestContext {
    let suiteName = "GodotGameFactoryAppTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    return TestContext(suiteName: suiteName, defaults: defaults)
}
