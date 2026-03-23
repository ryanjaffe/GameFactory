import SwiftUI

struct MainView: View {
    private enum SidebarSection: String, CaseIterable, Identifiable {
        case newProject
        case settings
        case logs

        var id: String { rawValue }

        var title: String {
            switch self {
            case .newProject:
                return "New Project"
            case .settings:
                return "Settings"
            case .logs:
                return "Logs"
            }
        }

        var systemImageName: String {
            switch self {
            case .newProject:
                return "hammer"
            case .settings:
                return "gearshape"
            case .logs:
                return "text.append"
            }
        }

        var description: String {
            switch self {
            case .newProject:
                return "Create projects, reuse presets, and continue recent work."
            case .settings:
                return "Inspect, audit, edit workflow files, and manage project tools."
            case .logs:
                return "Review the latest app activity and automation output."
            }
        }
    }

    @ObservedObject var viewModel: AppViewModel
    @State private var selectedSection: SidebarSection = .newProject

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(SidebarSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Label(section.title, systemImage: section.systemImageName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedSection == section ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .frame(minWidth: 180, idealWidth: 200, maxWidth: 220, maxHeight: .infinity, alignment: .topLeading)
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(selectedSection.title)
                        .font(.largeTitle)
                        .fontWeight(.semibold)

                    Text(selectedSection.description)
                        .foregroundStyle(.secondary)

                    switch selectedSection {
                    case .newProject:
                        PresetsView(viewModel: viewModel)
                        NewProjectFormView(viewModel: viewModel)
                        ProjectSummaryView(viewModel: viewModel)
                        PromptPackView(viewModel: viewModel)
                        PostCreateActionsView(viewModel: viewModel)
                        CodexHandoffStatusView(viewModel: viewModel)
                        RecentProjectsView(viewModel: viewModel)
                    case .settings:
                        SettingsActiveProjectView(viewModel: viewModel)
                        ProjectInspectorView(viewModel: viewModel)
                        ProjectAuditView(viewModel: viewModel)
                        AssetImportView(viewModel: viewModel)
                        AssetStarterPacksView(viewModel: viewModel)
                        HandoffBundleView(viewModel: viewModel)
                        WorkflowFilesView(viewModel: viewModel)
                        WorkflowSettingsView(viewModel: viewModel)
                    case .logs:
                        LogPanelView(searchText: $viewModel.logSearchText, entries: viewModel.filteredLogEntries)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct AssetStarterPacksView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Asset Starter Packs") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Add a small built-in placeholder pack to the active project. Files are copied into `art/` using the same safe naming rules as manual imports.")
                    .foregroundStyle(.secondary)

                if let activeProjectURL = viewModel.activeProjectURL {
                    ActiveProjectContextView(
                        label: viewModel.activeProjectContextLabel,
                        name: viewModel.activeProjectName,
                        path: activeProjectURL.path,
                        detail: viewModel.activeProjectContextDetailText
                    )

                    if let status = viewModel.assetImportStatus {
                        InlineStatusMessageView(status: status)
                    }

                    ForEach(viewModel.assetStarterPacks) { pack in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(pack.title)
                                .fontWeight(.medium)
                            Text(pack.description)
                                .foregroundStyle(.secondary)

                            if !viewModel.starterPackValidationIssues(for: pack).isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(viewModel.starterPackValidationIssues(for: pack), id: \.self) { issue in
                                        Text("• \(issue)")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Button("Apply \(pack.title)") {
                                viewModel.applyAssetStarterPack(pack)
                            }
                            .disabled(!viewModel.canApplyStarterPack(pack))
                        }
                    }
                } else {
                    ActiveProjectRequiredEmptyState()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HandoffBundleView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Handoff Bundle") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Copy a concise handoff package with summary, file tree, audit state, starter prompt, and asset/import context when available.")
                    .foregroundStyle(.secondary)

                if let activeProjectURL = viewModel.activeProjectURL {
                    ActiveProjectContextView(
                        label: viewModel.activeProjectContextLabel,
                        name: viewModel.activeProjectName,
                        path: activeProjectURL.path,
                        detail: viewModel.activeProjectContextDetailText
                    )

                    Picker(
                        "Mode",
                        selection: Binding(
                            get: { viewModel.selectedHandoffBundleMode },
                            set: { viewModel.applyHandoffBundleMode($0) }
                        )
                    ) {
                        ForEach(HandoffBundleMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Toggle("Include Project Session Notes", isOn: $viewModel.includeProjectSessionNotesInHandoff)
                    Toggle("Include Recent Activity", isOn: $viewModel.includeRecentActivityInHandoff)

                    if viewModel.includeRecentActivityInHandoff {
                        Stepper(
                            "Entries: \(viewModel.recentActivityInHandoffLimit)",
                            value: $viewModel.recentActivityInHandoffLimit,
                            in: 1...10
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bundle Preview")
                            .fontWeight(.medium)

                        ForEach(viewModel.handoffBundlePreviewItems) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .fontWeight(.medium)
                                Text(item.detail)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button("Copy Handoff Bundle") {
                        viewModel.copyHandoffBundle()
                    }

                    if let status = viewModel.handoffBundleStatus {
                        InlineStatusMessageView(status: status)
                    }
                } else {
                    ActiveProjectRequiredEmptyState()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AssetImportView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Asset Import") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Copy selected files into the active project's `art/` directory. Originals stay untouched.")
                    .foregroundStyle(.secondary)

                if let activeProjectURL = viewModel.activeProjectURL {
                    ActiveProjectContextView(
                        label: viewModel.activeProjectContextLabel,
                        name: viewModel.activeProjectName,
                        path: activeProjectURL.path,
                        detail: viewModel.activeProjectContextDetailText
                    )

                    Button("Import Assets") {
                        viewModel.importAssets()
                    }

                    if let status = viewModel.assetImportStatus {
                        InlineStatusMessageView(status: status)
                    }

                    if let summary = viewModel.lastAssetImport {
                        Text(summary.summaryText)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)

                        ForEach(summary.importedFiles) { importedFile in
                            Text(importedFile.destinationURL.lastPathComponent)
                        }
                    } else {
                        EmptyStateText("No imported assets yet for this active project.")
                    }
                } else {
                    ActiveProjectRequiredEmptyState()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ProjectInspectorView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Project Inspector") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Open an existing project folder to inspect it, check the key workflow files, and make it the active project when needed.")
                    .foregroundStyle(.secondary)

                Button("Open Existing Project") {
                    viewModel.openExistingProject()
                }

                if let summary = viewModel.inspectedProjectSummary {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(summary.validationMessage)
                            .foregroundStyle(summary.isValidProject ? Color.secondary : Color.orange)

                        inspectorRow(label: "Project", value: summary.projectName)
                        inspectorRow(label: "Path", value: summary.projectURL.path, selectable: true)
                        inspectorRow(label: "Template", value: summary.templateDisplayName)
                        inspectorRow(label: "project.godot", value: yesNo(summary.hasProjectGodot))
                        inspectorRow(label: "AGENTS.md", value: yesNo(summary.hasAgentsFile))
                        inspectorRow(label: "README.md", value: yesNo(summary.hasReadmeFile))
                        inspectorRow(label: "run_validation.sh", value: yesNo(summary.hasValidationScript))
                        inspectorRow(label: ".git", value: yesNo(summary.hasGitDirectory))
                        inspectorRow(label: "Origin", value: summary.originRemoteStatus.displayText, selectable: summary.originRemoteStatus.detailText != nil)

                        if let originDetail = summary.originRemoteStatus.detailText {
                            Text(originDetail)
                                .textSelection(.enabled)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Directories")
                                .fontWeight(.medium)
                            Text("scenes/: \(yesNo(summary.hasScenesDirectory))")
                            Text("scripts/: \(yesNo(summary.hasScriptsDirectory))")
                            Text("art/: \(yesNo(summary.hasArtDirectory))")
                            Text("tests/: \(yesNo(summary.hasTestsDirectory))")
                            Text("artifacts/: \(yesNo(summary.hasArtifactsDirectory))")
                        }

                        HStack {
                            Button("Use as Active Project") {
                                viewModel.useInspectedProjectForWorkflowFiles()
                            }
                            .disabled(!summary.isValidProject)

                            Button("Open in Godot") {
                                viewModel.openInspectedProjectInGodot()
                            }
                            .disabled(!summary.isValidProject)

                            Button("Open in Codex") {
                                viewModel.openInspectedProjectInCodex()
                            }
                            .disabled(!summary.isValidProject)
                        }

                        HStack {
                            Button("Copy Summary") {
                                viewModel.copyInspectedProjectSummary()
                            }

                            Button("Copy File Tree") {
                                viewModel.copyInspectedProjectFileTree()
                            }
                        }
                    }
                } else {
                    EmptyStateText("No existing project inspected yet. Choose a folder to see whether it looks like a Godot project and to reuse the current workflow tools.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inspectorRow(label: String, value: String, selectable: Bool = false) -> some View {
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

    private func yesNo(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }
}

private struct ProjectAuditView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Project Audit") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Run a quick health check for the active project and review the current workflow readiness.")
                    .foregroundStyle(.secondary)

                Button("Run Audit") {
                    viewModel.runProjectAudit()
                }
                .disabled(viewModel.activeProjectURL == nil)

                if let activeProjectURL = viewModel.activeProjectURL {
                    ActiveProjectContextView(
                        label: viewModel.activeProjectContextLabel,
                        name: viewModel.activeProjectName,
                        path: activeProjectURL.path,
                        detail: viewModel.activeProjectContextDetailText
                    )
                }

                if let audit = viewModel.lastProjectAudit {
                    Text(audit.summaryText)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)

                    ForEach(audit.checks) { check in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: check.status.systemImageName)
                                .foregroundStyle(statusColor(for: check.status))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(check.title)
                                    .fontWeight(.medium)
                                Text(check.status.rawValue)
                                    .foregroundStyle(.secondary)
                                Text(check.detail)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if viewModel.activeProjectURL == nil {
                    ActiveProjectRequiredEmptyState()
                } else {
                    EmptyStateText("No audit run yet. Run the audit to check whether the active project still looks healthy and Codex-ready.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusColor(for status: ProjectAuditStatus) -> Color {
        switch status {
        case .pass:
            return .green
        case .warn:
            return .orange
        case .fail:
            return .red
        case .skipped:
            return .secondary
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
                Text("Real project creations stay here for quick reopen, reuse, and handoff across sessions.")
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
                                Button("Use as Active Project") {
                                    viewModel.selectRecentProjectForWorkflowFiles(project)
                                }

                                Button("Open in Godot") {
                                    viewModel.openRecentProjectInGodot(project)
                                }

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
            if let activeProjectURL = viewModel.activeProjectURL, viewModel.hasPromptPack {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Use these template-aware prompts for the active project. Imported asset context is included when files are available under `art/`.")
                        .foregroundStyle(.secondary)

                    ActiveProjectContextView(
                        label: viewModel.activeProjectContextLabel,
                        name: viewModel.activeProjectName,
                        path: activeProjectURL.path,
                        detail: viewModel.activeProjectContextDetailText
                    )

                    Picker("Prompt", selection: $viewModel.selectedPromptKind) {
                        ForEach(viewModel.availablePromptPack) { prompt in
                            Text(prompt.title).tag(prompt.kind)
                        }
                    }

                    Picker(
                        "Preset",
                        selection: Binding(
                            get: { viewModel.selectedPromptPreset },
                            set: { viewModel.applyPromptPreset($0) }
                        )
                    ) {
                        ForEach(PromptPackPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saved Presets")
                            .fontWeight(.medium)

                        TextField("Preset Name", text: $viewModel.promptPresetNameDraft)

                        HStack {
                            Button("Save Preset") {
                                viewModel.saveCurrentPromptPreset(named: viewModel.promptPresetNameDraft)
                            }
                            .disabled(!viewModel.canSavePromptPreset)

                            Button("Export Presets") {
                                viewModel.exportSavedPromptPresets()
                            }

                            Button("Import Presets") {
                                viewModel.importSavedPromptPresets()
                            }

                            Picker("Saved", selection: $viewModel.selectedSavedPromptPresetID) {
                                Text("Select a saved preset").tag("")
                                ForEach(viewModel.savedPromptPresets) { preset in
                                    Text(preset.name).tag(preset.id)
                                }
                            }

                            Button("Apply") {
                                if let preset = viewModel.selectedSavedPromptPreset {
                                    viewModel.applySavedPromptPreset(preset)
                                }
                            }
                            .disabled(viewModel.selectedSavedPromptPreset == nil)

                            Button("Delete") {
                                if let preset = viewModel.selectedSavedPromptPreset {
                                    viewModel.deleteSavedPromptPreset(preset)
                                }
                            }
                            .disabled(viewModel.selectedSavedPromptPreset == nil)
                        }
                    }

                    Picker("Mode", selection: $viewModel.selectedPromptMode) {
                        ForEach(PromptPackMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Include")
                            .fontWeight(.medium)

                        Toggle("Project Summary", isOn: $viewModel.includeProjectSummary)
                        Toggle("Workflow Files", isOn: $viewModel.includeWorkflowFiles)
                        Toggle("Starter Context", isOn: $viewModel.includeStarterContext)
                        Toggle("Notes / Context", isOn: $viewModel.includeNotesOrContext)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Context")
                            .fontWeight(.medium)

                        TextEditor(text: $viewModel.promptCustomContextText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 90)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Project Session Notes")
                            .fontWeight(.medium)

                        TextEditor(text: $viewModel.projectSessionNotesText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 90)

                        HStack {
                            Button("Save Notes") {
                                viewModel.saveProjectSessionNotesForActiveProject()
                            }

                            Button("Clear Notes") {
                                viewModel.clearProjectSessionNotesForActiveProject()
                            }
                            .disabled(viewModel.projectSessionNotesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Include Recent Activity", isOn: $viewModel.includeRecentActivityContext)

                        if viewModel.includeRecentActivityContext {
                            Stepper(
                                "Entries: \(viewModel.recentActivityContextLimit)",
                                value: $viewModel.recentActivityContextLimit,
                                in: 1...10
                            )
                        }
                    }

                    Toggle("Include Project Session Notes", isOn: $viewModel.includeProjectSessionNotes)

                    HStack {
                        Button("Generate Preview") {
                            viewModel.generatePromptPreview()
                        }

                        Button("Copy Prompt") {
                            viewModel.copySelectedPrompt()
                        }

                        Button("Copy Starter Prompt") {
                            viewModel.copyActiveCodexStarterPrompt()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .fontWeight(.medium)

                        if viewModel.hasPromptPreview {
                            HStack(spacing: 12) {
                                Text("Characters: \(viewModel.previewCharacterCount)")
                                Text("Lines: \(viewModel.previewLineCount)")
                                Text("Words: \(viewModel.previewWordCount)")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            if let warning = viewModel.promptPreviewSizeWarning {
                                Text(warning)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        ScrollView {
                            if viewModel.hasPromptPreview {
                                Text(viewModel.promptPackPreviewText)
                                    .textSelection(.enabled)
                                    .font(.system(.callout, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                EmptyStateText("No preview generated yet. Choose a mode and sections, then click Generate Preview.")
                            }
                        }
                        .frame(minHeight: 180)
                    }

                    if let status = viewModel.promptPackStatus {
                        InlineStatusMessageView(status: status)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Use these template-aware prompts for the active project. Imported asset context is included when files are available under `art/`.")
                        .foregroundStyle(.secondary)

                    if viewModel.activeProjectURL == nil {
                        ActiveProjectRequiredEmptyState()
                    } else {
                        EmptyStateText("No prompt pack is available for the current project yet.")
                    }
                }
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

private struct WorkflowSettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Workflow Settings") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Edit small project-local settings for validation, handoff, and launch behavior. Save writes `gamefactory.workflow.json`; Revert reloads it from disk.")
                    .foregroundStyle(.secondary)

                if let activeProjectURL = viewModel.activeProjectURL {
                    ActiveProjectContextView(
                        label: viewModel.activeProjectContextLabel,
                        name: viewModel.activeProjectName,
                        path: activeProjectURL.path,
                        detail: viewModel.activeProjectContextDetailText
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Config File")
                            .fontWeight(.medium)
                        Text(viewModel.workflowSettingsConfigPath)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                        Text(viewModel.workflowSettingsStatusMessage)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Validation Target Scene/Path", text: $viewModel.workflowSettingsValidationTarget)
                    TextField("Godot Path Override (Optional)", text: $viewModel.workflowSettingsGodotPathOverride)
                    TextField("Prompt Style / Handoff Note (Optional)", text: $viewModel.workflowSettingsHandoffNote)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Project Note (Optional)")
                            .fontWeight(.medium)
                        TextEditor(text: $viewModel.workflowSettingsProjectNote)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 100)
                    }

                    HStack {
                        Button("Save") {
                            viewModel.saveWorkflowSettings()
                        }
                        .disabled(!viewModel.canSaveWorkflowSettings)

                        Button("Revert") {
                            viewModel.revertWorkflowSettings()
                        }
                        .disabled(!viewModel.canRevertWorkflowSettings)

                        if viewModel.workflowSettingsHasUnsavedChanges {
                            Text("Unsaved changes")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ActiveProjectRequiredEmptyState()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WorkflowFilesView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Workflow Files") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Inspect, edit, and restore the key workflow files for the active project.")
                    .foregroundStyle(.secondary)

                if viewModel.hasWorkflowFileTarget {
                    ActiveProjectContextView(
                        label: viewModel.activeProjectContextLabel,
                        name: viewModel.workflowFileTargetProjectName,
                        path: viewModel.workflowFileTargetProjectPath,
                        detail: viewModel.activeProjectContextDetailText
                    )

                    HStack {
                        ForEach(WorkflowFileKind.allCases) { file in
                            Button("Open \(file.fileName)") {
                                viewModel.openWorkflowFile(file)
                            }
                        }
                    }

                    if let status = viewModel.workflowFileStatus {
                        InlineStatusMessageView(status: status)
                    }

                    if let selectedWorkflowFile = viewModel.selectedWorkflowFile {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(selectedWorkflowFile.fileName)
                                .fontWeight(.medium)
                            Text(viewModel.workflowEditorFilePath.isEmpty ? "No file selected." : viewModel.workflowEditorFilePath)
                                .textSelection(.enabled)
                                .foregroundStyle(.secondary)

                            if viewModel.workflowFileNotFound {
                                EmptyStateText("File not found. The file is missing on disk, so editing is disabled until it exists again.")
                            } else {
                                TextEditor(
                                    text: Binding(
                                        get: { viewModel.workflowEditorText },
                                        set: { viewModel.updateWorkflowEditorText($0) }
                                    )
                                )
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 220)
                                .disabled(!viewModel.canEditWorkflowFile)
                            }

                            HStack {
                                Button("Save") {
                                    viewModel.saveWorkflowFile()
                                }
                                .disabled(!viewModel.canSaveWorkflowFile)

                                Button("Revert") {
                                    viewModel.revertWorkflowFile()
                                }
                                .disabled(!viewModel.canRevertWorkflowFile)

                                Button(viewModel.workflowRepairActionTitle) {
                                    viewModel.repairSelectedWorkflowFile()
                                }
                                .disabled(!viewModel.canRepairSelectedWorkflowFile)

                                if viewModel.workflowFileHasUnsavedChanges {
                                    Text("Unsaved changes")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let pendingFileName = viewModel.pendingWorkflowRepairFileName {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Restore the default \(pendingFileName)? This will overwrite the current file on disk.")
                                        .foregroundStyle(.secondary)

                                    HStack {
                                        Button("Confirm Restore Default") {
                                            viewModel.repairSelectedWorkflowFile()
                                        }

                                        Button("Cancel") {
                                            viewModel.cancelWorkflowFileRepairConfirmation()
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        EmptyStateText("Open AGENTS.md, README.md, or run_validation.sh to inspect, edit, or restore it here.")
                    }
                } else {
                    ActiveProjectRequiredEmptyState()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct PostCreateActionsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Last Created Project") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Quick actions for the most recently created real project.")
                    .foregroundStyle(.secondary)

                Text(viewModel.lastCreatedProjectPath)
                    .textSelection(.enabled)
                    .foregroundStyle(viewModel.hasLastCreatedProject ? .primary : .secondary)

                HStack {
                    Button("Open in Godot") {
                        viewModel.openLastCreatedProjectInGodot()
                    }
                    .disabled(!viewModel.hasLastCreatedProject)

                    Button("Open in Codex") {
                        viewModel.openLastCreatedProjectInCodex()
                    }
                    .disabled(!viewModel.hasLastCreatedProject)

                    Button("Open in Finder") {
                        viewModel.openLastCreatedProjectInFinder()
                    }
                    .disabled(!viewModel.hasLastCreatedProject)

                    Button("Open in Terminal") {
                        viewModel.openLastCreatedProjectInTerminal()
                    }
                    .disabled(!viewModel.hasLastCreatedProject)
                }

                HStack {
                    Button("Copy Project Path") {
                        viewModel.copyLastCreatedProjectPath()
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

                TextField("Project Name", text: projectNameBinding)

                HStack(alignment: .center, spacing: 12) {
                    TextField("Base Directory", text: baseDirectoryBinding)

                    Button("Choose Folder") {
                        viewModel.chooseBaseDirectory()
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    TextField("Godot Path (Optional)", text: godotPathBinding)

                    Button("Choose App/Binary") {
                        viewModel.chooseGodotExecutablePath()
                    }
                }

                TextField("GitHub Username", text: gitHubUsernameBinding)

                Picker("Repo Visibility", selection: repoVisibilityBinding) {
                    ForEach(RepoVisibility.allCases) { visibility in
                        Text(visibility.rawValue).tag(visibility)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Template", selection: templateBinding) {
                    ForEach(ProjectTemplate.allCases) { template in
                        Text(template.rawValue).tag(template)
                    }
                }

                Toggle("Dry Run", isOn: $viewModel.dryRunEnabled)

                if !viewModel.createProjectValidationIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Before continuing:")
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)

                        ForEach(viewModel.createProjectValidationIssues, id: \.self) { issue in
                            Text("• \(issue)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    Button("Preview Plan") {
                        viewModel.previewProject()
                    }
                    .disabled(!viewModel.canCreateProject)

                    Spacer()
                    Button(viewModel.dryRunEnabled ? "Run Dry Preview" : "Create Project") {
                        viewModel.createProject()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canCreateProject)
                }

                if let status = viewModel.createProjectStatus {
                    InlineStatusMessageView(status: status)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var projectNameBinding: Binding<String> {
        Binding(
            get: { viewModel.settings.projectName },
            set: { viewModel.settings.projectName = $0 }
        )
    }

    private var baseDirectoryBinding: Binding<String> {
        Binding(
            get: { viewModel.settings.baseDirectory },
            set: { viewModel.settings.baseDirectory = $0 }
        )
    }

    private var godotPathBinding: Binding<String> {
        Binding(
            get: { viewModel.settings.godotExecutablePath },
            set: { viewModel.settings.godotExecutablePath = $0 }
        )
    }

    private var gitHubUsernameBinding: Binding<String> {
        Binding(
            get: { viewModel.settings.gitHubUsername },
            set: { viewModel.settings.gitHubUsername = $0 }
        )
    }

    private var repoVisibilityBinding: Binding<RepoVisibility> {
        Binding(
            get: { viewModel.settings.repoVisibility },
            set: { viewModel.settings.repoVisibility = $0 }
        )
    }

    private var templateBinding: Binding<ProjectTemplate> {
        Binding(
            get: { viewModel.settings.template },
            set: { viewModel.settings.template = $0 }
        )
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

private struct SettingsActiveProjectView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GroupBox("Current Project") {
            if let activeProjectURL = viewModel.activeProjectURL {
                VStack(alignment: .leading, spacing: 12) {
                    ActiveProjectContextView(
                        label: viewModel.activeProjectContextLabel,
                        name: viewModel.activeProjectName,
                        path: activeProjectURL.path,
                        detail: viewModel.activeProjectContextDetailText
                    )

                    HStack {
                        Button("Reveal in Finder") {
                            viewModel.revealActiveProjectInFinder()
                        }

                        Button("Copy Path") {
                            viewModel.copyActiveProjectPath()
                        }

                        Button("Copy Name") {
                            viewModel.copyActiveProjectName()
                        }
                    }

                    if let status = viewModel.activeProjectStatus {
                        InlineStatusMessageView(status: status)
                    }
                }
            } else {
                ActiveProjectRequiredEmptyState()
            }
        }
    }
}

private struct ActiveProjectRequiredEmptyState: View {
    var body: some View {
        EmptyStateText("An active project is required here. Create a new project, inspect an existing project, or select a recent project to continue.")
    }
}

private struct InlineStatusMessageView: View {
    let status: UIStatusMessage

    var body: some View {
        Text(status.text)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundColor)
            )
    }

    private var foregroundColor: Color {
        switch status.kind {
        case .success:
            return .green
        case .error:
            return .red
        }
    }

    private var backgroundColor: Color {
        switch status.kind {
        case .success:
            return Color.green.opacity(0.12)
        case .error:
            return Color.red.opacity(0.12)
        }
    }
}

private struct ActiveProjectContextView: View {
    let label: String
    let name: String
    let path: String
    let detail: String?

    init(label: String, name: String, path: String, detail: String? = nil) {
        self.label = label
        self.name = name
        self.path = path
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .fontWeight(.medium)
            Text(name)
                .fontWeight(.medium)
            if let detail {
                Text(detail)
                    .foregroundStyle(.secondary)
            }
            Text(path)
                .textSelection(.enabled)
                .foregroundStyle(.secondary)
        }
    }
}
