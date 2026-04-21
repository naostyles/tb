import SwiftUI

struct SessionView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject private var engine  = SnoringDetectionEngine.shared
    @ObservedObject private var recorder = AudioRecorder.shared
    @ObservedObject private var power   = PowerManager.shared
    @ObservedObject private var motion  = MotionDetector.shared
    @ObservedObject private var health  = HealthKitManager.shared
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(hue: 0.69, saturation: 0.55, brightness: 0.18), location: 0),
                    .init(color: Color(hue: 0.69, saturation: 0.6, brightness: 0.06), location: 1)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                // Elapsed time
                VStack(spacing: 4) {
                    Text("計測時間")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1)
                    Text(TimeFormat.clock(elapsedTime))
                        .font(.system(size: 56, weight: .thin, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                .padding(.bottom, 24)

                // Status ring: snoring / sleep talking / quiet
                SnoringStatusView(
                    isSnoring: engine.isSnoringDetected,
                    isTalking: engine.isSleepTalkingDetected,
                    intensity: engine.currentIntensity
                )
                .padding(.bottom, 20)

                // Waveform or low-power badge
                if !power.isLowPowerActive {
                    AudioLevelView(level: recorder.audioLevel)
                        .frame(height: 50)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "battery.50").foregroundStyle(.yellow)
                        Text("低電力モードで計測中")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.bottom, 20)
                }

                // Stats row
                HStack(spacing: 0) {
                    SessionStatItem(
                        value: "\(engine.snoringEvents.count)",
                        label: "いびき",
                        icon: "waveform.badge.exclamationmark"
                    )
                    Divider().frame(height: 36).background(.white.opacity(0.2))
                    SessionStatItem(
                        value: "\(engine.sleepTalkingEvents.count)",
                        label: "寝言",
                        icon: "text.bubble.fill"
                    )
                    Divider().frame(height: 36).background(.white.opacity(0.2))
                    SessionStatItem(
                        value: "\(motion.tossEvents.count)",
                        label: "寝返り",
                        icon: "figure.roll"
                    )
                    if let hr = health.currentHeartRate {
                        Divider().frame(height: 36).background(.white.opacity(0.2))
                        SessionStatItem(
                            value: "\(Int(hr))",
                            label: "心拍",
                            icon: "heart.fill"
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)

                Spacer()

                // Stop button
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    timer?.invalidate()
                    sessionManager.stopRecording()
                } label: {
                    Label("計測を終了", systemImage: "stop.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            let interval: TimeInterval = power.isLowPowerActive ? 5 : 1
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                withAnimation(.linear(duration: 0.1)) { elapsedTime += interval }
            }
        }
        .onDisappear { timer?.invalidate() }
        // Tap anywhere to temporarily restore brightness during auto-dim
        .simultaneousGesture(
            TapGesture().onEnded { _ in power.temporarilyRestoreBrightness() }
        )
    }
}

// MARK: - Status Ring

struct SnoringStatusView: View {
    let isSnoring: Bool
    let isTalking: Bool
    let intensity: Double
    @State private var animating = false
    @ObservedObject private var power = PowerManager.shared

    private var activeState: (color: Color, icon: String, label: String)? {
        if isSnoring  { return (.orange, "waveform.badge.exclamationmark", "いびきを検出中") }
        if isTalking  { return (.cyan,   "text.bubble.fill",               "寝言を検出中") }
        return nil
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                if let state = activeState, !power.isLowPowerActive {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(state.color.opacity(0.25 - Double(i) * 0.06), lineWidth: 1.5)
                            .frame(width: 96 + CGFloat(i) * 32, height: 96 + CGFloat(i) * 32)
                            .scaleEffect(animating ? 1.35 : 1)
                            .opacity(animating ? 0 : 1)
                            .animation(
                                .easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(Double(i) * 0.35),
                                value: animating
                            )
                    }
                }

                Circle()
                    .fill((activeState?.color ?? .white).opacity(activeState != nil ? 0.22 : 0.08))
                    .frame(width: 96, height: 96)

                Image(systemName: activeState?.icon ?? "moon.zzz.fill")
                    .font(.system(size: 36, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(activeState?.color ?? .white.opacity(0.6))
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(height: 180)
            .animation(.spring(duration: 0.5), value: isSnoring || isTalking)

            Text(activeState?.label ?? "静かに眠っています")
                .font(.headline)
                .foregroundStyle(activeState?.color ?? .white.opacity(0.65))

            if isSnoring {
                ProgressView(value: intensity)
                    .tint(.orange)
                    .frame(width: 140)
                    .animation(.easeOut(duration: 0.2), value: intensity)
            }
        }
        .onChange(of: isSnoring || isTalking) { _, v in animating = v }
        .onAppear { animating = isSnoring || isTalking }
    }
}

struct SessionStatItem: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }
}
