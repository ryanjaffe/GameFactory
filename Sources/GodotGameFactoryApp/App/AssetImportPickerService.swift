import AppKit
import Foundation

struct AssetImportPickerService {
    private let picker: () -> [URL]

    init(picker: @escaping () -> [URL] = AssetImportPickerService.defaultPicker) {
        self.picker = picker
    }

    func chooseFiles() -> [URL] {
        picker()
    }

    private static func defaultPicker() -> [URL] {
        let panel = NSOpenPanel()
        panel.title = "Import Assets"
        panel.prompt = "Import"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else {
            return []
        }

        return panel.urls
    }
}
