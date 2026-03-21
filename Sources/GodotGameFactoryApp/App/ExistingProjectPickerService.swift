import AppKit
import Foundation

struct ExistingProjectPickerService {
    private let picker: () -> URL?

    init(picker: @escaping () -> URL? = ExistingProjectPickerService.defaultPicker) {
        self.picker = picker
    }

    func chooseProjectFolder() -> URL? {
        picker()
    }

    private static func defaultPicker() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Open Existing Project"
        panel.prompt = "Open Project"
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
