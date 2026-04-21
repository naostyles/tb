import Foundation
import SwiftUI

// MARK: - Apnea Event

struct ApneaEvent: Identifiable, Codable {
    var id: UUID = UUID()
    let timeOffset: TimeInterval   // seconds from session start
    var silenceDuration: TimeInterval

    var severity: Severity {
        switch silenceDuration {
        case 0..<10:  return .mild
        case 10..<20: return .moderate
        default:      return .severe
        }
    }

    enum Severity: String, Codable {
        case mild     = "軽度"
        case moderate = "中等度"
        case severe   = "重度"

        var color: Color {
            switch self {
            case .mild:     .yellow
            case .moderate: .orange
            case .severe:   .red
            }
        }

        var icon: String {
            switch self {
            case .mild:     "lungs"
            case .moderate: "exclamationmark.triangle"
            case .severe:   "exclamationmark.triangle.fill"
            }
        }
    }
}

// MARK: - Breathflow Sample (per-second breathing state)

struct BreathflowSample: Identifiable, Codable {
    var id: UUID = UUID()
    let timeOffset: TimeInterval
    let rmsLevel: Double
    let state: BreathState

    enum BreathState: String, Codable {
        case snoring, breathing, silence, grindingTeeth

        var color: Color {
            switch self {
            case .snoring:       .orange
            case .breathing:     .green
            case .silence:       .red.opacity(0.7)
            case .grindingTeeth: .purple
            }
        }
    }
}

// MARK: - Sleep Position

enum SleepPosition: String, Codable, CaseIterable {
    case faceUp    = "仰向け"
    case leftSide  = "左向き"
    case rightSide = "右向き"
    case prone     = "うつ伏せ"
    case unknown   = "不明"

    var icon: String {
        switch self {
        case .faceUp:    "person.fill"
        case .leftSide:  "arrow.left.circle.fill"
        case .rightSide: "arrow.right.circle.fill"
        case .prone:     "person.fill.turn.down"
        case .unknown:   "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .faceUp:    .orange
        case .leftSide:  .blue
        case .rightSide: .green
        case .prone:     .purple
        case .unknown:   .secondary
        }
    }
}

struct SleepPositionSample: Identifiable, Codable {
    var id: UUID = UUID()
    let timeOffset: TimeInterval
    var position: SleepPosition
    var duration: TimeInterval = 0
}

// MARK: - Teeth Grinding Event

struct TeethGrindingEvent: Identifiable, Codable {
    var id: UUID = UUID()
    var startTime: Date = Date()
    var endTime: Date?
    var timeOffset: TimeInterval = 0
    var intensity: Double = 0.5

    var duration: TimeInterval { endTime.map { $0.timeIntervalSince(startTime) } ?? 0 }
}
