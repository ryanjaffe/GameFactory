import Foundation

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

final class AppLogger {
    private(set) var entries: [LogEntry] = []

    @discardableResult
    func log(_ message: String) -> LogEntry {
        let entry = LogEntry(timestamp: Date(), message: message)
        entries.append(entry)
        return entry
    }
}
