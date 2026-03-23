import Foundation

struct ProjectSessionNotesStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let notesKey = "GodotGameFactory.projectSessionNotes"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadNote(for projectKey: String) -> String {
        storedNotes()[projectKey] ?? ""
    }

    @discardableResult
    func saveNote(_ note: String, for projectKey: String) -> Bool {
        var notes = storedNotes()
        notes[projectKey] = note
        return save(notes)
    }

    @discardableResult
    func deleteNote(for projectKey: String) -> Bool {
        var notes = storedNotes()
        notes.removeValue(forKey: projectKey)
        return save(notes)
    }

    private func storedNotes() -> [String: String] {
        guard let data = defaults.data(forKey: notesKey) else {
            return [:]
        }

        guard let decoded = try? decoder.decode([String: String].self, from: data) else {
            return [:]
        }

        return decoded
    }

    @discardableResult
    private func save(_ notes: [String: String]) -> Bool {
        guard let data = try? encoder.encode(notes) else {
            return false
        }

        defaults.set(data, forKey: notesKey)
        return true
    }
}
