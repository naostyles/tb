import Foundation
import Combine

class WatchDataModel: ObservableObject {
    static let shared = WatchDataModel()

    @Published var isRecording = false
    @Published var isSnoringDetected = false
    @Published var intensity: Double = 0.0
    @Published var lastSummary: SessionSummary?

    struct SessionSummary {
        let duration: TimeInterval
        let snoringPercentage: Double
        let qualityScore: Int
        let eventCount: Int

        var formattedDuration: String {
            let h = Int(duration) / 3600
            let m = (Int(duration) % 3600) / 60
            if h > 0 { return "\(h)時間\(m)分" }
            return "\(m)分"
        }

        var qualityColor: Color {
            switch qualityScore {
            case 80...100: return .green
            case 60..<80: return .yellow
            case 40..<60: return .orange
            default: return .red
            }
        }
    }

    private init() {}

    func update(from message: [String: Any]) {
        DispatchQueue.main.async {
            if let recording = message["isRecording"] as? Bool {
                self.isRecording = recording
            }
            if let snoring = message["snoringDetected"] as? Bool {
                self.isSnoringDetected = snoring
            }
            if let intensity = message["intensity"] as? Double {
                self.intensity = intensity
            }
        }
    }

    func updateSummary(from context: [String: Any]) {
        guard context["type"] as? String == "sessionSummary" else { return }
        DispatchQueue.main.async {
            self.lastSummary = SessionSummary(
                duration: context["duration"] as? TimeInterval ?? 0,
                snoringPercentage: context["snoringPercentage"] as? Double ?? 0,
                qualityScore: context["qualityScore"] as? Int ?? 0,
                eventCount: context["eventCount"] as? Int ?? 0
            )
        }
    }
}

import SwiftUI
extension WatchDataModel.SessionSummary {
    var qualityLabel: String {
        switch qualityScore {
        case 80...100: return "良好"
        case 60..<80: return "普通"
        case 40..<60: return "やや悪い"
        default: return "悪い"
        }
    }
}
