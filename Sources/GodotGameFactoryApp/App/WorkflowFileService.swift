import Foundation

struct WorkflowFileService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func fileURL(for kind: WorkflowFileKind, projectURL: URL) -> URL {
        projectURL.appendingPathComponent(kind.fileName)
    }

    func loadFile(_ kind: WorkflowFileKind, projectURL: URL) -> WorkflowFileLoadResult {
        let fileURL = fileURL(for: kind, projectURL: projectURL)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return WorkflowFileLoadResult(fileURL: fileURL, contents: nil, isMissing: true)
        }

        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            return WorkflowFileLoadResult(fileURL: fileURL, contents: contents, isMissing: false)
        } catch {
            return WorkflowFileLoadResult(fileURL: fileURL, contents: nil, isMissing: false)
        }
    }

    func saveFile(_ contents: String, kind: WorkflowFileKind, projectURL: URL) throws -> URL {
        let fileURL = fileURL(for: kind, projectURL: projectURL)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}

struct WorkflowFileLoadResult {
    let fileURL: URL
    let contents: String?
    let isMissing: Bool
}

enum WorkflowFileKind: String, CaseIterable, Identifiable {
    case agents
    case readme
    case validation

    var id: String { rawValue }

    var fileName: String {
        switch self {
        case .agents:
            return "AGENTS.md"
        case .readme:
            return "README.md"
        case .validation:
            return "run_validation.sh"
        }
    }
}
