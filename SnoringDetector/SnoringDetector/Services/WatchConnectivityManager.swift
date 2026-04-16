import WatchConnectivity
import Combine

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
        let message: [String: Any] = [
            "isRecording": isRecording,
            "snoringDetected": snoringDetected,
            "intensity": intensity
        ]
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func sendSessionSummary(session: SleepSession) {
        guard WCSession.default.activationState == .activated else { return }
        let summary: [String: Any] = [
            "type": "sessionSummary",
            "duration": session.duration,
            "snoringPercentage": session.snoringPercentage,
            "qualityScore": session.qualityScore,
            "eventCount": session.snoringEvents.count
        ]
        try? WCSession.default.updateApplicationContext(summary)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let command = message["command"] as? String {
                switch command {
                case "startRecording":
                    self.watchRecordingRequested = true
                case "stopRecording":
                    self.watchRecordingRequested = false
                default:
                    break
                }
            }
        }
    }
}
