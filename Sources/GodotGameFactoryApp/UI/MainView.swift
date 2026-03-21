import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            List {
                Label("New Project", systemImage: "hammer")
                Label("Settings", systemImage: "gearshape")
                Label("Logs", systemImage: "text.append")
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Godot Game Factory")
                        .font(.largeTitle)
                        .fontWeight(.semibold)

                    Text("Create a Godot project scaffold, inspect the plan first when needed, and keep the generated workflow easy to continue in Codex.")
                        .foregroundStyle(.secondary)

                    PresetsView(viewModel: viewModel)
                    NewProjectFormView(viewModel: viewModel)
                    ProjectSummaryView(viewModel: viewModel)
                    PromptPackView(viewModel: viewModel)
                    PostCreateActionsView(viewModel: viewModel)
                    CodexHandoffStatusView(viewModel: viewModel)
                    RecentProjectsView(viewModel: viewModel)

                    LogPanelView(entries: viewModel.logEntries)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
        }
    }
}

private struct PresetsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Presets") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Save reusable creation defaults for base directory, GitHub settings, visibility, and template.")
                    .foregroundStyle(.secondary)

                TextField("Preset Name", text: $viewModel.presetNameDraft)

                Picker("Saved Preset", selection: $viewModel.selectedPresetName) {
                    Text("Select a preset").tag("")
                    ForEach(viewModel.presets) { preset in
                        Text(preset.name).tag(preset.name)
                    }
                }

                HStack {
                    Button("Save Current as Preset") {
                        viewModel.saveCurrentAsPreset()
                    }
                    .disabled(!viewModel.canSavePreset)

                    Button("Apply Preset") {
                        viewModel.applySelectedPreset()
                    }
                    .disabled(!viewModel.hasPresets || viewModel.selectedPreset == nil)

                    Button("Delete Preset") {
                        viewModel.deleteSelectedPreset()
                    }
                    .disabled(!viewModel.hasPresets || viewModel.selectedPreset == nil)
                }

                if !viewModel.hasPresets {
                    EmptyStateText("No presets saved yet. Save the current form when you have a setup you want to reuse.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CodexHandoffStatusView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Codex Handoff") {
            if let message = viewModel.codexHandoffMessage {
                Text(message)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                EmptyStateText("Use Open in Codex from the last created project or a recent project to copy the starter prompt and open the folder for the next session.")
            }
        }
    }
}

