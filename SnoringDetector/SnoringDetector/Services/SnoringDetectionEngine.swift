import AVFoundation
import Accelerate
import Combine

/// Classifies real-time audio into three categories:
/// - **Snoring**: quasi-periodic low-frequency sound (50–500 Hz) with harmonic
///   structure and low spectral centroid.
/// - **Sleep talking**: speech-like sound with harmonic structure AND significant
///   formant energy (800–3 000 Hz), higher spectral centroid.
/// - **Other**: noise, silence, TV, alarms — none of the above.
@MainActor
class SnoringDetectionEngine: ObservableObject {
    static let shared = SnoringDetectionEngine()

    @Published var isSnoringDetected = false
    @Published var currentIntensity: Double = 0.0
    @Published var snoringEvents: [SnoringEvent] = []

    @Published var isSleepTalkingDetected = false
    @Published var sleepTalkingEvents: [SleepTalkingEvent] = []

    @Published var isTeethGrindingDetected = false
    @Published var teethGrindingEvents: [TeethGrindingEvent] = []
    @Published var currentRMS: Float = 0

    struct Configuration {
        var amplitudeThreshold: Float = 0.006
        var snoringFrequencyLow: Float = 50
        var snoringFrequencyHigh: Float = 500
        var snoringEnergyRatio: Float = 0.28
        var highFrequencyRejectHz: Float = 1500
        var highFrequencyRejectRatio: Float = 0.35
        var spectralCentroidMax: Float = 650      // above this → likely speech, not snoring
        var formantEnergyThreshold: Float = 0.12  // 800–3000 Hz fraction needed for sleep talking
        var confirmationWindowSeconds: Double = 0.5
        var silenceWindowSeconds: Double = 1.5
        var detectSleepTalking: Bool = true
        var rejectNonSnoring: Bool = true
        var lowPowerMode: Bool = false
        var grindingFrequencyLow: Float  = 600
        var grindingFrequencyHigh: Float = 1400
        var grindingEnergyRatio: Float   = 0.30
        var detectTeethGrinding: Bool    = true
    }

    var configuration = Configuration()

    // MARK: - Private state

    private var sampleRate: Double = 44100
    private var fftSize: Int = 4096
    private var bufferCounter: UInt = 0

    // Snoring tracking
    private var snoringStartTime: Date?
    private var lastSnoringDetectionTime: Date?
    private var currentSnoringEvent: SnoringEvent?

    // Sleep talking tracking
    private var talkingStartTime: Date?
    private var lastTalkingDetectionTime: Date?
    private var currentTalkingEvent: SleepTalkingEvent?

    // Teeth grinding tracking
    private var grindingStartTime: Date?
    private var lastGrindingDetectionTime: Date?
    private var currentGrindingEvent: TeethGrindingEvent?

    // Persistent FFT setup
    private var fftSetup: FFTSetup?
    private var fftLog2n: vDSP_Length = 0

    private init() {}

