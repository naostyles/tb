import Foundation
import UIKit

// MARK: - Power Manager

/// Tracks iOS Low Power Mode, exposes a user toggle, and dims the screen during
/// recording to extend battery life.
@MainActor
final class PowerManager: ObservableObject {
    static let shared = PowerManager()

    @Published private(set) var systemLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published var userLowPowerPreference: Bool {
        didSet { UserDefaults.standard.set(userLowPowerPreference, forKey: prefKey) }
    }

    /// Effective mode: on if either the user opted in or the system enabled it.
    var isLowPowerActive: Bool { systemLowPowerMode || userLowPowerPreference }

    private let prefKey = "lowPowerPreference"
    private var savedBrightness: CGFloat?

    private init() {
        userLowPowerPreference = UserDefaults.standard.bool(forKey: prefKey)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateChanged),
            name: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    @objc private func powerStateChanged() {
        Task { @MainActor in
            self.systemLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            SnoringDetectionEngine.shared.configuration.lowPowerMode = self.isLowPowerActive
        }
    }

    /// Dims the screen during a recording session to a minimal-legible level.
    func beginSessionDimming() {
        guard savedBrightness == nil else { return }
        savedBrightness = UIScreen.main.brightness
        if isLowPowerActive {
            UIScreen.main.brightness = 0.05
        }
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func endSessionDimming() {
        if let saved = savedBrightness {
            UIScreen.main.brightness = saved
            savedBrightness = nil
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

// MARK: - Session Manager

@MainActor
class SessionManager: ObservableObject {
    @Published var isRecording = false

    private let audioRecorder   = AudioRecorder.shared
    private let detectionEngine = SnoringDetectionEngine.shared
    private let dataStore       = DataStore.shared
    private let powerManager    = PowerManager.shared
    private var currentSession: SleepSession?

    /// Throttling state — Watch updates and foreground work happen at most every N seconds.
    private var lastWatchSendAt: Date = .distantPast
    private let watchSendInterval: TimeInterval = 2.0
    private let lowPowerWatchSendInterval: TimeInterval = 5.0

    func startRecording() {
        Task {
            guard await audioRecorder.requestPermission() else { return }
            do {
                let url = try audioRecorder.startRecording()
                detectionEngine.reset()
                detectionEngine.configuration.lowPowerMode = powerManager.isLowPowerActive

                var session = dataStore.startSession()
                session.audioFileURL = url
                currentSession = session

                let sessionStart = session.startDate
                detectionEngine.configure(sampleRate: 44100)
                powerManager.beginSessionDimming()

                audioRecorder.onAudioBuffer = { [weak self] buffer, _ in
                    guard let self else { return }
                    self.detectionEngine.process(buffer: buffer, sessionStartTime: sessionStart)
                    self.throttledWatchUpdate()
                }
                isRecording = true
            } catch {
                print("Recording failed: \(error)")
            }
        }
    }

    func stopRecording() {
        audioRecorder.stopRecording()
        powerManager.endSessionDimming()
        if let session = currentSession {
            dataStore.endSession(session: session, events: detectionEngine.snoringEvents)
            if let finished = dataStore.sessions.first {
                WatchConnectivityManager.shared.sendSessionSummary(session: finished)
            }
        }
        currentSession = nil
        detectionEngine.reset()
        isRecording = false
    }

    private func throttledWatchUpdate() {
        let interval = powerManager.isLowPowerActive ? lowPowerWatchSendInterval : watchSendInterval
        let now = Date()
        guard now.timeIntervalSince(lastWatchSendAt) >= interval else { return }
        lastWatchSendAt = now
        WatchConnectivityManager.shared.sendSessionStatus(
            isRecording: true,
            snoringDetected: detectionEngine.isSnoringDetected,
            intensity: detectionEngine.currentIntensity
        )
    }
}
