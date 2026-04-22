import SwiftUI

// MARK: - Session View (recording screen)

struct SessionView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject private var engine   = SnoringDetectionEngine.shared
    @ObservedObject private var recorder = AudioRecorder.shared
    @ObservedObject private var power    = PowerManager.shared
    @ObservedObject private var motion   = MotionDetector.shared
    @ObservedObject private var health   = HealthKitManager.shared
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    // Midnight navy → deep indigo background
    private let bgGradient = LinearGradient(
        stops: [
            .init(color: Color(hue: 0.70, saturation: 0.50, brightness: 0.14), location: 0.0),
            .init(color: Color(hue: 0.72, saturation: 0.60, brightness: 0.06), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // Grab handle
                Capsule()
                    .fill(.white.opacity(0.20))
                    .frame(width: 36, height: 5)
                    .padding(.top, 14)
                    .padding(.bottom, 28)

                // Elapsed time
                ElapsedTimeDisplay(elapsed: elapsedTime)
                    .padding(.bottom, 28)

                // Status orb
                StatusOrb(
                    isSnoring: engine.isSnoringDetected,
                    isTalking: engine.isSleepTalkingDetected,
                    intensity: engine.currentIntensity
                )
                .padding(.bottom, 20)

                // Waveform / low-power indicator
                Group {
                    if power.isLowPowerActive {
                        LowPowerBadge()
                    } else {
                        AudioLevelView(level: recorder.audioLevel)
                            .frame(height: 44)
                            .padding(.horizontal, 36)
                    }
                }
                .padding(.bottom, 28)

                // Live stats bar
                LiveStatsBar(
                    engine: engine,
                    motion: motion,
                    health: health
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                Spacer()

                // Stop button
                StopButton {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    timer?.invalidate()
                    sessionManager.stopRecording()
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
        .simultaneousGesture(
            TapGesture().onEnded { _ in power.temporarilyRestoreBrightness() }
        )
    }

    private func startTimer() {
        let interval: TimeInterval = power.isLowPowerActive ? 5 : 1
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation(.linear(duration: 0.12)) { elapsedTime += interval }
        }
    }
}

// MARK: - Elapsed Time Display

private struct ElapsedTimeDisplay: View {
    let elapsed: TimeInterval

    var body: some View {
        VStack(spacing: 3) {
            Text("計測時間")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.45))
                .tracking(1.2)
            Text(TimeFormat.clock(elapsed))
                .font(.system(size: 54, weight: .thin, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
    }
}

// MARK: - Status Orb

struct StatusOrb: View {
    let isSnoring: Bool
    let isTalking: Bool
    let intensity: Double
    @State private var pulse = false
    @State private var breathe = false

    private var state: (color: Color, icon: String, label: String) {
        if isSnoring { return (.orange, "waveform.badge.exclamationmark", "いびきを検出中") }
        if isTalking { return (.cyan,   "text.bubble.fill",               "寝言を検出中")   }
        return (.white.opacity(0.5), "moon.zzz.fill", "静かに眠っています")
    }

    private var isActive: Bool { isSnoring || isTalking }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                // Ambient breathing glow (quiet state)
                if !isActive {
                    Circle()
                        .fill(.white.opacity(0.04))
                        .frame(width: 148, height: 148)
                        .scaleEffect(breathe ? 1.10 : 1.0)
                        .animation(
                            .easeInOut(duration: 3.8).repeatForever(autoreverses: true),
                            value: breathe
                        )
                }

                // Alert pulse rings (snoring / talking)
                if isActive {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(state.color.opacity(0.30 - Double(i) * 0.08), lineWidth: 1.5)
                            .frame(width: 92 + CGFloat(i) * 30, height: 92 + CGFloat(i) * 30)
                            .scaleEffect(pulse ? 1.35 : 1.0)
                            .opacity(pulse ? 0 : 1)
                            .animation(
                                .easeOut(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.30),
                                value: pulse
                            )
                    }
                }

                // Core orb background
                Circle()
                    .fill(state.color.opacity(isActive ? 0.22 : 0.08))
                    .frame(width: 92, height: 92)

                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 92, height: 92)

                // Icon
                Image(systemName: state.icon)
                    .font(.system(size: 34, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(state.color)
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.spring(duration: 0.4), value: isActive)
            }
            .frame(height: 168)

            // Status label
            VStack(spacing: 8) {
                Text(state.label)
                    .font(.headline.weight(.medium))
                    .foregroundStyle(state.color)
                    .animation(.easeInOut(duration: 0.3), value: isActive)

                if isSnoring {
                    IntensityBar(value: intensity)
                        .frame(width: 128, height: 4)
                }
            }
        }
        .onChange(of: isActive) { _, active in pulse = active }
        .onAppear { pulse = isActive; breathe = true }
    }
}

private struct IntensityBar: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            Capsule().fill(.white.opacity(0.12))
            Capsule()
                .fill(LinearGradient(
                    colors: [.orange.opacity(0.7), .orange],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(width: geo.size.width * CGFloat(value))
                .animation(.easeOut(duration: 0.15), value: value)
        }
    }
}

// MARK: - Live Stats Bar

private struct LiveStatsBar: View {
    @ObservedObject var engine: SnoringDetectionEngine
    @ObservedObject var motion: MotionDetector
    @ObservedObject var health: HealthKitManager

    var body: some View {
        HStack(spacing: 0) {
            LiveStat(value: "\(engine.snoringEvents.count)",
                     label: "いびき",
                     icon: "waveform.badge.exclamationmark")
            Divider().frame(height: 32).background(.white.opacity(0.15))
            LiveStat(value: "\(engine.sleepTalkingEvents.count)",
                     label: "寝言",
                     icon: "text.bubble.fill")
            Divider().frame(height: 32).background(.white.opacity(0.15))
            LiveStat(value: "\(motion.tossEvents.count)",
                     label: "寝返り",
                     icon: "figure.roll")
            if let hr = health.currentHeartRate {
                Divider().frame(height: 32).background(.white.opacity(0.15))
                LiveStat(value: "\(Int(hr))",
                         label: "心拍数",
                         icon: "heart.fill")
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct LiveStat: View {
    let value: String; let label: String; let icon: String
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.40))
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.40))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Low Power Badge

private struct LowPowerBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "battery.50percent")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.yellow)
            Text("低電力モードで計測中")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.60))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.06),
                    in: Capsule())
    }
}

// MARK: - Stop Button

private struct StopButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "stop.circle.fill").font(.title3)
                Text("計測を終了").font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
        }
        .buttonStyle(SlumberDestructiveStyle())
    }
}

private struct SlumberDestructiveStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.65 : 0.80))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
