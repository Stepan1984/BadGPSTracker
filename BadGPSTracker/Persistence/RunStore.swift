import Foundation

/// Local persistence for finished / in-progress sessions. No cloud sync in v1.
@MainActor
final class RunStore: ObservableObject {
    @Published private(set) var sessions: [RunSession] = []

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String = "run_sessions.json") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = docs.appendingPathComponent(filename)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            sessions = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try decoder.decode([RunSession].self, from: data)
                .sorted { $0.startedAt > $1.startedAt }
        } catch {
            sessions = []
        }
    }

    func upsert(_ session: RunSession) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx] = session
        } else {
            sessions.insert(session, at: 0)
        }
        persist()
    }

    func session(id: UUID) -> RunSession? {
        sessions.first { $0.id == id }
    }

    func delete(id: UUID) {
        sessions.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        do {
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Local-only MVP: swallow write errors; Session still holds in-memory state.
        }
    }
}
