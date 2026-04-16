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

    var onAudioBuffer: ((AVAudioPCMBuffer, AVAudioTime) -> Void)?

    override private init() {
        super.init()
    }

    func requestPermission() async -> Bool {
        let granted = await AVAudioApplication.requestRecordPermission()
        permissionGranted = granted
        return granted
    }

    func startRecording() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let engine = AVAudioEngine()
        audioEngine = engine
        inputNode = engine.inputNode

        let format = inputNode!.outputFormat(forBus: 0)
        let url = makeRecordingURL()
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        inputNode!.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            guard let self else { return }
            try? self.audioFile?.write(from: buffer)
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
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<count { sum += channelData[i] * channelData[i] }
        return min(sqrt(sum / Float(count)) * 10, 1.0)
    }

    private func makeRecordingURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return docs.appendingPathComponent("snoring_\(formatter.string(from: Date())).caf")
    }
}