    func configure(sampleRate: Double, fftSize: Int = 4096) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        rebuildFFTSetup()
    }

    // MARK: - Process

    func process(buffer: AVAudioPCMBuffer, sessionStartTime: Date) {
        guard let data = buffer.floatChannelData?[0] else { return }
        guard Int(buffer.frameLength) >= fftSize else { return }

        bufferCounter &+= 1
        if configuration.lowPowerMode && bufferCounter % 2 != 0 { return }

        let samples = Array(UnsafeBufferPointer(start: data, count: fftSize))
        let rms = computeRMS(samples: samples)
        currentRMS = rms
        let now = Date()

        guard rms > configuration.amplitudeThreshold else {
            handleSnoringSilence(now: now)
            handleTalkingSilence(now: now)
            handleGrindingSilence(now: now)
            return
        }

        switch classify(samples: samples) {
        case .snoring:
            handleTalkingSilence(now: now)
            handleGrindingSilence(now: now)
            handleSnoringActive(rms: rms, now: now, sessionStart: sessionStartTime)
        case .sleepTalking:
            handleSnoringSilence(now: now)
            handleGrindingSilence(now: now)
            handleTalkingActive(now: now, sessionStart: sessionStartTime)
        case .grindingTeeth:
            handleSnoringSilence(now: now)
            handleTalkingSilence(now: now)
            handleGrindingActive(rms: rms, now: now, sessionStart: sessionStartTime)
        case .other:
            handleSnoringSilence(now: now)
            handleTalkingSilence(now: now)
            handleGrindingSilence(now: now)
        }
    }

    func reset() {
        isSnoringDetected = false
        isSleepTalkingDetected = false
        currentIntensity = 0
        snoringEvents.removeAll()
        sleepTalkingEvents.removeAll()
        snoringStartTime = nil
        lastSnoringDetectionTime = nil
        currentSnoringEvent = nil
        talkingStartTime = nil
        lastTalkingDetectionTime = nil
        currentTalkingEvent = nil
        isTeethGrindingDetected = false
        teethGrindingEvents.removeAll()
        currentRMS = 0
        grindingStartTime = nil
        lastGrindingDetectionTime = nil
        currentGrindingEvent = nil
        bufferCounter = 0
    }

    // MARK: - Sound Classification

    private enum SoundClass { case snoring, sleepTalking, grindingTeeth, other }

    private func classify(samples: [Float]) -> SoundClass {
        var windowed = applyHannWindow(samples: samples)
        let spectrum = performFFT(samples: &windowed)
        guard !spectrum.isEmpty else { return .other }

        let binWidth = Float(sampleRate) / Float(fftSize)
        let n = spectrum.count
        let totalEnergy = spectrum.reduce(0, +)
        guard totalEnergy > 0 else { return .other }

        // Teeth grinding: strong energy in 600-1400 Hz with harmonic structure
        if configuration.detectTeethGrinding {
            let gLow  = min(Int(configuration.grindingFrequencyLow  / binWidth), n - 1)
            let gHigh = min(Int(configuration.grindingFrequencyHigh / binWidth), n - 1)
            if gHigh > gLow {
                let gEnergy = spectrum[gLow..<gHigh].reduce(0, +)
                if (gEnergy / totalEnergy) >= configuration.grindingEnergyRatio &&
                   hasHarmonicStructure(spectrum: spectrum, binWidth: binWidth) {
                    let gCentroid = spectralCentroid(spectrum: spectrum, binWidth: binWidth)
                    if gCentroid > 700 && gCentroid < 1500 { return .grindingTeeth }
                }
            }
        }

        // Low-band energy gate (snoring band)
        let lowBin  = min(Int(configuration.snoringFrequencyLow  / binWidth), n - 1)
        let highBin = min(Int(configuration.snoringFrequencyHigh / binWidth), n - 1)
        let bandEnergy = spectrum[lowBin..<highBin].reduce(0, +)
        guard (bandEnergy / totalEnergy) >= configuration.snoringEnergyRatio else { return .other }

        // Must have harmonic structure (distinguishes periodic snoring/speech from noise)
        guard hasHarmonicStructure(spectrum: spectrum, binWidth: binWidth) else { return .other }

        let centroid = spectralCentroid(spectrum: spectrum, binWidth: binWidth)

        if configuration.detectSleepTalking {
            // Formant energy: speech has strong peaks in 800–3000 Hz
            let formantLow  = min(Int(800  / binWidth), n - 1)
            let formantHigh = min(Int(3000 / binWidth), n - 1)
            let formantEnergy = formantLow < formantHigh
                ? spectrum[formantLow..<formantHigh].reduce(0, +) / totalEnergy
                : 0

            if formantEnergy >= configuration.formantEnergyThreshold && centroid > 350 {
                return .sleepTalking
            }
        }

        // Additional rejection filters for non-snoring sounds
        if configuration.rejectNonSnoring {
            let rejectBin = min(Int(configuration.highFrequencyRejectHz / binWidth), n - 1)
            if rejectBin < n {
                let hiEnergy = spectrum[rejectBin..<n].reduce(0, +)
                if (hiEnergy / totalEnergy) > configuration.highFrequencyRejectRatio { return .other }
            }
            guard centroid <= configuration.spectralCentroidMax else { return .other }
        }

        return .snoring
    }

    // MARK: - State machines

    private func handleSnoringActive(rms: Float, now: Date, sessionStart: Date) {
        lastSnoringDetectionTime = now
        if snoringStartTime == nil { snoringStartTime = now }
        let elapsed = now.timeIntervalSince(snoringStartTime!)
        guard elapsed >= configuration.confirmationWindowSeconds else { return }

        let intensity = Double(rms * 4).clamped(to: 0...1)
        if !isSnoringDetected {
            isSnoringDetected = true
            currentSnoringEvent = SnoringEvent(
                startTime: now,
                intensity: intensity,
                timeOffset: now.timeIntervalSince(sessionStart)
            )
        }
        currentIntensity = intensity
        currentSnoringEvent?.intensity = intensity
    }

    private func handleSnoringSilence(now: Date) {
        guard let lastDetect = lastSnoringDetectionTime else {
            isSnoringDetected = false
            return
        }
        guard now.timeIntervalSince(lastDetect) >= configuration.silenceWindowSeconds else { return }

        if isSnoringDetected, var event = currentSnoringEvent {
            event.endTime = lastDetect
            if event.duration > 0.5 { snoringEvents.append(event) }
            currentSnoringEvent = nil
        }
        isSnoringDetected = false
        snoringStartTime = nil
        lastSnoringDetectionTime = nil
        currentIntensity = 0
    }

    private func handleTalkingActive(now: Date, sessionStart: Date) {
        lastTalkingDetectionTime = now
        if talkingStartTime == nil { talkingStartTime = now }
        let elapsed = now.timeIntervalSince(talkingStartTime!)
        guard elapsed >= configuration.confirmationWindowSeconds else { return }

        if !isSleepTalkingDetected {
            isSleepTalkingDetected = true
            currentTalkingEvent = SleepTalkingEvent(
                startTime: now,
                timeOffset: now.timeIntervalSince(sessionStart)
            )
        }
    }

    private func handleTalkingSilence(now: Date) {
        guard let lastDetect = lastTalkingDetectionTime else {
            isSleepTalkingDetected = false
            return
        }
        guard now.timeIntervalSince(lastDetect) >= configuration.silenceWindowSeconds else { return }

        if isSleepTalkingDetected, var event = currentTalkingEvent {
            event.endTime = lastDetect
            if event.duration > 0.5 { sleepTalkingEvents.append(event) }
            currentTalkingEvent = nil
        }
        isSleepTalkingDetected = false
        talkingStartTime = nil
        lastTalkingDetectionTime = nil
    }

    private func handleGrindingActive(rms: Float, now: Date, sessionStart: Date) {
        lastGrindingDetectionTime = now
        if grindingStartTime == nil { grindingStartTime = now }
        let elapsed = now.timeIntervalSince(grindingStartTime!)
        guard elapsed >= configuration.confirmationWindowSeconds else { return }
        let intensity = Double(rms * 4).clamped(to: 0...1)
        if !isTeethGrindingDetected {
            isTeethGrindingDetected = true
            currentGrindingEvent = TeethGrindingEvent(
                startTime: now, timeOffset: now.timeIntervalSince(sessionStart), intensity: intensity)
        }
        currentGrindingEvent?.intensity = intensity
    }

    private func handleGrindingSilence(now: Date) {
        guard let lastDetect = lastGrindingDetectionTime else {
            isTeethGrindingDetected = false; return
        }
        guard now.timeIntervalSince(lastDetect) >= configuration.silenceWindowSeconds else { return }
        if isTeethGrindingDetected, var event = currentGrindingEvent {
            event.endTime = lastDetect
            if event.duration > 0.5 { teethGrindingEvents.append(event) }
            currentGrindingEvent = nil
        }
        isTeethGrindingDetected = false; grindingStartTime = nil; lastGrindingDetectionTime = nil
    }

    // MARK: - Spectral analysis helpers

    /// Returns true when there are ≥2 harmonics (2×, 3×, 4×, 5× fundamental) present
    /// at ≥8% of the fundamental peak's energy. This is the key discriminator against
    /// broadband noise, single-tone alarms, and wind.
    private func hasHarmonicStructure(spectrum: [Float], binWidth: Float) -> Bool {
        let fundLow  = max(1, Int(50  / binWidth))
        let fundHigh = min(Int(300 / binWidth), spectrum.count - 1)
        guard fundHigh > fundLow else { return false }

        var peakMag: Float = 0
        var peakBin = fundLow
        for i in fundLow...fundHigh {
            if spectrum[i] > peakMag { peakMag = spectrum[i]; peakBin = i }
        }
        guard peakMag > 0 else { return false }

        // Peak must stand meaningfully above the local noise floor
        let avg = spectrum[fundLow...fundHigh].reduce(0, +) / Float(fundHigh - fundLow + 1)
        guard peakMag > avg * 2.5 else { return false }

        let fundFreq = Float(peakBin) * binWidth
        let minHarmonicMag = peakMag * 0.08

        var harmonicsFound = 0
        for h in 2...5 {
            let hBin = Int(fundFreq * Float(h) / binWidth)
            let lo = max(0, hBin - 3)
            let hi = min(hBin + 3, spectrum.count - 1)
            guard lo <= hi else { continue }
            if (lo...hi).map({ spectrum[$0] }).max() ?? 0 >= minHarmonicMag {
                harmonicsFound += 1
            }
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
            var cb = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) {
                vDSP_ctoz($0, 2, &cb, 1, vDSP_Length(halfN))
            }
            vDSP_fft_zrip(setup, &cb, 1, fftLog2n, FFTDirection(FFT_FORWARD))
            vDSP_zvmags(&cb, 1, &magnitudes, 1, vDSP_Length(halfN))
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
