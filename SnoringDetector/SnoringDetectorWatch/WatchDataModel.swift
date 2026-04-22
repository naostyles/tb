import Foundation
import SwiftUI
import Combine

class WatchDataModel: ObservableObject {
    static let shared = WatchDataModel()

    @Published var isRecording = false
    @Published var isSnoringDetected = false
    @Published var isTalkingDetected = false
    @Published var intensity: Double = 0.0
    @Published var currentHeartRate: Int? = nil
    @Published var tossCount: Int = 0
    @Published var lastSummary: SessionSummary?

    struct SessionSummary {
        let duration: TimeInterval
        let snoringPercentage: Double
        let qualityScore: Int
        let eventCount: Int
        let talkingCount: Int
        let tossCount: Int
        let avgHeartRate: Double?
        let avgOxygen: Double?

        var formattedDuration: String {
            let h = Int(duration) / 3600
            let m = (Int(duration) % 3600) / 60
            return h > 0 ? "\(h)時間\(m)分" : "\(m)分"
        }

        var qualityColor: Color {
            switch qualityScore {
            case 80...100: return .green
            case 60..<80:  return .yellow
            case 40..<60:  return .orange
            default:       return .red
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
    }

    private init() {}

    func update(from message: [String: Any]) {
        DispatchQueue.main.async {
            if let v = message["isRecording"]     as? Bool   { self.isRecording = v }
            if let v = message["snoringDetected"] as? Bool   { self.isSnoringDetected = v }
            if let v = message["talkingDetected"] as? Bool   { self.isTalkingDetected = v }
            if let v = message["intensity"]       as? Double { self.intensity = v }
            if let v = message["heartRate"]       as? Int    { self.currentHeartRate = v }
            if let v = message["tossCount"]       as? Int    { self.tossCount = v }
        }
    }

    func updateSummary(from context: [String: Any]) {
        guard context["type"] as? String == "sessionSummary" else { return }
        DispatchQueue.main.async {
            self.lastSummary = SessionSummary(
                duration:          context["duration"]          as? TimeInterval ?? 0,
                snoringPercentage: context["snoringPercentage"] as? Double ?? 0,
                qualityScore:      context["qualityScore"]      as? Int ?? 0,
                eventCount:        context["eventCount"]        as? Int ?? 0,
                talkingCount:      context["talkingCount"]      as? Int ?? 0,
                tossCount:         context["tossCount"]         as? Int ?? 0,
                avgHeartRate:      context["avgHeartRate"]      as? Double,
                avgOxygen:         context["avgOxygen"]         as? Double
            )
        }
    }
}
