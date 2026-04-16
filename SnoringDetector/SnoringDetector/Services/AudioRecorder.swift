import AVFoundation
import Combine

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    static let shared = AudioRecorder()

    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var permissionGranted = false

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var currentFileURL: URL?

    var onAudioBuffer: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?

    override private init() {
        super.init()
    }

    func requestPermission() async -> Bool {
        let status = await AVAudioApplication.requestRecordPermission()
        permissionGranted = status
        return status
    }

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let engine = AVAudioEngine()
        audioEngine = engine
        inputNode = engine.inputNode

        let format = inputNode!.outputFormat(forBus: 0)

        // Set up audio file for recording
        let url = makeRecordingURL()
        currentFileURL = url
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        inputNode!.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            guard let self else { return }
            // Write to file
            try? self.audioFile?.write(from: buffer)

            // Compute RMS level
            let rms = self.computeRMS(buffer: buffer)
            Task { @MainActor in
                self.audioLevel = rms
                self.onAudioBuffer?(buffer, time)
            }
        }

        try engine.start()
        isRecording = true
        return url
    }

    func stopRecording() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        audioFile = nil
        isRecording = false
        audioLevel = 0

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func computeRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameCount {
            let sample = channelData[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameCount))
        return min(rms * 10, 1.0)  // Normalize to 0-1 range
    }

    private func makeRecordingURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let name = "snoring_\(formatter.string(from: Date())).caf"
        return docs.appendingPathComponent(name)
    }
}
