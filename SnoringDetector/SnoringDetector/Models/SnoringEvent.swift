import Foundation
import SwiftUI

struct SnoringEvent: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var intensity: Double
    var timeOffset: TimeInterval

    init(id: UUID = UUID(), startTime: Date = Date(), intensity: Double = 0.5, timeOffset: TimeInterval = 0) {
        self.id = id; self.startTime = startTime; self.intensity = intensity; self.timeOffset = timeOffset
    }
    var duration: TimeInterval { endTime.map { $0.timeIntervalSince(startTime) } ?? 0 }
    var intensityLevel: IntensityLevel {
        switch intensity {
        case 0..<0.33: return .low
        case 0.33..<0.66: return .medium
        default: return .high
        }
    }
    enum IntensityLevel: String, Codable {
        case low = "軽い", medium = "普通", high = "強い"
        var color: Color { switch self { case .low: .yellow; case .medium: .orange; case .high: .red } }
        var systemImage: String { switch self { case .low: "waveform.path"; case .medium: "waveform"; case .high: "waveform.badge.exclamationmark" } }
    }
}

// MARK: - Sleep Talking Event

struct SleepTalkingEvent: Identifiable, Codable {
    let id: UUID; let startTime: Date; var endTime: Date?; var timeOffset: TimeInterval
    var duration: TimeInterval { endTime.map { $0.timeIntervalSince(startTime) } ?? 0 }
    init(id: UUID = UUID(), startTime: Date = Date(), timeOffset: TimeInterval = 0) {
        self.id = id; self.startTime = startTime; self.timeOffset = timeOffset
    }
}

// MARK: - Toss/Turn Event

struct TossEvent: Identifiable, Codable {
    let id: UUID; let time: Date; var timeOffset: TimeInterval; var motionLevel: Double
    init(id: UUID = UUID(), time: Date = Date(), timeOffset: TimeInterval = 0, motionLevel: Double = 0.5) {
        self.id = id; self.time = time; self.timeOffset = timeOffset; self.motionLevel = motionLevel
    }
}

// MARK: - Vital Sample (HR, SpO2, etc.)

struct VitalSample: Identifiable, Codable {
    let id: UUID; let date: Date; let value: Double; let type: VitalType
    init(id: UUID = UUID(), date: Date, value: Double, type: VitalType) {
        self.id = id; self.date = date; self.value = value; self.type = type
    }
    enum VitalType: String, Codable {
        case heartRate = "HR", oxygenSaturation = "SpO2",
             respiratoryRate = "RR", heartRateVariability = "HRV"
    }
}

// MARK: - Ambient Noise Sample

/// Per-minute average microphone RMS recorded during a session.
struct NoiseSample: Identifiable, Codable {
    let id: UUID; let date: Date; let rmsLevel: Double; let timeOffset: TimeInterval
    init(id: UUID = UUID(), date: Date, rmsLevel: Double, timeOffset: TimeInterval) {
        self.id = id; self.date = date; self.rmsLevel = rmsLevel; self.timeOffset = timeOffset
    }
}

// MARK: - Sleep Stage

/// Estimated sleep stage at a given minute, derived from motion + audio patterns.
struct SleepStage: Identifiable, Codable {
    let id: UUID; let startOffset: TimeInterval; var endOffset: TimeInterval; let stage: Stage
    init(id: UUID = UUID(), startOffset: TimeInterval, endOffset: TimeInterval = 0, stage: Stage) {
        self.id = id; self.startOffset = startOffset; self.endOffset = endOffset; self.stage = stage
    }
    var duration: TimeInterval { endOffset - startOffset }

    enum Stage: String, Codable, CaseIterable {
        case awake = "覚醒"
        case rem   = "REM"
        case light = "浅い眠り"
        case deep  = "深い眠り"

        var color: Color {
            switch self { case .awake: .red; case .rem: .purple; case .light: .cyan; case .deep: .indigo }
        }
        var shortLabel: String {
            switch self { case .awake: "覚"; case .rem: "R"; case .light: "浅"; case .deep: "深" }
        }
    }
}
