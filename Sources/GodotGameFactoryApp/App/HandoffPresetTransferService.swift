import AppKit
import Foundation
import UniformTypeIdentifiers

struct HandoffPresetTransferService {
    private let openPanelPicker: () -> URL?
    private let savePanelPicker: () -> URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        openPanelPicker: @escaping () -> URL? = HandoffPresetTransferService.defaultOpenPanelPicker,
        savePanelPicker: @escaping () -> URL? = HandoffPresetTransferService.defaultSavePanelPicker
    ) {
        self.openPanelPicker = openPanelPicker
        self.savePanelPicker = savePanelPicker
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    func exportPresets(_ presets: [SavedHandoffPreset]) throws -> URL? {
        guard let destinationURL = savePanelPicker() else {
            return nil
        }

        let data = try encoder.encode(presets)
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    func importPresets() throws -> [SavedHandoffPreset]? {
        guard let sourceURL = openPanelPicker() else {
            return nil
        }

        let data = try Data(contentsOf: sourceURL)
        return try decoder.decode([SavedHandoffPreset].self, from: data)
    }

    private static func defaultOpenPanelPicker() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Import Handoff Presets"
        panel.prompt = "Import"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.urls.first
    }

    private static func defaultSavePanelPicker() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Handoff Presets"
        panel.prompt = "Export"
        panel.nameFieldStringValue = "handoff-bundle-presets.json"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}
