import WatchConnectivity
import Combine

// Keys shared between iPhone and Watch targets
enum WatchMessageKey {
    static let isRecording    = "isRecording"
    static let snoringDetected = "snoringDetected"
    static let intensity      = "intensity"
    static let command        = "command"
    static let type           = "type"
    static let duration       = "duration"
    static let snoringPct     = "snoringPercentage"
    static let qualityScore   = "qualityScore"
    static let eventCount     = "eventCount"

    static let typeSessionSummary = "sessionSummary"
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

    func sendSessionStatus(isRecording: Bool, snoringDetected: Bool, intensity: Double) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage([
            WatchMessageKey.isRecording:     isRecording,
            WatchMessageKey.snoringDetected: snoringDetected,
            WatchMessageKey.intensity:       intensity
        ], replyHandler: nil)
    }

    func sendSessionSummary(session: SleepSession) {
        guard WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext([
            WatchMessageKey.type:         WatchMessageKey.typeSessionSummary,
            WatchMessageKey.duration:     session.duration,
            WatchMessageKey.snoringPct:   session.snoringPercentage,
            WatchMessageKey.qualityScore: session.qualityScore,
            WatchMessageKey.eventCount:   session.snoringEvents.count
        ])
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
