import AVFoundation
import Accelerate
import Combine

/// Detects snoring in real-time from audio buffers using FFT-based frequency analysis.
/// Snoring occupies 80–500 Hz with low spectral centroid, weak high-frequency energy,
/// and a rhythmic 2–5 second periodicity. Non-snoring sounds (speech, TV, music,
/// alarms, wind) are rejected via spectral shape and rhythmicity tests.
@MainActor
class SnoringDetectionEngine: ObservableObject {
    static let shared = SnoringDetectionEngine()

    @Published var isSnoringDetected = false
    @Published var currentIntensity: Double = 0.0
    @Published var snoringEvents: [SnoringEvent] = []

    struct Configuration {
        var amplitudeThreshold: Float = 0.010
        var snoringFrequencyLow: Float = 80
        var snoringFrequencyHigh: Float = 500
        var snoringEnergyRatio: Float = 0.45          // stricter than before (was 0.35)
        var highFrequencyRejectHz: Float = 1000       // energy above this must stay low
        var highFrequencyRejectRatio: Float = 0.22    // reject if > this fraction above cutoff
        var spectralCentroidMax: Float = 450          // snoring centroid is low
        var confirmationWindowSeconds: Double = 0.5
        var silenceWindowSeconds: Double = 1.0
        var requireRhythm: Bool = true                // require 2–5 s breathing cycle
        var lowPowerMode: Bool = false                // halve FFT workload when true
    }

    var configuration = Configuration()

    private var sampleRate: Double = 44100
    private var fftSize: Int = 4096
    private var snoringStartTime: Date?
    private var lastDetectionTime: Date?
    private var currentEvent: SnoringEvent?
    private var recentEventStarts: [Date] = []       // rolling history for rhythm check
    private var bufferCounter: UInt = 0              // for buffer-skip in low-power mode

    // Persistent FFT setup — avoids per-buffer create/destroy.
    private var fftSetup: FFTSetup?
    private var fftLog2n: vDSP_Length = 0

    private init() {}

