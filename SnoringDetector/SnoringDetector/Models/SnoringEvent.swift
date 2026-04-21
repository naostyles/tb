import Foundation
import SwiftUI

struct SnoringEvent: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var intensity: Double  // 0.0 – 1.0
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

        var color: Color {
            switch self {
            case .low:    return .yellow
            case .medium: return .orange
            case .high:   return .red
            }
        }

        var systemImage: String {
            switch self {
            case .low:    return "waveform.path"
            case .medium: return "waveform"
            case .high:   return "waveform.badge.exclamationmark"
            }
        }
    }
}

// MARK: - Sleep Talking Event

struct SleepTalkingEvent: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var timeOffset: TimeInterval
    var duration: TimeInterval { endTime.map { $0.timeIntervalSince(startTime) } ?? 0 }

    init(id: UUID = UUID(), startTime: Date = Date(), timeOffset: TimeInterval = 0) {
        self.id = id
        self.startTime = startTime
        self.timeOffset = timeOffset
    }
}

// MARK: - Toss/Turn Event

struct TossEvent: Identifiable, Codable {
    let id: UUID
    let time: Date
    var timeOffset: TimeInterval
    var motionLevel: Double  // 0-1 normalized magnitude

    init(id: UUID = UUID(), time: Date = Date(), timeOffset: TimeInterval = 0, motionLevel: Double = 0.5) {
        self.id = id
        self.time = time
        self.timeOffset = timeOffset
        self.motionLevel = motionLevel
    }
}

// MARK: - Vital Sample (HR, SpO2, etc.)

struct VitalSample: Identifiable, Codable {
    let id: UUID
    let date: Date
    let value: Double
    let type: VitalType

    init(id: UUID = UUID(), date: Date, value: Double, type: VitalType) {
        self.id = id
        self.date = date
        self.value = value
        self.type = type
    }

    enum VitalType: String, Codable {
        case heartRate         = "HR"
        case oxygenSaturation  = "SpO2"
        case respiratoryRate   = "RR"
        case heartRateVariability = "HRV"
    }
}
