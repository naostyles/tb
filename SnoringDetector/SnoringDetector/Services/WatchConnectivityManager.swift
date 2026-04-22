import WatchConnectivity
import Combine

// Keys shared between iPhone and Watch targets
enum WatchMessageKey {
    static let isRecording     = "isRecording"
    static let snoringDetected = "snoringDetected"
    static let talkingDetected = "talkingDetected"
    static let intensity       = "intensity"
    static let heartRate       = "heartRate"
    static let tossCount       = "tossCount"
    static let command         = "command"
    static let type            = "type"
    static let duration        = "duration"
    static let snoringPct      = "snoringPercentage"
    static let qualityScore    = "qualityScore"
    static let eventCount      = "eventCount"
    static let talkingCount    = "talkingCount"
    static let avgHeartRate    = "avgHeartRate"
    static let avgOxygen       = "avgOxygen"

    static let typeSessionSummary = "sessionSummary"
    static let hapticTrigger = "hapticTrigger"
}

enum WatchCommand {
    static let start = "startRecording"
    static let stop  = "stopRecording"
}

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isWatchReachable = false
    @Published var watchRecordingRequested = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    @MainActor
    func sendSessionStatus(isRecording: Bool, snoringDetected: Bool, intensity: Double) {
        guard WCSession.default.isReachable else { return }
        var msg: [String: Any] = [
            WatchMessageKey.isRecording:     isRecording,
            WatchMessageKey.snoringDetected: snoringDetected,
            WatchMessageKey.talkingDetected: SnoringDetectionEngine.shared.isSleepTalkingDetected,
            WatchMessageKey.intensity:       intensity,
            WatchMessageKey.tossCount:       MotionDetector.shared.tossEvents.count
        ]
        if let hr = HealthKitManager.shared.currentHeartRate {
            msg[WatchMessageKey.heartRate] = Int(hr)
        }
        WCSession.default.sendMessage(msg, replyHandler: nil)
    }

    func sendHapticTrigger() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage([WatchMessageKey.hapticTrigger: true], replyHandler: nil)
    }

    func sendSessionSummary(session: SleepSession) {
        guard WCSession.default.activationState == .activated else { return }
        var ctx: [String: Any] = [
            WatchMessageKey.type:         WatchMessageKey.typeSessionSummary,
            WatchMessageKey.duration:     session.duration,
            WatchMessageKey.snoringPct:   session.snoringPercentage,
            WatchMessageKey.qualityScore: session.qualityScore,
            WatchMessageKey.eventCount:   session.snoringEvents.count,
            WatchMessageKey.talkingCount: session.sleepTalkingEvents.count,
            WatchMessageKey.tossCount:    session.tossEvents.count
        ]
        if let hr  = session.averageHeartRate  { ctx[WatchMessageKey.avgHeartRate] = hr }
        if let spo2 = session.averageOxygen    { ctx[WatchMessageKey.avgOxygen]    = spo2 }
        try? WCSession.default.updateApplicationContext(ctx)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let command = message[WatchMessageKey.command] as? String else { return }
        DispatchQueue.main.async {
            self.watchRecordingRequested = command == WatchCommand.start
        }
    }
}
