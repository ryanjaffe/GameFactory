import Foundation

struct AssetImportSummary {
    let projectURL: URL
    let destinationDirectoryURL: URL
    let importedFiles: [ImportedAsset]
    let sourceKind: AssetImportSourceKind

    var summaryText: String {
        let importedList = importedFiles.map { "- \($0.destinationURL.lastPathComponent)" }.joined(separator: "\n")

        return """
        Asset Import Summary

        Project: \(projectURL.lastPathComponent)
        Destination: \(destinationDirectoryURL.path)
        Source: \(sourceKind.displayText)
        Imported files:
        \(importedList)
        """
    }

    var recentImportText: String {
        let recentNames = importedFiles.prefix(3).map { $0.destinationURL.lastPathComponent }.joined(separator: ", ")
        let remainderCount = max(0, importedFiles.count - 3)
        let suffix = remainderCount > 0 ? " (+\(remainderCount) more)" : ""
        return "Recent imports: \(recentNames)\(suffix)"
    }
}

struct ImportedAsset: Identifiable, Equatable {
    let sourceURL: URL
    let destinationURL: URL

    var id: String { destinationURL.path }
}

enum AssetImportSourceKind: Equatable {
    case manualFiles
    case starterPack(String)

    var displayText: String {
        switch self {
        case .manualFiles:
            return "Manual import"
        case let .starterPack(title):
            return "Starter pack: \(title)"
        }
    }
}
