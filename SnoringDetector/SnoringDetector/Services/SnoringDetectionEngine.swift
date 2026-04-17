import AVFoundation
import Accelerate
import Combine

/// Detects snoring in real-time from audio buffers using FFT-based frequency analysis.
/// Snoring typically occupies 80–500 Hz with characteristic rhythmic patterns.
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
        var snoringEnergyRatio: Float = 0.35
        var confirmationWindowSeconds: Double = 0.5
        var silenceWindowSeconds: Double = 1.0
    }

    var configuration = Configuration()

    private var sampleRate: Double = 44100
    private var fftSize: Int = 4096
    private var snoringStartTime: Date?
    private var lastDetectionTime: Date?
    private var currentEvent: SnoringEvent?

    private init() {}

    func configure(sampleRate: Double, fftSize: Int = 4096) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
    }

    func process(buffer: AVAudioPCMBuffer, sessionStartTime: Date) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= fftSize else { return }

        let samples = Array(UnsafeBufferPointer(start: data, count: fftSize))
        let rms = computeRMS(samples: samples)

        guard rms > configuration.amplitudeThreshold else {
            handleSilence(sessionStartTime: sessionStartTime)
            return
        }

        guard analyzeFrequency(samples: samples) else {
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
            isSnoringDetected = true
            let offset = now.timeIntervalSince(sessionStartTime)
            currentEvent = SnoringEvent(startTime: now, intensity: normalizedIntensity, timeOffset: offset)
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

    private func analyzeFrequency(samples: [Float]) -> Bool {
        var windowed = applyHannWindow(samples: samples)
        let spectrum = performFFT(samples: &windowed)

        let binWidth = Float(sampleRate) / Float(fftSize)
        let lowBin  = Int(configuration.snoringFrequencyLow  / binWidth)
        let highBin = Int(configuration.snoringFrequencyHigh / binWidth)

        let totalEnergy   = spectrum.reduce(0, +)
        guard totalEnergy > 0 else { return false }

        let snoringEnergy = spectrum[lowBin..<min(highBin, spectrum.count)].reduce(0, +)
        return (snoringEnergy / totalEnergy) >= configuration.snoringEnergyRatio
    }

    private func applyHannWindow(samples: [Float]) -> [Float] {
        var result = samples
        let n = Float(samples.count - 1)
        for i in 0..<samples.count {
            result[i] *= 0.5 * (1 - cos(2 * Float.pi * Float(i) / n))
        }
        return result
    }

    private func performFFT(samples: inout [Float]) -> [Float] {
        let n    = samples.count
        let halfN = n / 2
        var realPart  = [Float](repeating: 0, count: halfN)
        var imagPart  = [Float](repeating: 0, count: halfN)
        var magnitudes = [Float](repeating: 0, count: halfN)

        samples.withUnsafeMutableBufferPointer { ptr in
            var complexBuffer = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) {
                vDSP_ctoz($0, 2, &complexBuffer, 1, vDSP_Length(halfN))
            }
            let log2n = vDSP_Length(log2(Float(n)))
            let setup = vDSP_create_fftsetup(log2n, FFTRadix(FFT_RADIX2))!
            defer { vDSP_destroy_fftsetup(setup) }
            vDSP_fft_zrip(setup, &complexBuffer, 1, log2n, FFTDirection(FFT_FORWARD))
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