    func configure(sampleRate: Double, fftSize: Int = 4096) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        rebuildFFTSetup()
    }

    func process(buffer: AVAudioPCMBuffer, sessionStartTime: Date) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= fftSize else { return }

        // In low-power mode, analyze every 2nd buffer to halve CPU cost.
        bufferCounter &+= 1
        if configuration.lowPowerMode && bufferCounter % 2 != 0 { return }

        let samples = Array(UnsafeBufferPointer(start: data, count: fftSize))
        let rms = computeRMS(samples: samples)

        guard rms > configuration.amplitudeThreshold else {
            handleSilence(sessionStartTime: sessionStartTime)
            return
        }

        guard isSnoringLike(samples: samples) else {
            handleSilence(sessionStartTime: sessionStartTime)
            return
        }

        let now = Date()
        lastDetectionTime = now
        if snoringStartTime == nil { snoringStartTime = now }

        let elapsed = now.timeIntervalSince(snoringStartTime!)
        guard elapsed >= configuration.confirmationWindowSeconds else { return }

        let normalizedIntensity = Double(rms * 3).clamped(to: 0...1)
        if !isSnoringDetected {
            // Rhythm check: accept only if previous event occurred 1.5–6 s ago,
            // matching the natural breathing cycle. First event is always allowed.
            if configuration.requireRhythm,
               let last = recentEventStarts.last {
                let gap = now.timeIntervalSince(last)
                if gap < 1.2 || gap > 8.0 {
                    // Pattern doesn't match breathing rhythm — treat as noise.
                    // Still remember the candidate so a repeating pattern can settle in.
                    recentEventStarts.append(now)
                    trimRhythmHistory(now: now)
                    snoringStartTime = nil
                    return
                }
            }
            isSnoringDetected = true
            let offset = now.timeIntervalSince(sessionStartTime)
            currentEvent = SnoringEvent(startTime: now, intensity: normalizedIntensity, timeOffset: offset)
            recentEventStarts.append(now)
            trimRhythmHistory(now: now)
        }
        currentIntensity = normalizedIntensity
        currentEvent?.intensity = normalizedIntensity
    }

    func reset() {
        isSnoringDetected = false
        currentIntensity = 0
        snoringEvents.removeAll()
        snoringStartTime = nil
        lastDetectionTime = nil
        currentEvent = nil
        recentEventStarts.removeAll()
        bufferCounter = 0
    }

    // MARK: - Private

    private func handleSilence(sessionStartTime: Date) {
        guard let lastDetect = lastDetectionTime else {
            isSnoringDetected = false
            return
        }
        guard Date().timeIntervalSince(lastDetect) >= configuration.silenceWindowSeconds else { return }

        if isSnoringDetected, var event = currentEvent {
            event.endTime = lastDetect
            if event.duration > 0.5 { snoringEvents.append(event) }
            currentEvent = nil
        }
        isSnoringDetected = false
        snoringStartTime = nil
        lastDetectionTime = nil
        currentIntensity = 0
    }

    private func trimRhythmHistory(now: Date) {
        recentEventStarts = recentEventStarts.filter { now.timeIntervalSince($0) < 30 }
    }

    /// Multi-feature spectral test to isolate snoring from other sounds.
    private func isSnoringLike(samples: [Float]) -> Bool {
        var windowed = applyHannWindow(samples: samples)
        let spectrum = performFFT(samples: &windowed)

        let binWidth = Float(sampleRate) / Float(fftSize)
        let nyquistBin = spectrum.count

        let lowBin  = min(Int(configuration.snoringFrequencyLow  / binWidth), nyquistBin)
        let highBin = min(Int(configuration.snoringFrequencyHigh / binWidth), nyquistBin)
        let rejectBin = min(Int(configuration.highFrequencyRejectHz / binWidth), nyquistBin)

        let totalEnergy = spectrum.reduce(0, +)
        guard totalEnergy > 0 else { return false }

        // 1) Sufficient energy in snoring band.
        let snoringEnergy = spectrum[lowBin..<highBin].reduce(0, +)
        guard (snoringEnergy / totalEnergy) >= configuration.snoringEnergyRatio else { return false }

        // 2) Reject sounds with strong high-frequency content (speech, music, TV, alarms).
        if rejectBin < nyquistBin {
            let highEnergy = spectrum[rejectBin..<nyquistBin].reduce(0, +)
            if (highEnergy / totalEnergy) > configuration.highFrequencyRejectRatio { return false }
        }

        // 3) Spectral centroid must be low — snoring is a rumble, not a whistle.
        let centroid = spectralCentroid(spectrum: spectrum, binWidth: binWidth)
        guard centroid <= configuration.spectralCentroidMax else { return false }

        return true
    }

    private func spectralCentroid(spectrum: [Float], binWidth: Float) -> Float {
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        for (i, m) in spectrum.enumerated() {
            weightedSum += Float(i) * binWidth * m
            magnitudeSum += m
        }
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
    }

    private func applyHannWindow(samples: [Float]) -> [Float] {
        var result = samples
        let n = Float(samples.count - 1)
        for i in 0..<samples.count {
            result[i] *= 0.5 * (1 - cos(2 * Float.pi * Float(i) / n))
        }
        return result
    }

    private func rebuildFFTSetup() {
        if let setup = fftSetup { vDSP_destroy_fftsetup(setup) }
        fftLog2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(fftLog2n, FFTRadix(FFT_RADIX2))
    }

    private func performFFT(samples: inout [Float]) -> [Float] {
        if fftSetup == nil { rebuildFFTSetup() }
        guard let setup = fftSetup else { return [] }

        let n = samples.count
        let halfN = n / 2
        var realPart  = [Float](repeating: 0, count: halfN)
        var imagPart  = [Float](repeating: 0, count: halfN)
        var magnitudes = [Float](repeating: 0, count: halfN)

        samples.withUnsafeMutableBufferPointer { ptr in
            var complexBuffer = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) {
                vDSP_ctoz($0, 2, &complexBuffer, 1, vDSP_Length(halfN))
            }
            vDSP_fft_zrip(setup, &complexBuffer, 1, fftLog2n, FFTDirection(FFT_FORWARD))
            vDSP_zvmags(&complexBuffer, 1, &magnitudes, 1, vDSP_Length(halfN))
        }
        return magnitudes
    }

    private func computeRMS(samples: [Float]) -> Float {
        var sum: Float = 0
        vDSP_svesq(samples, 1, &sum, vDSP_Length(samples.count))
        return sqrt(sum / Float(samples.count))
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        max(range.lowerBound, min(range.upperBound, self))
    }
}
