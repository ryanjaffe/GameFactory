import Foundation

struct AssetImportSummary {
    let projectURL: URL
    let destinationDirectoryURL: URL
    let importedFiles: [ImportedAsset]

    var summaryText: String {
        let importedList = importedFiles.map { "- \($0.destinationURL.lastPathComponent)" }.joined(separator: "\n")

        return """
        Asset Import Summary

        Project: \(projectURL.lastPathComponent)
        Destination: \(destinationDirectoryURL.path)
        Imported files:
        \(importedList)
        """
    }
}

struct ImportedAsset: Identifiable, Equatable {
    let sourceURL: URL
    let destinationURL: URL

    var id: String { destinationURL.path }
}
