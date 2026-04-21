import Foundation
import UIKit
import CoreMotion

// MARK: - Power Manager

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

    private let prefKey       = "lowPowerPreference"
    private let dimEnabledKey = "screenAutoDimEnabled"
    private let dimDelayKey   = "screenDimDelay"
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
            self, selector: #selector(powerStateChanged),
            name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil
        )
    }

    @objc private func powerStateChanged() {
        Task { @MainActor in
            self.systemLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            SnoringDetectionEngine.shared.configuration.lowPowerMode = self.isLowPowerActive
        }
    }

    func beginSessionDimming() {
        guard savedBrightness == nil else { return }
        savedBrightness = UIScreen.main.brightness
        UIApplication.shared.isIdleTimerDisabled = !screenAutoDimEnabled
        if isLowPowerActive { UIScreen.main.brightness = 0.05 }
        if screenAutoDimEnabled { scheduleDim(delay: screenDimDelaySeconds) }
    }

    func temporarilyRestoreBrightness() {
        dimTimer?.invalidate(); restoreTimer?.invalidate()
        guard let saved = savedBrightness else { return }
        UIScreen.main.brightness = min(saved, 0.6)
        restoreTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.scheduleDim(delay: 5) }
        }
    }

    func endSessionDimming() {
        dimTimer?.invalidate(); restoreTimer?.invalidate()
        dimTimer = nil; restoreTimer = nil
        if let saved = savedBrightness { UIScreen.main.brightness = saved; savedBrightness = nil }
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func scheduleDim(delay: TimeInterval) {
        dimTimer?.invalidate()
        dimTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            Task { @MainActor in UIScreen.main.brightness = 0.01 }
        }
    }
}

// MARK: - Motion Detector

@MainActor
final class MotionDetector: ObservableObject {
    static let shared = MotionDetector()

    @Published var tossEvents: [TossEvent] = []
    @Published var motionLevel: Double = 0

    var motionSensitivity: Double = 0.5
    private(set) var recentMotionBuffer: [Double] = []   // last 300 readings (~1 min at 5 Hz)

    private let motionManager = CMMotionManager()
    private var sessionStartTime: Date?
    private var lastTossTime: Date = .distantPast
    private let tossCooldown: TimeInterval = 30

    private init() {}

    func start(sessionStartTime: Date) {
        guard motionManager.isDeviceMotionAvailable else { return }
        self.sessionStartTime = sessionStartTime
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            Task { @MainActor in
                let a = motion.userAcceleration
                let mag = (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot()
                self.motionLevel = min(mag / 2.0, 1.0)
                self.recentMotionBuffer.append(mag)
                if self.recentMotionBuffer.count > 300 { self.recentMotionBuffer.removeFirst() }
                self.evaluate(magnitude: mag)
            }
        }
    }

    func stop() { motionManager.stopDeviceMotionUpdates(); motionLevel = 0 }

    func reset() { tossEvents.removeAll(); lastTossTime = .distantPast; sessionStartTime = nil; recentMotionBuffer.removeAll() }

    /// Average motion magnitude over the last `seconds` seconds (approximate).
    func averageMotion(lastSeconds: Double) -> Double {
        let count = min(recentMotionBuffer.count, Int(lastSeconds * 5))
        guard count > 0 else { return 0 }
        return recentMotionBuffer.suffix(count).reduce(0, +) / Double(count)
    }

    private func evaluate(magnitude: Double) {
        guard magnitude >= motionSensitivity else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTossTime) >= tossCooldown else { return }
        lastTossTime = now
        let offset = sessionStartTime.map { now.timeIntervalSince($0) } ?? 0
        tossEvents.append(TossEvent(time: now, timeOffset: offset, motionLevel: min(magnitude / 2, 1)))
    }
}

// MARK: - Sleep Stage Tracker

/// Estimates sleep stages every minute using motion intensity + snoring state.
/// Based on simplified actigraphy: high motion = awake, periodic motion + snoring = REM,
/// periodic motion alone = light, no motion = deep.
@MainActor
final class SleepStageTracker {
    private var stages: [SleepStage] = []
    private var currentStage: SleepStage.Stage = .light
    private var currentStageStart: TimeInterval = 0

    func reset() { stages.removeAll(); currentStage = .light; currentStageStart = 0 }

    func update(atOffset offset: TimeInterval, motionAvg: Double, tossesLastMinute: Int, isSnoring: Bool) {
        let newStage: SleepStage.Stage
        switch (motionAvg, tossesLastMinute, isSnoring) {
        case (let m, _, _) where m > 0.6:            newStage = .awake
        case (_, let t, _) where t >= 4:             newStage = .awake
        case (_, let t, true) where t >= 1:          newStage = .rem
        case (let m, _, true) where m < 0.1:         newStage = .light
        case (_, let t, false) where t >= 1:         newStage = .light
        case (let m, 0, false) where m < 0.05:       newStage = .deep
        default:                                     newStage = .light
        }

        if newStage != currentStage {
            if currentStageStart < offset {
                stages.append(SleepStage(startOffset: currentStageStart, endOffset: offset, stage: currentStage))
            }
            currentStage = newStage
            currentStageStart = offset
        }
    }

