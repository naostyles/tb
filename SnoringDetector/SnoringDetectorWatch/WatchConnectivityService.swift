import WatchConnectivity
import WatchKit
import Foundation

// Mirror of WatchMessageKey / WatchCommand defined in the iOS target
private enum MessageKey {
    static let isRecording     = "isRecording"
    static let snoringDetected = "snoringDetected"
    static let intensity       = "intensity"
    static let command         = "command"
    static let type            = "type"
    static let typeSessionSummary = "sessionSummary"
    static let hapticTrigger   = "hapticTrigger"
}

private enum Command {
    static let start = "startRecording"
    static let stop  = "stopRecording"
}

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

    func startRecordingOnPhone() {
        sendCommand(Command.start)
    }

    func stopRecordingOnPhone() {
        sendCommand(Command.stop)
    }

    private func sendCommand(_ command: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage([MessageKey.command: command], replyHandler: nil)
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.isPhoneReachable = session.isReachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isPhoneReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        WatchDataModel.shared.update(from: message)

        // Haptic for snoring alert intervention (gentle directional haptic to prompt position change)
        if message[MessageKey.hapticTrigger] as? Bool == true {
            WKInterfaceDevice.current().play(.directionUp)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                WKInterfaceDevice.current().play(.directionUp)
            }
        } else if message[MessageKey.snoringDetected] as? Bool == true {
            WKInterfaceDevice.current().play(.click)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        WatchDataModel.shared.updateSummary(from: applicationContext)
    }
}
