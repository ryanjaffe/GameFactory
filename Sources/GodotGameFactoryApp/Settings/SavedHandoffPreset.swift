import Foundation

struct SavedHandoffPreset: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let selectedMode: HandoffBundleMode
    let includeProjectSessionNotes: Bool
    let includeRecentActivity: Bool
    let recentActivityLimit: Int

    init(
        id: String = UUID().uuidString,
        name: String,
        selectedMode: HandoffBundleMode,
        includeProjectSessionNotes: Bool,
        includeRecentActivity: Bool,
        recentActivityLimit: Int
    ) {
        self.id = id
        self.name = name
        self.selectedMode = selectedMode
        self.includeProjectSessionNotes = includeProjectSessionNotes
        self.includeRecentActivity = includeRecentActivity
        self.recentActivityLimit = max(1, min(recentActivityLimit, 10))
    }
}
