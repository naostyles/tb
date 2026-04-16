import Foundation

struct SnoringEvent: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var intensity: Double  // 0.0 - 1.0
    var timeOffset: TimeInterval  // seconds from session start

    init(id: UUID = UUID(), startTime: Date = Date(), intensity: Double = 0.5, timeOffset: TimeInterval = 0) {
        self.id = id
        self.startTime = startTime
        self.intensity = intensity
        self.timeOffset = timeOffset
    }

    var duration: TimeInterval {
        guard let end = endTime else { return 0 }
        return end.timeIntervalSince(startTime)
    }

    var intensityLevel: IntensityLevel {
        switch intensity {
        case 0..<0.33: return .low
        case 0.33..<0.66: return .medium
        default: return .high
        }
    }

    enum IntensityLevel: String, Codable {
        case low = "軽い"
        case medium = "普通"
        case high = "強い"

        var color: String {
            switch self {
            case .low: return "yellow"
            case .medium: return "orange"
            case .high: return "red"
            }
        }

        var systemImage: String {
            switch self {
            case .low: return "waveform.path"
            case .medium: return "waveform"
            case .high: return "waveform.badge.exclamationmark"
            }
        }
    }
}
