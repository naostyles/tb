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
    var sleepTalkingEvents: [SleepTalkingEvent]
    var tossEvents: [TossEvent]
    var vitalSamples: [VitalSample]
    var noiseSamples: [NoiseSample]
    var sleepStages: [SleepStage]
    var audioFileURL: URL?

    init(id: UUID = UUID(), startDate: Date = Date()) {
        self.id = id
        self.startDate = startDate
        self.snoringEvents = []
        self.sleepTalkingEvents = []
        self.tossEvents = []
        self.vitalSamples = []
        self.noiseSamples = []
        self.sleepStages = []
    }

    // Forward-compatible decoder
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                 = try c.decode(UUID.self, forKey: .id)
        startDate          = try c.decode(Date.self, forKey: .startDate)
        endDate            = try c.decodeIfPresent(Date.self, forKey: .endDate)
        snoringEvents      = try c.decodeIfPresent([SnoringEvent].self,      forKey: .snoringEvents)      ?? []
        sleepTalkingEvents = try c.decodeIfPresent([SleepTalkingEvent].self, forKey: .sleepTalkingEvents) ?? []
        tossEvents         = try c.decodeIfPresent([TossEvent].self,         forKey: .tossEvents)         ?? []
        vitalSamples       = try c.decodeIfPresent([VitalSample].self,       forKey: .vitalSamples)       ?? []
        noiseSamples       = try c.decodeIfPresent([NoiseSample].self,       forKey: .noiseSamples)       ?? []
        sleepStages        = try c.decodeIfPresent([SleepStage].self,        forKey: .sleepStages)        ?? []
        audioFileURL       = try c.decodeIfPresent(URL.self, forKey: .audioFileURL)
    }

    // MARK: - Computed

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

    var heartRateSamples:  [VitalSample] { vitalSamples.filter { $0.type == .heartRate } }
    var oxygenSamples:     [VitalSample] { vitalSamples.filter { $0.type == .oxygenSaturation } }
    var respiratorySamples:[VitalSample] { vitalSamples.filter { $0.type == .respiratoryRate } }

    var averageHeartRate: Double? {
        let s = heartRateSamples
        guard !s.isEmpty else { return nil }
        return s.map(\.value).reduce(0, +) / Double(s.count)
    }

    var averageOxygen: Double? {
        let s = oxygenSamples
        guard !s.isEmpty else { return nil }
        return s.map(\.value).reduce(0, +) / Double(s.count)
    }

    var deepSleepDuration: TimeInterval {
        sleepStages.filter { $0.stage == .deep }.map(\.duration).reduce(0, +)
    }
    var remSleepDuration: TimeInterval {
        sleepStages.filter { $0.stage == .rem }.map(\.duration).reduce(0, +)
    }
    var lightSleepDuration: TimeInterval {
        sleepStages.filter { $0.stage == .light }.map(\.duration).reduce(0, +)
    }
    var averageNoiseLevel: Double {
        guard !noiseSamples.isEmpty else { return 0 }
        return noiseSamples.map(\.rmsLevel).reduce(0, +) / Double(noiseSamples.count)
    }

    var qualityScore: Int {
        var score = 100.0

        // Snoring penalty
        switch snoringPercentage {
        case 0..<5:   break
        case 5..<15:  score -= 15
        case 15..<30: score -= 30
        case 30..<50: score -= 50
        default:      score -= 70
        }

        // Sleep talking penalty (minor)
        let talkingMinutes = sleepTalkingEvents.map(\.duration).reduce(0, +) / 60
        score -= min(10, talkingMinutes * 0.5)

        // Toss/turn penalty (frequent movement = restless sleep)
        let tossesPerHour = duration > 0 ? Double(tossEvents.count) / (duration / 3600) : 0
        if tossesPerHour > 20 { score -= 15 }
        else if tossesPerHour > 10 { score -= 7 }

        // SpO2 penalty (low oxygen saturation)
        if let spo2 = averageOxygen {
            if spo2 < 90 { score -= 25 }
            else if spo2 < 94 { score -= 12 }
        }

        return max(10, Int(score.rounded()))
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
