import AppKit
import Foundation

struct FolderPickerService {
    private let picker: () -> URL?

    init(picker: @escaping () -> URL? = FolderPickerService.defaultPicker) {
        self.picker = picker
    }

    func chooseFolder() -> URL? {
        picker()
    }

    private static func defaultPicker() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Base Directory"
        panel.prompt = "Choose Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.urls.first
    }
}
