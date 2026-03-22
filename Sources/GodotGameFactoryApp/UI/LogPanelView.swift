import SwiftUI

struct LogPanelView: View {
    @Binding var searchText: String
    let entries: [LogEntry]

    var body: some View {
        GroupBox("Log") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search log entries", text: $searchText)

                if entries.isEmpty {
                    Text(emptyStateMessage)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(entries) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(entry.message)
                                        .textSelection(.enabled)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 220)
                }
            }
        }
    }

    private var emptyStateMessage: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No log entries yet." : "No matching log entries."
    }
}
