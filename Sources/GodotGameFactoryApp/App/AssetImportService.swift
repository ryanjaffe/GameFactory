import Foundation

struct AssetImportService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func importAssets(from sourceURLs: [URL], into projectURL: URL) throws -> AssetImportSummary {
        let destinationDirectoryURL = projectURL.appendingPathComponent("art", isDirectory: true)
        try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)

        var importedFiles: [ImportedAsset] = []

        for sourceURL in sourceURLs {
            let destinationURL = availableDestinationURL(for: sourceURL, in: destinationDirectoryURL)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            importedFiles.append(ImportedAsset(sourceURL: sourceURL, destinationURL: destinationURL))
        }

        return AssetImportSummary(
            projectURL: projectURL,
            destinationDirectoryURL: destinationDirectoryURL,
            importedFiles: importedFiles
        )
    }

    func importGeneratedAssets(_ files: [GeneratedAssetFile], into projectURL: URL) throws -> AssetImportSummary {
        let destinationDirectoryURL = projectURL.appendingPathComponent("art", isDirectory: true)
        try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)

        var importedFiles: [ImportedAsset] = []

        for file in files {
            let requestedDestinationURL = destinationDirectoryURL.appendingPathComponent(file.relativePath)
            let parentDirectoryURL = requestedDestinationURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: parentDirectoryURL, withIntermediateDirectories: true)

            let destinationURL = availableDestinationURL(for: requestedDestinationURL, in: parentDirectoryURL)
            try file.contents.write(to: destinationURL, atomically: true, encoding: .utf8)
            importedFiles.append(
                ImportedAsset(
                    sourceURL: destinationURL,
                    destinationURL: destinationURL
                )
            )
        }

        return AssetImportSummary(
            projectURL: projectURL,
            destinationDirectoryURL: destinationDirectoryURL,
            importedFiles: importedFiles
        )
    }

    private func availableDestinationURL(for sourceURL: URL, in directoryURL: URL) -> URL {
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        var candidateURL = directoryURL.appendingPathComponent(sourceURL.lastPathComponent)

        guard fileManager.fileExists(atPath: candidateURL.path) else {
            return candidateURL
        }

        var suffix = 2
        while true {
            let candidateName = fileExtension.isEmpty
                ? "\(originalName) \(suffix)"
                : "\(originalName) \(suffix).\(fileExtension)"
            candidateURL = directoryURL.appendingPathComponent(candidateName)

            if !fileManager.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }

            suffix += 1
        }
    }
}

struct GeneratedAssetFile {
    let relativePath: String
    let contents: String
}
