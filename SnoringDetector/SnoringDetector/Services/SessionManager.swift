import Foundation

@MainActor
class SessionManager: ObservableObject {
    @Published var isRecording = false

    private let audioRecorder   = AudioRecorder.shared
    private let detectionEngine = SnoringDetectionEngine.shared
    private let dataStore       = DataStore.shared
    private var currentSession: SleepSession?

    func startRecording() {
        Task {
            guard await audioRecorder.requestPermission() else { return }
            do {
                let url = try audioRecorder.startRecording()
                detectionEngine.reset()
                var session = dataStore.startSession()
                session.audioFileURL = url
                currentSession = session

                let sessionStart = session.startDate
                detectionEngine.configure(sampleRate: 44100)

                audioRecorder.onAudioBuffer = { [weak self] buffer, _ in
                    guard let self else { return }
                    self.detectionEngine.process(buffer: buffer, sessionStartTime: sessionStart)
                    WatchConnectivityManager.shared.sendSessionStatus(
                        isRecording: true,
                        snoringDetected: self.detectionEngine.isSnoringDetected,
                        intensity: self.detectionEngine.currentIntensity
                    )
                }
                isRecording = true
            } catch {
                print("Recording failed: \(error)")
            }
        }
    }

    func stopRecording() {
        audioRecorder.stopRecording()
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
}
