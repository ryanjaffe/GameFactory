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
            VStack(alignment: .leading, spacing: 20) {
                Text("Godot Game Factory")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("Configure a new project. Use Dry Run or Preview Plan to inspect exactly what would happen before any files are written.")
                    .foregroundStyle(.secondary)

                NewProjectFormView(viewModel: viewModel)
                ProjectSummaryView(viewModel: viewModel)
                PromptPackView(viewModel: viewModel)
                PostCreateActionsView(viewModel: viewModel)
                CodexHandoffStatusView(viewModel: viewModel)
                RecentProjectsView(viewModel: viewModel)

                LogPanelView(entries: viewModel.logEntries)
            }
            .padding(24)
        }
    }
}

private struct CodexHandoffStatusView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if let message = viewModel.codexHandoffMessage {
            GroupBox("Codex Handoff") {
                Text(message)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct RecentProjectsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if viewModel.hasRecentProjects {
            GroupBox("Recent Projects") {
                VStack(alignment: .leading, spacing: 14) {
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
                            Text("Git: \(project.gitInitialized ? "Ready" : "Not initialized")")
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct PromptPackView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        if viewModel.hasPromptPack, let selectedPrompt = viewModel.selectedPrompt {
            GroupBox("Codex Prompt Pack") {
                VStack(alignment: .leading, spacing: 14) {
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
        if let summary = viewModel.lastCreatedSummary {
            GroupBox("Project Summary") {
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

                    Button("Copy Codex Starter Prompt") {
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

                    Spacer()
                    Button(viewModel.dryRunEnabled ? "Run Dry Preview" : "Create Project") {
                        viewModel.createProject()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
