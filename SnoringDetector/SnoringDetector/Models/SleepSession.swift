import Foundation
import SwiftUI

// MARK: - Time Formatters

enum TimeFormat {
    static func clock(_ s: TimeInterval) -> String {
        String(format: "%02d:%02d:%02d", Int(s) / 3600, (Int(s) % 3600) / 60, Int(s) % 60)
    }

    static func playback(_ s: TimeInterval) -> String {
        String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }

    static func shortDuration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60, sec = Int(s) % 60
        return m > 0 ? "\(m)分\(sec)秒" : "\(sec)秒"
    }

    static func elapsed(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600, m = (Int(s) % 3600) / 60, sec = Int(s) % 60
        return h > 0 ? String(format: "%d:%02d:%02d 経過", h, m, sec)
                     : String(format: "%d:%02d 経過", m, sec)
    }

    static func longDuration(_ s: TimeInterval) -> String {
        String(format: "%d時間%02d分", Int(s) / 3600, (Int(s) % 3600) / 60)
    }
}

enum AppDateFormatter {
    private static let jaJP = Locale(identifier: "ja_JP")

    static let sessionDateTime: DateFormatter = make(format: "M月d日(E) HH:mm")
    static let sessionDate: DateFormatter     = make(format: "M月d日(E)")
    static let bedtime: DateFormatter         = make(format: "HH:mm 就寝")
    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = jaJP
        f.timeStyle = .short
        return f
    }()

    private static func make(format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = jaJP
        f.dateFormat = format
        return f
    }
}

// MARK: - SleepSession

struct SleepSession: Identifiable, Codable {
    let id: UUID
    var startDate: Date
    var endDate: Date?
    var snoringEvents: [SnoringEvent]
    var audioFileURL: URL?

    init(id: UUID = UUID(), startDate: Date = Date()) {
        self.id = id
        self.startDate = startDate
        self.snoringEvents = []
    }

    var duration: TimeInterval {
        guard let end = endDate else { return Date().timeIntervalSince(startDate) }
        return end.timeIntervalSince(startDate)
    }

    var totalSnoringDuration: TimeInterval {
        snoringEvents.reduce(0) { $0 + $1.duration }
    }

    var snoringPercentage: Double {
        guard duration > 0 else { return 0 }
        return (totalSnoringDuration / duration) * 100
    }

    var averageIntensity: Double {
        guard !snoringEvents.isEmpty else { return 0 }
        return snoringEvents.map(\.intensity).reduce(0, +) / Double(snoringEvents.count)
    }

    var qualityScore: Int {
        switch snoringPercentage {
        case 0..<5:   return 100
        case 5..<15:  return 80
        case 15..<30: return 60
        case 30..<50: return 40
        default:      return 20
        }
    }

    var qualityLabel: String {
        switch qualityScore {
        case 80...100: return "良好"
        case 60..<80:  return "普通"
        case 40..<60:  return "やや悪い"
        default:       return "悪い"
        }
    }

    var qualityColor: Color {
        switch qualityScore {
        case 80...100: return .green
        case 60..<80:  return .yellow
        case 40..<60:  return .orange
        default:       return .red
        }
    }

    var formattedDuration: String { TimeFormat.longDuration(duration) }
    var formattedDate: String     { AppDateFormatter.sessionDateTime.string(from: startDate) }
}
