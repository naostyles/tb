import Foundation
import UIKit
import CoreMotion

// MARK: - Power Manager

/// Tracks iOS Low Power Mode, manages screen brightness during recording,
/// and implements auto-screen-dim after a configurable delay.
@MainActor
final class PowerManager: ObservableObject {
    static let shared = PowerManager()

    @Published private(set) var systemLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published var userLowPowerPreference: Bool {
        didSet { UserDefaults.standard.set(userLowPowerPreference, forKey: prefKey) }
    }
    @Published var screenAutoDimEnabled: Bool {
        didSet { UserDefaults.standard.set(screenAutoDimEnabled, forKey: dimEnabledKey) }
    }
    @Published var screenDimDelaySeconds: Double {
        didSet { UserDefaults.standard.set(screenDimDelaySeconds, forKey: dimDelayKey) }
    }

    var isLowPowerActive: Bool { systemLowPowerMode || userLowPowerPreference }

    private let prefKey      = "lowPowerPreference"
    private let dimEnabledKey = "screenAutoDimEnabled"
    private let dimDelayKey  = "screenDimDelay"
    private var savedBrightness: CGFloat?
    private var dimTimer: Timer?
    private var restoreTimer: Timer?

    private init() {
        userLowPowerPreference = UserDefaults.standard.bool(forKey: prefKey)
        let stored = UserDefaults.standard.double(forKey: dimDelayKey)
        screenDimDelaySeconds = stored > 0 ? stored : 60
        let storedDim = UserDefaults.standard.object(forKey: dimEnabledKey) as? Bool
        screenAutoDimEnabled = storedDim ?? true
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

    /// Called when recording starts. Saves brightness and schedules auto-dim.
    func beginSessionDimming() {
        guard savedBrightness == nil else { return }
        savedBrightness = UIScreen.main.brightness
        // Keep screen on so user can see status; auto-dim handles dimming
        UIApplication.shared.isIdleTimerDisabled = !screenAutoDimEnabled

        if isLowPowerActive {
            UIScreen.main.brightness = 0.05
        }
        if screenAutoDimEnabled {
            scheduleDim(delay: screenDimDelaySeconds)
        }
    }

    /// Call when user taps screen during dim — briefly restore brightness.
    func temporarilyRestoreBrightness() {
        dimTimer?.invalidate()
        restoreTimer?.invalidate()
        guard let saved = savedBrightness else { return }
        UIScreen.main.brightness = min(saved, 0.6)
        restoreTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.scheduleDim(delay: 5) }
        }
    }

    func endSessionDimming() {
        dimTimer?.invalidate()
        restoreTimer?.invalidate()
        dimTimer = nil
        restoreTimer = nil
        if let saved = savedBrightness {
            UIScreen.main.brightness = saved
            savedBrightness = nil
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func scheduleDim(delay: TimeInterval) {
        dimTimer?.invalidate()
        dimTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard self?.savedBrightness != nil else { return }
                UIScreen.main.brightness = 0.01
            }
        }
    }
}

// MARK: - Motion Detector

/// Detects toss-and-turn events using the device's accelerometer.
/// One event is recorded at most once every 30 seconds to avoid counting
/// micro-adjustments.
@MainActor
final class MotionDetector: ObservableObject {
    static let shared = MotionDetector()

    @Published var tossEvents: [TossEvent] = []
    @Published var motionLevel: Double = 0

    var motionSensitivity: Double = 0.5  // g-force threshold (0.3 – 1.0)

    private let motionManager = CMMotionManager()
    private var sessionStartTime: Date?
    private var lastTossTime: Date = .distantPast
    private let tossCooldown: TimeInterval = 30

    private init() {}

    func start(sessionStartTime: Date) {
        guard motionManager.isDeviceMotionAvailable else { return }
        self.sessionStartTime = sessionStartTime
        motionManager.deviceMotionUpdateInterval = 0.2  // 5 Hz — plenty for body movement
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            Task { @MainActor in
                let a = motion.userAcceleration
                let mag = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
                self.motionLevel = min(mag / 2.0, 1.0)
                self.evaluate(magnitude: mag)
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        motionLevel = 0
    }

    func reset() {
        tossEvents.removeAll()
        lastTossTime = .distantPast
        sessionStartTime = nil
    }

    private func evaluate(magnitude: Double) {
        guard magnitude >= motionSensitivity else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTossTime) >= tossCooldown else { return }
        lastTossTime = now
        let offset = sessionStartTime.map { now.timeIntervalSince($0) } ?? 0
        let normalized = min(magnitude / 2.0, 1.0)
        tossEvents.append(TossEvent(time: now, timeOffset: offset, motionLevel: normalized))
    }
}

// MARK: - Session Manager

@MainActor
class SessionManager: ObservableObject {
    @Published var isRecording = false

    private let audioRecorder    = AudioRecorder.shared
    private let detectionEngine  = SnoringDetectionEngine.shared
    private let dataStore        = DataStore.shared
    private let powerManager     = PowerManager.shared
    private let motionDetector   = MotionDetector.shared
    private let healthKit        = HealthKitManager.shared
    private var currentSession: SleepSession?

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
                motionDetector.reset()
                motionDetector.start(sessionStartTime: sessionStart)
                if healthKit.isAuthorized { healthKit.startLiveHeartRateMonitoring() }

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
        motionDetector.stop()
        healthKit.stopLiveHeartRateMonitoring()
        powerManager.endSessionDimming()

        if let session = currentSession {
            dataStore.endSession(
                session: session,
                snoringEvents: detectionEngine.snoringEvents,
                sleepTalkingEvents: detectionEngine.sleepTalkingEvents,
                tossEvents: motionDetector.tossEvents
            )
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
