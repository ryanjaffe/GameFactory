import Foundation

struct AssetPromptContextService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func assetSummary(for projectURL: URL) -> String {
        let artDirectoryURL = projectURL.appendingPathComponent("art", isDirectory: true)
        guard fileManager.fileExists(atPath: artDirectoryURL.path) else {
            return "Imported assets: none detected under `art/`."
        }

        let assetFiles = enumeratedAssetFiles(in: artDirectoryURL, relativeTo: projectURL)
        guard !assetFiles.isEmpty else {
            return "Imported assets: none detected under `art/`."
        }

        let groupSummary = assetGroupSummary(for: assetFiles)
        let samplePaths = assetFiles.prefix(3).map { "`\($0)`" }.joined(separator: ", ")

        return "Imported assets: \(assetFiles.count) file(s) under `art/`; groups: \(groupSummary); examples: \(samplePaths)."
    }

    private func enumeratedAssetFiles(in artDirectoryURL: URL, relativeTo projectURL: URL) -> [String] {
        guard let enumerator = fileManager.enumerator(
            at: artDirectoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [String] = []
        let resolvedArtDirectoryURL = artDirectoryURL.resolvingSymlinksInPath()
        let artPathComponents = resolvedArtDirectoryURL.pathComponents

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else {
                continue
            }

            let resolvedFileURL = fileURL.resolvingSymlinksInPath()
            let filePathComponents = resolvedFileURL.pathComponents
            let relativeComponents = filePathComponents.dropFirst(artPathComponents.count)
            let relativePath = (["art"] + relativeComponents).joined(separator: "/")
            files.append(relativePath)
        }

        return files.sorted()
    }

    private func assetGroupSummary(for relativePaths: [String]) -> String {
        let groupedCounts = Dictionary(grouping: relativePaths) { relativePath in
            let components = relativePath.split(separator: "/")
            if components.count >= 3 {
                return String(components[1])
            }
            return "art root"
        }
        .map { key, values in (key: key, count: values.count) }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.key < rhs.key
            }
            return lhs.count > rhs.count
        }

        return groupedCounts.prefix(3)
            .map { "`\($0.key)` (\($0.count))" }
            .joined(separator: ", ")
    }
}