private struct RecentProjectsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Recent Projects") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Recently created real projects are kept here for quick reuse across sessions.")
                    .foregroundStyle(.secondary)

                if viewModel.hasRecentProjects {
                    ForEach(viewModel.recentProjects) { project in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(project.projectName)
                                        .fontWeight(.medium)
                                    Text(project.path)
                                        .textSelection(.enabled)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(project.createdAtDisplayText)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Template: \(project.template.rawValue)")
                            Text("Git: \(project.gitInitialized ? "Ready" : "Needs attention")")
                            Text("GitHub: \(project.gitHubStatus.displayText)")

                            HStack {
                                Button("Open in Codex") {
                                    viewModel.openRecentProjectInCodex(project)
                                }

                                Button("Copy Path") {
                                    viewModel.copyRecentProjectPath(project)
                                }

                                Button("Open in Finder") {
                                    viewModel.openRecentProjectInFinder(project)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    EmptyStateText("No recent projects yet. Real project creations will appear here after generation completes.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PromptPackView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Codex Prompt Pack") {
            if viewModel.hasPromptPack, let selectedPrompt = viewModel.selectedPrompt {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Use these template-aware prompts after a real project has been created.")
                        .foregroundStyle(.secondary)

                    Picker("Prompt", selection: $viewModel.selectedPromptKind) {
                        ForEach(viewModel.availablePromptPack) { prompt in
                            Text(prompt.title).tag(prompt.kind)
                        }
                    }

                    Text(selectedPrompt.body)
                        .textSelection(.enabled)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Button("Copy Prompt") {
                            viewModel.copySelectedPrompt()
                        }

                        Button("Copy Starter Prompt") {
                            viewModel.copyLastCreatedCodexStarterPrompt()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                EmptyStateText("No prompt pack yet. Create a real project first to unlock template-aware Codex prompts.")
            }
        }
    }
}

private struct IntegrationStatusView: View {
    let label: String
    let status: ProjectIntegrationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .fontWeight(.medium)

            HStack(spacing: 8) {
                Image(systemName: status.systemImageName)
                    .foregroundStyle(statusColor)
                Text(status.label)
                    .fontWeight(.medium)
            }

            Text(status.shortDetail)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch status.colorName {
        case "success":
            return .green
        case "skipped":
            return .orange
        case "failed":
            return .red
        default:
            return .secondary
        }
    }
}

private struct ProjectSummaryView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Project Summary") {
            if let summary = viewModel.lastCreatedSummary {
                VStack(alignment: .leading, spacing: 14) {
                    summaryRow(label: "Project", value: summary.projectName)
                    summaryRow(label: "Path", value: summary.finalProjectURL.path, selectable: true)
                    summaryRow(label: "Template", value: summary.template.rawValue)

                    HStack(alignment: .top, spacing: 24) {
                        IntegrationStatusView(label: "Git", status: summary.gitStatus)
                        IntegrationStatusView(label: "GitHub", status: summary.gitHubStatus)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workflow Files")
                            .fontWeight(.medium)
                        ForEach(summary.workflowFiles, id: \.self) { file in
                            Text(file)
                        }
                    }

                    HStack {
                        Button("Copy Summary") {
                            viewModel.copyLastCreatedSummary()
                        }

                        Button("Copy File Tree") {
                            viewModel.copyLastCreatedFileTree()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                EmptyStateText("No project summary yet. Create a real project to see the final path, template, integration status, and workflow files here.")
            }
        }
    }

    private func summaryRow(label: String, value: String, selectable: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .fontWeight(.medium)
            if selectable {
                Text(value)
                    .textSelection(.enabled)
            } else {
                Text(value)
            }
        }
    }

}

private struct PostCreateActionsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Last Created Project") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Use these actions after a real project has been created.")
                    .foregroundStyle(.secondary)

                Text(viewModel.lastCreatedProjectPath)
                    .textSelection(.enabled)
                    .foregroundStyle(viewModel.hasLastCreatedProject ? .primary : .secondary)

                HStack {
                    Button("Open in Codex") {
                        viewModel.openLastCreatedProjectInCodex()
                    }
                    .disabled(!viewModel.hasLastCreatedProject)

                    Button("Open in Finder") {
                        viewModel.openLastCreatedProjectInFinder()
                    }
                    .disabled(!viewModel.hasLastCreatedProject)

                    Button("Copy Project Path") {
                        viewModel.copyLastCreatedProjectPath()
                    }
                    .disabled(!viewModel.hasLastCreatedProject)

                    Button("Open in Terminal") {
                        viewModel.openLastCreatedProjectInTerminal()
                    }
                    .disabled(!viewModel.hasLastCreatedProject)

                    Button("Copy Starter Prompt") {
                        viewModel.copyLastCreatedCodexStarterPrompt()
                    }
                    .disabled(!viewModel.hasLastCreatedProject)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct NewProjectFormView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("New Project") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Required fields: project name and base directory. Everything else can be adjusted later.")
                    .foregroundStyle(.secondary)

                TextField("Project Name", text: $viewModel.settings.projectName)

                HStack(alignment: .center, spacing: 12) {
                    TextField("Base Directory", text: $viewModel.settings.baseDirectory)

                    Button("Choose Folder") {
                        viewModel.chooseBaseDirectory()
                    }
                }

                TextField("GitHub Username", text: $viewModel.settings.gitHubUsername)

                Picker("Repo Visibility", selection: $viewModel.settings.repoVisibility) {
                    ForEach(RepoVisibility.allCases) { visibility in
                        Text(visibility.rawValue).tag(visibility)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Template", selection: $viewModel.settings.template) {
                    ForEach(ProjectTemplate.allCases) { template in
                        Text(template.rawValue).tag(template)
                    }
                }

                Toggle("Dry Run", isOn: $viewModel.dryRunEnabled)

                HStack {
                    Button("Preview Plan") {
                        viewModel.previewProject()
                    }
                    .disabled(!viewModel.canPreviewOrCreateProject)

                    Spacer()
                    Button(viewModel.dryRunEnabled ? "Run Dry Preview" : "Create Project") {
                        viewModel.createProject()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canPreviewOrCreateProject)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct EmptyStateText: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
