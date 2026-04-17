import SwiftUI

struct SessionView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject private var engine = SnoringDetectionEngine.shared
    @ObservedObject private var recorder = AudioRecorder.shared
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Background: deep indigo fading to near-black
            LinearGradient(
                stops: [
                    .init(color: Color(hue: 0.69, saturation: 0.55, brightness: 0.18), location: 0),
                    .init(color: Color(hue: 0.69, saturation: 0.6, brightness: 0.06), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(.white.opacity(0.25))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 28)

                // Elapsed time
                VStack(spacing: 4) {
                    Text("計測時間")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1)
                    Text(TimeFormat.clock(elapsedTime))
                        .font(.system(size: 60, weight: .thin, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                .padding(.bottom, 36)

                // Status ring + icon
                SnoringStatusView(isSnoring: engine.isSnoringDetected, intensity: engine.currentIntensity)
                    .padding(.bottom, 28)

                // Audio waveform
                AudioLevelView(level: recorder.audioLevel)
                    .frame(height: 60)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)

                // Stats
                HStack(spacing: 0) {
                    SessionStatItem(
                        value: "\(engine.snoringEvents.count)",
                        label: "検出回数",
                        icon: "waveform.badge.exclamationmark"
                    )
                    Divider()
                        .frame(height: 36)
                        .background(.white.opacity(0.2))
                    SessionStatItem(
                        value: String(format: "%.0f%%", engine.currentIntensity * 100),
                        label: "現在の強度",
                        icon: "speaker.wave.3"
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)

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
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                withAnimation(.linear(duration: 0.1)) { elapsedTime += 1 }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}

// MARK: - Snoring Status

struct SnoringStatusView: View {
    let isSnoring: Bool
    let intensity: Double
    @State private var animating = false

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                if isSnoring {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(.orange.opacity(0.25 - Double(i) * 0.06), lineWidth: 1.5)
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
                    .fill(isSnoring ? .orange.opacity(0.22) : .white.opacity(0.08))
                    .frame(width: 96, height: 96)

                Image(systemName: isSnoring ? "waveform.badge.exclamationmark" : "moon.zzz.fill")
                    .font(.system(size: 36, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSnoring ? .orange : .white.opacity(0.6))
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(height: 200)
            .animation(.spring(duration: 0.5), value: isSnoring)

            Text(isSnoring ? "いびきを検出中" : "静かに眠っています")
                .font(.headline)
                .foregroundStyle(isSnoring ? .orange : .white.opacity(0.65))

            if isSnoring {
                ProgressView(value: intensity)
                    .tint(.orange)
                    .frame(width: 140)
                    .animation(.easeOut(duration: 0.2), value: intensity)
            }
        }
        .onChange(of: isSnoring) { _, v in animating = v }
        .onAppear { animating = isSnoring }
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
