import Foundation
import Combine

class DataStore: ObservableObject {
    static let shared = DataStore()

    @Published var sessions: [SleepSession] = []
    @Published var currentSession: SleepSession?

    private let sessionsKey = "saved_sessions"

    private init() {
        migrateDetectionSettings()
        load()
    }

    /// Reset detection settings that were too strict in a previous build.
    private func migrateDetectionSettings() {
        let migrationKey = "detectionSettingsMigratedV3"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        UserDefaults.standard.set(0.28,   forKey: "snoringEnergyRatio")
        UserDefaults.standard.set(50.0,   forKey: "snoringFrequencyLow")
        UserDefaults.standard.set(500.0,  forKey: "snoringFrequencyHigh")
        UserDefaults.standard.set(0.006,  forKey: "amplitudeThreshold")
        UserDefaults.standard.set(true,   forKey: "rejectNonSnoring")
        UserDefaults.standard.set(true,   forKey: migrationKey)
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

// MARK: - Trend Analyzer

/// Pure functions that summarize sleep sessions into trend points, weekday
/// patterns, intensity distributions, and highlight stats.
enum SleepAnalyzer {

    struct DailyPoint: Identifiable {
        var id: Date { date }
        let date: Date
        let snoringPercentage: Double
        let qualityScore: Double
        let durationHours: Double
        let sessionCount: Int
    }

    struct WeekdayPoint: Identifiable {
        var id: Int { weekdayIndex }
        let weekdayIndex: Int        // 1 = Sunday ... 7 = Saturday (Calendar)
        let label: String            // ja: 日 月 火 水 木 金 土
        let avgSnoringPercentage: Double
        let avgQualityScore: Double
        let sessionCount: Int
    }

    struct IntensitySlice: Identifiable {
        var id: String { label }
        let label: String            // 軽い / 普通 / 強い
        let count: Int
        let color: String            // symbolic; view maps to SwiftUI.Color
    }

    struct Highlights {
        let totalSessions: Int
        let avgDurationHours: Double
        let avgSnoringPercentage: Double
        let avgQualityScore: Double
        let bestSession: SleepSession?
        let worstSession: SleepSession?
        let longestSession: SleepSession?
        let bedtimeVarianceMinutes: Double  // spread of bedtimes (std-dev-like)
        let trend: Trend                    // is recent week better/worse than prior?
    }

    enum Trend { case improving, stable, worsening, unknown }

    // MARK: - Daily aggregation

    static func dailyPoints(_ sessions: [SleepSession], days: Int) -> [DailyPoint] {
        guard !sessions.isEmpty, days > 0 else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [] }

        var byDay: [Date: [SleepSession]] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.startDate)
            if day >= start { byDay[day, default: []].append(session) }
        }