    func finalize(endOffset: TimeInterval) -> [SleepStage] {
        if currentStageStart < endOffset {
            stages.append(SleepStage(startOffset: currentStageStart, endOffset: endOffset, stage: currentStage))
        }
        return stages
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
    private let motionDetector  = MotionDetector.shared
    private let healthKit       = HealthKitManager.shared
    private let stageTracker    = SleepStageTracker()

    private var currentSession: SleepSession?
    private var minuteTimer: Timer?
    private var minuteRMSValues: [Double] = []
    private var noiseSamples: [NoiseSample] = []
    private var tossesThisMinute: Int = 0
    private var prevTossCount: Int = 0
    private var continuousSnoringStart: Date?

    private var lastWatchSendAt: Date = .distantPast
    private let watchSendInterval: TimeInterval = 2.0
    private let lowPowerWatchSendInterval: TimeInterval = 5.0

    @AppStorage("snoringAlertEnabled") private var snoringAlertEnabled: Bool = true
    @AppStorage("snoringAlertMinutes") private var snoringAlertMinutes: Double = 3.0

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
                stageTracker.reset()
                noiseSamples.removeAll()
                tossesThisMinute = 0; prevTossCount = 0
                continuousSnoringStart = nil
                if healthKit.isAuthorized { healthKit.startLiveHeartRateMonitoring() }

                audioRecorder.onAudioBuffer = { [weak self] buffer, _ in
                    guard let self else { return }
                    self.detectionEngine.process(buffer: buffer, sessionStartTime: sessionStart)
                    self.accumulateRMS()
                    self.checkSnoringAlert()
                    self.throttledWatchUpdate()
                }

                // Minute timer: record noise, estimate stage, check smart alarm
                minuteTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.recordMinuteStats(sessionStart: sessionStart) }
                }
                ScheduleManager.shared.scheduleSmartAlarmBackup()
                isRecording = true
            } catch {
                print("Recording failed: \(error)")
            }
        }
    }

    func stopRecording() {
        minuteTimer?.invalidate(); minuteTimer = nil
        audioRecorder.stopRecording()
        motionDetector.stop()
        healthKit.stopLiveHeartRateMonitoring()
        powerManager.endSessionDimming()
        ScheduleManager.shared.cancelSmartAlarmBackup()

        if let session = currentSession {
            let totalOffset = Date().timeIntervalSince(session.startDate)
            let stages = stageTracker.finalize(endOffset: totalOffset)
            dataStore.endSession(
                session: session,
                snoringEvents: detectionEngine.snoringEvents,
                sleepTalkingEvents: detectionEngine.sleepTalkingEvents,
                tossEvents: motionDetector.tossEvents,
                noiseSamples: noiseSamples,
                sleepStages: stages
            )
            if let finished = dataStore.sessions.first {
                WatchConnectivityManager.shared.sendSessionSummary(session: finished)
            }
        }
        currentSession = nil
        detectionEngine.reset()
        noiseSamples.removeAll()
        isRecording = false
    }

    // MARK: - Per-minute stats

    private func accumulateRMS() {
        minuteRMSValues.append(Double(AudioRecorder.shared.audioLevel))
    }

    private func recordMinuteStats(sessionStart: Date) {
        let now = Date()
        let offset = now.timeIntervalSince(sessionStart)

        // Noise sample
        let avg = minuteRMSValues.isEmpty ? 0.0 : minuteRMSValues.reduce(0, +) / Double(minuteRMSValues.count)
        minuteRMSValues.removeAll()
        noiseSamples.append(NoiseSample(date: now, rmsLevel: avg, timeOffset: offset))

        // Toss count this minute
        let currentToss = motionDetector.tossEvents.count
        tossesThisMinute = currentToss - prevTossCount
        prevTossCount = currentToss

        // Sleep stage
        let motionAvg = motionDetector.averageMotion(lastSeconds: 60)
        stageTracker.update(
            atOffset: offset,
            motionAvg: motionAvg,
            tossesLastMinute: tossesThisMinute,
            isSnoring: detectionEngine.isSnoringDetected
        )

        // Smart alarm check
        ScheduleManager.shared.checkSmartAlarm(
            motionAvg: motionAvg,
            tossCount: tossesThisMinute
        )
    }

    // MARK: - Snoring alert

    private func checkSnoringAlert() {
        guard snoringAlertEnabled else { return }
        if detectionEngine.isSnoringDetected {
            if continuousSnoringStart == nil { continuousSnoringStart = Date() }
            if let start = continuousSnoringStart,
               Date().timeIntervalSince(start) >= snoringAlertMinutes * 60 {
                sendSnoringAlert()
                continuousSnoringStart = nil  // reset so it can fire again later
            }
        } else {
            continuousSnoringStart = nil
        }
    }

    private func sendSnoringAlert() {
        let content = UNMutableNotificationContent()
        content.title = "いびきが続いています"
        content.body = "体の向きを変えると改善することがあります。"
        content.sound = .default
        let req = UNNotificationRequest(identifier: "snoringAlert_\(Date().timeIntervalSince1970)",
                                        content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Watch throttle

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
