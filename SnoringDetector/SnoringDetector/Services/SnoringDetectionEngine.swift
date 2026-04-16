import AVFoundation
import Accelerate
import Combine

/// Detects snoring in real-time from audio buffers using FFT-based frequency analysis.
/// Snoring typically occupies 100–500 Hz with characteristic rhythmic patterns.
@MainActor
class SnoringDetectionEngine: ObservableObject {
    static let shared = SnoringDetectionEngine()

    @Published var isSnoringDetected = false
    @Published var currentIntensity: Double = 0.0
    @Published var snoringEvents: [SnoringEvent] = []

    // Tunable thresholds
    var amplitudeThreshold: Float = 0.015      // RMS threshold to consider as potential snoring
    var snoringFrequencyLow: Float = 80        // Hz
    var snoringFrequencyHigh: Float = 500      // Hz
    var snoringEnergyRatio: Float = 0.45       // Snoring band must contain this fraction of total energy
    var confirmationWindowSeconds: Double = 0.8 // Must detect for this long before confirming
    var silenceWindowSeconds: Double = 1.2     // Silence needed to end a snoring event

    private var sampleRate: Double = 44100
    private var fftSize: Int = 4096
    private var snoringStartTime: Date?
    private var lastDetectionTime: Date?
    private var currentEvent: SnoringEvent?

    private var log2N: Int { Int(log2(Float(fftSize))) }

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

        guard rms > amplitudeThreshold else {
            handleSilence(sessionStartTime: sessionStartTime)
            return
        }

        let isSnoringFrequency = analyzeFrequency(samples: samples)
        let now = Date()

        if isSnoringFrequency {
            lastDetectionTime = now
            if snoringStartTime == nil {
                snoringStartTime = now
            }

            // Confirm snoring after window
            let elapsed = now.timeIntervalSince(snoringStartTime!)
            if elapsed >= confirmationWindowSeconds {
                if !isSnoringDetected {
                    isSnoringDetected = true
                    let offset = now.timeIntervalSince(sessionStartTime)
                    currentEvent = SnoringEvent(startTime: now, intensity: Double(rms * 3).clamped(to: 0...1), timeOffset: offset)
                }
                currentIntensity = Double(rms * 3).clamped(to: 0...1)
                currentEvent?.intensity = currentIntensity
            }
        } else {
            handleSilence(sessionStartTime: sessionStartTime)
        }
    }

    private func handleSilence(sessionStartTime: Date) {
        guard let lastDetect = lastDetectionTime else {
            isSnoringDetected = false
            return
        }
        let silenceElapsed = Date().timeIntervalSince(lastDetect)
        if silenceElapsed >= silenceWindowSeconds {
            if isSnoringDetected, var event = currentEvent {
                event.endTime = lastDetect
                if event.duration > 0.5 {
                    snoringEvents.append(event)
                }
                currentEvent = nil
            }
            isSnoringDetected = false
            snoringStartTime = nil
            lastDetectionTime = nil
            currentIntensity = 0
        }
    }

    private func analyzeFrequency(samples: [Float]) -> Bool {
        var windowed = applyHannWindow(samples: samples)
        let spectrum = performFFT(samples: &windowed)

        let binWidth = Float(sampleRate) / Float(fftSize)
        let lowBin = Int(snoringFrequencyLow / binWidth)
        let highBin = Int(snoringFrequencyHigh / binWidth)

        let totalEnergy = spectrum.reduce(0, +)
        guard totalEnergy > 0 else { return false }

        let snoringBand = spectrum[lowBin..<min(highBin, spectrum.count)]
        let snoringEnergy = snoringBand.reduce(0, +)

        return (snoringEnergy / totalEnergy) >= snoringEnergyRatio
    }

    private func applyHannWindow(samples: [Float]) -> [Float] {
        var result = samples
        let count = samples.count
        for i in 0..<count {
            let window = 0.5 * (1 - cos(2 * Float.pi * Float(i) / Float(count - 1)))
            result[i] *= window
        }
        return result
    }

    private func performFFT(samples: inout [Float]) -> [Float] {
        let n = samples.count
        let halfN = n / 2
        var realPart = [Float](repeating: 0, count: halfN)
        var imagPart = [Float](repeating: 0, count: halfN)
        var magnitudes = [Float](repeating: 0, count: halfN)

        samples.withUnsafeMutableBufferPointer { ptr in
            var complexBuffer = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &complexBuffer, 1, vDSP_Length(halfN))
            }
            let setup = vDSP_create_fftsetup(vDSP_Length(log2(Float(n))), FFTRadix(FFT_RADIX2))!
            vDSP_fft_zrip(setup, &complexBuffer, 1, vDSP_Length(log2(Float(n))), FFTDirection(FFT_FORWARD))
            vDSP_zvmags(&complexBuffer, 1, &magnitudes, 1, vDSP_Length(halfN))
            vDSP_destroy_fftsetup(setup)
        }

        return magnitudes
    }

    private func computeRMS(samples: [Float]) -> Float {
        var sum: Float = 0
        vDSP_svesq(samples, 1, &sum, vDSP_Length(samples.count))
        return sqrt(sum / Float(samples.count))
    }

    func reset() {
        isSnoringDetected = false
        currentIntensity = 0
        snoringEvents.removeAll()
        snoringStartTime = nil
        lastDetectionTime = nil
        currentEvent = nil
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return max(range.lowerBound, min(range.upperBound, self))
    }
}
