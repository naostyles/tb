import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    func load(url: URL) throws {
        stop()
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        let p = try AVAudioPlayer(contentsOf: url)
        p.delegate = self
        p.prepareToPlay()
        player = p
        duration = p.duration
    }

    func togglePlayback() { isPlaying ? pause() : play() }

    func play() {
        player?.play()
        isPlaying = true
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        progress = 0
        duration = 0
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func seek(to time: TimeInterval) {
        let t = time.clamped(to: 0...max(duration, 0))
        player?.currentTime = t
        currentTime = t
        progress = duration > 0 ? t / duration : 0
    }

    private func updateProgress() {
        guard let p = player else { return }
        currentTime = p.currentTime
        progress = duration > 0 ? p.currentTime / duration : 0
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.progress = 0
            self.progressTimer?.invalidate()
            self.progressTimer = nil
        }
    }
}
