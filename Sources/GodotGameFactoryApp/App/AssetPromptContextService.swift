import Foundation

struct AssetPromptContextService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func assetSummary(for projectURL: URL) -> String {
        inventorySummary(for: projectURL).promptSummaryText
    }

    func inventorySummary(for projectURL: URL) -> AssetInventorySummary {
        let artDirectoryURL = projectURL.appendingPathComponent("art", isDirectory: true)
        guard fileManager.fileExists(atPath: artDirectoryURL.path) else {
            return AssetInventorySummary(relativePaths: [])
        }

        let assetFiles = enumeratedAssetFiles(in: artDirectoryURL, relativeTo: projectURL)
        return AssetInventorySummary(relativePaths: assetFiles)
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

struct AssetInventorySummary {
    let relativePaths: [String]

    var hasAssets: Bool {
        !relativePaths.isEmpty
    }

    var totalFileCount: Int {
        relativePaths.count
    }

    var groupedCounts: [(name: String, count: Int)] {
        Dictionary(grouping: relativePaths) { relativePath in
            let components = relativePath.split(separator: "/")
            if components.count >= 3 {
                return String(components[1])
            }
            return "art root"
        }
        .map { key, values in (name: key, count: values.count) }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.name < rhs.name
            }
            return lhs.count > rhs.count
        }
    }

    var representativePaths: [String] {
        Array(relativePaths.prefix(3))
    }

    var promptSummaryText: String {
        guard hasAssets else {
            return "Imported assets: none detected under `art/`."
        }

        let groupSummary = groupedCounts.prefix(3)
            .map { "`\($0.name)` (\($0.count))" }
            .joined(separator: ", ")
        let samplePaths = representativePaths.map { "`\($0)`" }.joined(separator: ", ")
        return "Imported assets: \(totalFileCount) file(s) under `art/`; groups: \(groupSummary); examples: \(samplePaths)."
    }

    var bundleSummaryText: String {
        guard hasAssets else {
            return "Assets: none detected under `art/`."
        }

        let groups = groupedCounts.prefix(3)
            .map { "\($0.name) (\($0.count))" }
            .joined(separator: ", ")
        let examples = representativePaths.joined(separator: ", ")

        return """
        Assets: \(totalFileCount) file(s) under art/
        Groups: \(groups)
        Representative paths: \(examples)
        """
    }
}
