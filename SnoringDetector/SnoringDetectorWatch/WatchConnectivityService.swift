import WatchConnectivity
import Foundation

class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var isPhoneReachable = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sendCommandToPhone(_ command: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["command": command], replyHandler: nil)
    }

    func startRecordingOnPhone() {
        sendCommandToPhone("startRecording")
    }

    func stopRecordingOnPhone() {
        sendCommandToPhone("stopRecording")
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        WatchDataModel.shared.update(from: message)
        // Haptic feedback when snoring detected
        if let snoring = message["snoringDetected"] as? Bool, snoring {
            WKInterfaceDevice.current().play(.notification)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        WatchDataModel.shared.updateSummary(from: applicationContext)
    }
}
