import AppKit
import Foundation

struct GodotPathPickerService {
    private let picker: () -> URL?

    init(picker: @escaping () -> URL? = GodotPathPickerService.defaultPicker) {
        self.picker = picker
    }

    func chooseGodotExecutable() -> URL? {
        picker()
    }

    private static func defaultPicker() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Godot App or Binary"
        panel.prompt = "Choose"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.urls.first
    }
}
