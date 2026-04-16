import SwiftUI

struct SessionView: View {
    @ObservedObject var sessionManager: SessionManager
    @ObservedObject private var engine = SnoringDetectionEngine.shared
    @ObservedObject private var recorder = AudioRecorder.shared
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.15).ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 4) {
                        Text("計測時間")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(formatTime(elapsedTime))
                            .font(.system(size: 56, weight: .thin, design: .monospaced))
                            .foregroundStyle(.white)
                    }

                    AudioLevelView(level: recorder.audioLevel)
                        .frame(height: 80)
                        .padding(.horizontal)

                    SnoringStatusView(isSnoring: engine.isSnoringDetected, intensity: engine.currentIntensity)

                    HStack(spacing: 40) {
                        MiniStat(value: "\(engine.snoringEvents.count)", label: "検出回数", color: .orange)
                        MiniStat(value: String(format: "%.0f%%", engine.currentIntensity * 100), label: "強度", color: .red)
                    }

                    Spacer()

                    Button {
                        timer?.invalidate()
                        sessionManager.stopRecording()
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("計測を終了")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(Color.red.opacity(0.8))
                        .clipShape(Capsule())
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("計測中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in elapsedTime += 1 }
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

struct SnoringStatusView: View {
    let isSnoring: Bool
    let intensity: Double
    @State private var animating = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if isSnoring {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.orange.opacity(0.3 - Double(i) * 0.08), lineWidth: 2)
                            .frame(width: 80 + CGFloat(i * 30), height: 80 + CGFloat(i * 30))
                            .scaleEffect(animating ? 1.3 : 1.0)
                            .opacity(animating ? 0 : 0.6)
                            .animation(
                                .easeOut(duration: 1.2).repeatForever(autoreverses: false).delay(Double(i) * 0.3),
                                value: animating
                            )
                    }
                }
                Circle()
                    .fill(isSnoring ? Color.orange.opacity(0.3) : Color.white.opacity(0.08))
                    .frame(width: 80, height: 80)
                Image(systemName: isSnoring ? "waveform.badge.exclamationmark" : "moon.zzz.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(isSnoring ? .orange : .white.opacity(0.5))
            }
            .frame(height: 160)

            Text(isSnoring ? "いびきを検出中" : "静かに眠っています")
                .font(.headline)
                .foregroundStyle(isSnoring ? .orange : .white.opacity(0.7))

            if isSnoring {
                ProgressView(value: intensity)
                    .tint(.orange)
                    .frame(width: 160)
            }
        }
        .onChange(of: isSnoring) { _, snoring in animating = snoring }
        .onAppear { animating = isSnoring }
    }
}

struct MiniStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