        return (0..<days).compactMap { offset -> DailyPoint? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let list = byDay[day] ?? []
            if list.isEmpty {
                return DailyPoint(date: day, snoringPercentage: 0, qualityScore: 0,
                                  durationHours: 0, sessionCount: 0)
            }
            let snore   = list.map(\.snoringPercentage).reduce(0, +) / Double(list.count)
            let quality = list.map { Double($0.qualityScore) }.reduce(0, +) / Double(list.count)
            let hours   = list.map(\.duration).reduce(0, +) / 3600
            return DailyPoint(
                date: day,
                snoringPercentage: snore,
                qualityScore: quality,
                durationHours: hours,
                sessionCount: list.count
            )
        }
    }

    // MARK: - Weekday pattern

    static func weekdayPattern(_ sessions: [SleepSession]) -> [WeekdayPoint] {
        let calendar = Calendar(identifier: .gregorian)
        let labels = ["日", "月", "火", "水", "木", "金", "土"]
        var bucket: [Int: [SleepSession]] = [:]
        for s in sessions {
            let w = calendar.component(.weekday, from: s.startDate)
            bucket[w, default: []].append(s)
        }
        return (1...7).map { weekday in
            let list = bucket[weekday] ?? []
            if list.isEmpty {
                return WeekdayPoint(
                    weekdayIndex: weekday,
                    label: labels[weekday - 1],
                    avgSnoringPercentage: 0,
                    avgQualityScore: 0,
                    sessionCount: 0
                )
            }
            let snore = list.map(\.snoringPercentage).reduce(0, +) / Double(list.count)
            let q     = list.map { Double($0.qualityScore) }.reduce(0, +) / Double(list.count)
            return WeekdayPoint(
                weekdayIndex: weekday,
                label: labels[weekday - 1],
                avgSnoringPercentage: snore,
                avgQualityScore: q,
                sessionCount: list.count
            )
        }
    }

    // MARK: - Intensity distribution

    static func intensityDistribution(_ sessions: [SleepSession]) -> [IntensitySlice] {
        var low = 0, mid = 0, high = 0
        for s in sessions {
            for e in s.snoringEvents {
                switch e.intensityLevel {
                case .low:    low += 1
                case .medium: mid += 1
                case .high:   high += 1
                }
            }
        }
        return [
            IntensitySlice(label: "軽い", count: low,  color: "yellow"),
            IntensitySlice(label: "普通", count: mid,  color: "orange"),
            IntensitySlice(label: "強い", count: high, color: "red")
        ]
    }

    // MARK: - Highlights

    static func highlights(_ sessions: [SleepSession]) -> Highlights {
        guard !sessions.isEmpty else {
            return Highlights(
                totalSessions: 0, avgDurationHours: 0, avgSnoringPercentage: 0,
                avgQualityScore: 0, bestSession: nil, worstSession: nil,
                longestSession: nil, bedtimeVarianceMinutes: 0, trend: .unknown
            )
        }

        let count = Double(sessions.count)
        let avgDuration = sessions.map(\.duration).reduce(0, +) / count / 3600
        let avgSnoring  = sessions.map(\.snoringPercentage).reduce(0, +) / count
        let avgQuality  = sessions.map { Double($0.qualityScore) }.reduce(0, +) / count

        let best    = sessions.max(by: { $0.qualityScore < $1.qualityScore })
        let worst   = sessions.min(by: { $0.qualityScore < $1.qualityScore })
        let longest = sessions.max(by: { $0.totalSnoringDuration < $1.totalSnoringDuration })

        let variance = bedtimeVarianceMinutes(sessions)
        let trend = recentTrend(sessions)

        return Highlights(
            totalSessions: sessions.count,
            avgDurationHours: avgDuration,
            avgSnoringPercentage: avgSnoring,
            avgQualityScore: avgQuality,
            bestSession: best,
            worstSession: worst,
            longestSession: longest,
            bedtimeVarianceMinutes: variance,
            trend: trend
        )
    }

    private static func bedtimeVarianceMinutes(_ sessions: [SleepSession]) -> Double {
        let calendar = Calendar.current
        let minutesOfDay = sessions.compactMap { s -> Double? in
            let comps = calendar.dateComponents([.hour, .minute], from: s.startDate)
            guard let h = comps.hour, let m = comps.minute else { return nil }
            // Bedtimes after midnight: wrap-around so 23:00 and 01:00 are near each other.
            let raw = Double(h * 60 + m)
            return raw < 12 * 60 ? raw + 24 * 60 : raw
        }
        guard minutesOfDay.count > 1 else { return 0 }
        let mean = minutesOfDay.reduce(0, +) / Double(minutesOfDay.count)
        let variance = minutesOfDay.map { pow($0 - mean, 2) }.reduce(0, +) / Double(minutesOfDay.count)
        return sqrt(variance)
    }

    /// Compare last-7-day avg-quality vs prior-7-day avg-quality.
    private static func recentTrend(_ sessions: [SleepSession]) -> Trend {
        let now = Date()
        let week  = sessions.filter { now.timeIntervalSince($0.startDate) <= 7 * 86400 }
        let prior = sessions.filter {
            let age = now.timeIntervalSince($0.startDate)
            return age > 7 * 86400 && age <= 14 * 86400
        }
        guard !week.isEmpty, !prior.isEmpty else { return .unknown }
        let avg: ([SleepSession]) -> Double = { list in
            list.map { Double($0.qualityScore) }.reduce(0, +) / Double(list.count)
        }
        let delta = avg(week) - avg(prior)
        if delta > 5  { return .improving }
        if delta < -5 { return .worsening }
        return .stable
    }
}
