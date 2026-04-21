import AVFoundation
import Accelerate
import Combine

/// Detects snoring from audio buffers using FFT + harmonic structure analysis.
///
/// The primary indicator is harmonic structure: snoring produces a quasi-periodic
/// sound whose energy peaks at a fundamental frequency (50–300 Hz) with at least
/// two visible harmonics. This distinguishes snoring from broadband noise, wind,
/// alerts, and speech (which has strong formant energy above 800 Hz).
@MainActor
class SnoringDetectionEngine: ObservableObject {
    static let shared = SnoringDetectionEngine()

    @Published var isSnoringDetected = false
    @Published var currentIntensity: Double = 0.0
    @Published var snoringEvents: [SnoringEvent] = []

    struct Configuration {
        var amplitudeThreshold: Float = 0.006      // RMS threshold; lower catches quieter snoring
        var snoringFrequencyLow: Float = 50        // fundamental range — some snorers go below 80 Hz
        var snoringFrequencyHigh: Float = 500      // top of snoring fundamental + 1st harmonics
        var snoringEnergyRatio: Float = 0.28       // 50–500 Hz must hold ≥28% of total energy
        var highFrequencyRejectHz: Float = 1500    // above this = speech/music territory
        var highFrequencyRejectRatio: Float = 0.35 // reject if >35% energy above 1500 Hz
        var spectralCentroidMax: Float = 650       // snoring centroid stays low even with harmonics
        var confirmationWindowSeconds: Double = 0.5
        var silenceWindowSeconds: Double = 1.5
        var rejectNonSnoring: Bool = true          // enable harmonic + spectral shape checks
        var lowPowerMode: Bool = false
    }

    var configuration = Configuration()

    private var sampleRate: Double = 44100
    private var fftSize: Int = 4096
    private var snoringStartTime: Date?
    private var lastDetectionTime: Date?
    private var currentEvent: SnoringEvent?
    private var bufferCounter: UInt = 0

    // Persistent FFT setup — avoids per-buffer allocation.
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
        guard Int(buffer.frameLength) >= fftSize else { return }

        bufferCounter &+= 1
        if configuration.lowPowerMode && bufferCounter % 2 != 0 { return }

        let samples = Array(UnsafeBufferPointer(start: data, count: fftSize))
        let rms = computeRMS(samples: samples)

        guard rms > configuration.amplitudeThreshold else {
            handleSilence(sessionStartTime: sessionStartTime)
            return
        }

        guard passesSpectralChecks(samples: samples) else {
            handleSilence(sessionStartTime: sessionStartTime)
            return
        }

        let now = Date()
        lastDetectionTime = now
        if snoringStartTime == nil { snoringStartTime = now }

        let elapsed = now.timeIntervalSince(snoringStartTime!)
        guard elapsed >= configuration.confirmationWindowSeconds else { return }

        let normalizedIntensity = Double(rms * 4).clamped(to: 0...1)
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

    /// Two-stage check:
    /// 1) Band energy ratio — ensures energy is concentrated in the snoring range.
    /// 2) If `rejectNonSnoring` is enabled, run harmonic structure and spectral shape
    ///    tests to reject speech, music, alarms, and broadband noise.
    private func passesSpectralChecks(samples: [Float]) -> Bool {
        var windowed = applyHannWindow(samples: samples)
        let spectrum = performFFT(samples: &windowed)
        guard !spectrum.isEmpty else { return false }

        let binWidth = Float(sampleRate) / Float(fftSize)
        let n = spectrum.count
        let totalEnergy = spectrum.reduce(0, +)
        guard totalEnergy > 0 else { return false }

        // Stage 1: basic band energy gate
        let lowBin  = min(Int(configuration.snoringFrequencyLow  / binWidth), n - 1)
        let highBin = min(Int(configuration.snoringFrequencyHigh / binWidth), n - 1)
        let bandEnergy = spectrum[lowBin..<highBin].reduce(0, +)
        guard (bandEnergy / totalEnergy) >= configuration.snoringEnergyRatio else { return false }

        // Stage 2 (optional): harmonic structure + spectral shape
        guard configuration.rejectNonSnoring else { return true }

        // 2a) Harmonic structure — the fingerprint of periodic, tonal sounds.
        guard hasHarmonicStructure(spectrum: spectrum, binWidth: binWidth) else { return false }

        // 2b) High-frequency dominance check. Speech/music push a lot of energy above
        //     1500 Hz (formants, overtones). Snoring doesn't.
        let rejectBin = min(Int(configuration.highFrequencyRejectHz / binWidth), n - 1)
        if rejectBin < n {
            let hiEnergy = spectrum[rejectBin..<n].reduce(0, +)
            if (hiEnergy / totalEnergy) > configuration.highFrequencyRejectRatio { return false }
        }

        // 2c) Spectral centroid. Snoring energy is concentrated in the low hundreds of Hz.
        let centroid = spectralCentroid(spectrum: spectrum, binWidth: binWidth)
        guard centroid <= configuration.spectralCentroidMax else { return false }

        return true
    }

    /// Looks for a clear fundamental in 50–300 Hz and checks that at least 2 of the
    /// next 4 harmonics (2×, 3×, 4×, 5× fundamental) are present at ≥10% of peak energy.
    ///
    /// This is the most discriminating single test: snoring is quasi-periodic so it
    /// always shows harmonic structure, whereas noise, wind, and single-tone alarms do not.
    private func hasHarmonicStructure(spectrum: [Float], binWidth: Float) -> Bool {
        let fundLow  = max(1, Int(50  / binWidth))
        let fundHigh = min(Int(300 / binWidth), spectrum.count - 1)
        guard fundHigh > fundLow else { return false }

        // Find the dominant peak in the fundamental range.
        var peakMag: Float = 0
        var peakBin = fundLow
        for i in fundLow...fundHigh {
            if spectrum[i] > peakMag { peakMag = spectrum[i]; peakBin = i }
        }
        guard peakMag > 0 else { return false }

        // Sanity: peak must stand above the local average (not just noise).
        let avgInRange = spectrum[fundLow...fundHigh].reduce(0, +) / Float(fundHigh - fundLow + 1)
        guard peakMag > avgInRange * 2.5 else { return false }

        let fundFreq = Float(peakBin) * binWidth
        let minHarmonicMag = peakMag * 0.08  // harmonic must be ≥8% of fundamental

        var harmonicsFound = 0
        for h in 2...5 {
            let hBin = Int(fundFreq * Float(h) / binWidth)
            let lo = max(0, hBin - 3)
            let hi = min(hBin + 3, spectrum.count - 1)
            guard lo <= hi else { continue }
            let localPeak = (lo...hi).map { spectrum[$0] }.max() ?? 0
            if localPeak >= minHarmonicMag { harmonicsFound += 1 }
        }
        return harmonicsFound >= 2
    }

    private func spectralCentroid(spectrum: [Float], binWidth: Float) -> Float {
        var weighted: Float = 0
        var total: Float = 0
        for (i, m) in spectrum.enumerated() {
            weighted += Float(i) * binWidth * m
            total += m
        }
        return total > 0 ? weighted / total : 0
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
        var realPart   = [Float](repeating: 0, count: halfN)
        var imagPart   = [Float](repeating: 0, count: halfN)
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
