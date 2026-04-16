import Foundation
import Combine

class DataStore: ObservableObject {
    static let shared = DataStore()

    @Published var sessions: [SleepSession] = []
    @Published var currentSession: SleepSession?

    private let sessionsKey = "saved_sessions"

    private init() {
        load()
    }

    func startSession() -> SleepSession {
        let session = SleepSession()
        currentSession = session
        return session
    }

    func endSession(session: SleepSession, events: [SnoringEvent]) {
        var finished = session
        finished.endDate = Date()
        finished.snoringEvents = events
        sessions.insert(finished, at: 0)
        currentSession = nil
        save()
    }

    func delete(session: SleepSession) {
        sessions.removeAll { $0.id == session.id }
        // Clean up audio file if present
        if let url = session.audioFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        save()
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(sessions) {
            UserDefaults.standard.set(data, forKey: sessionsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey) else { return }
        let decoder = JSONDecoder()
        if let decoded = try? decoder.decode([SleepSession].self, from: data) {
            sessions = decoded
        }
    }

    // MARK: - Statistics

    var weeklyAverageSnoringPercentage: Double {
        let week = sessions.filter {
            $0.startDate > Date().addingTimeInterval(-7 * 86400)
        }
        guard !week.isEmpty else { return 0 }
        return week.map { $0.snoringPercentage }.reduce(0, +) / Double(week.count)
    }

    var weeklyAverageQuality: Double {
        let week = sessions.filter {
            $0.startDate > Date().addingTimeInterval(-7 * 86400)
        }
        guard !week.isEmpty else { return 0 }
        return week.map { Double($0.qualityScore) }.reduce(0, +) / Double(week.count)
    }

    var longestSnoringSession: SleepSession? {
        sessions.max(by: { $0.totalSnoringDuration < $1.totalSnoringDuration })
    }

    func sessionsForLastNDays(_ n: Int) -> [SleepSession] {
        let cutoff = Date().addingTimeInterval(Double(-n) * 86400)
        return sessions.filter { $0.startDate > cutoff }
    }
}
