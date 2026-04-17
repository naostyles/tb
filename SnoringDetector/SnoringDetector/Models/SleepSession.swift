import Foundation
import SwiftUI

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

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%d時間%02d分", hours, minutes)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E) HH:mm"
        return formatter.string(from: startDate)
    }
}
