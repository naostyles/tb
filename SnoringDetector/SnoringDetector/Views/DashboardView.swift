import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var sessionManager = SessionManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    OnDeviceBadge()
                        .frame(maxWidth: .infinity, alignment: .center)

                    RecordButton(sessionManager: sessionManager)

                    if !dataStore.sessionsForLastNDays(7).isEmpty {
                        WeeklyStatsRow(dataStore: dataStore)
                    }

                    if let last = dataStore.sessions.first {
                        LastSessionCard(session: last)
                    }

                    SleepTipsSection()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("いびき検出")
        }
        .sheet(isPresented: $sessionManager.isRecording) {
            SessionView(sessionManager: sessionManager)
                .interactiveDismissDisabled()
        }
    }
}

// MARK: - On-Device Badge

struct OnDeviceBadge: View {
    var body: some View {
        Label("端末内で解析・通信なし", systemImage: "lock.fill")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.quaternary, in: Capsule())
    }
}

// MARK: - Record Button

struct RecordButton: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.0

    private var isRecording: Bool { sessionManager.isRecording }

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                if isRecording {
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .stroke(Color.red.opacity(0.2 - Double(i) * 0.05), lineWidth: 1)
                            .frame(width: 200, height: 200)
                            .scaleEffect(pulseScale)
                            .opacity(pulseOpacity)
                            .animation(
                                .easeOut(duration: 1.6).repeatForever(autoreverses: false).delay(Double(i) * 0.4),
                                value: pulseScale
                            )
                    }
                }

                Circle()
                    .fill(isRecording ? Color.red : Color.indigo)
                    .frame(width: 160, height: 160)
                    .shadow(
                        color: (isRecording ? Color.red : Color.indigo).opacity(0.35),
                        radius: 24, y: 10
                    )

                VStack(spacing: 10) {
                    Image(systemName: isRecording ? "stop.fill" : "moon.zzz.fill")
                        .font(.system(size: 46, weight: .medium))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                    Text(isRecording ? "停止" : "計測開始")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .onTapGesture {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                isRecording ? sessionManager.stopRecording() : sessionManager.startRecording()
            }
            .onChange(of: isRecording) { _, recording in
                if recording { startPulse() }
            }

            Text(isRecording ? "計測中... iPhoneをそのままにしてください" : "タップして睡眠中のいびきを計測")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func startPulse() {
        pulseScale = 1.0
        pulseOpacity = 0.5
        withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
            pulseScale = 1.4
            pulseOpacity = 0
        }
    }
}

// MARK: - Weekly Stats Row

struct WeeklyStatsRow: View {
    let dataStore: DataStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("今週の平均")

            HStack(spacing: 12) {
                MetricTile(
                    value: String(format: "%.0f%%", dataStore.weeklyAverageSnoringPercentage),
                    label: "いびき割合",
                    icon: "waveform",
                    tint: .orange
                )
                MetricTile(
                    value: String(format: "%.0f", dataStore.weeklyAverageQuality),
                    label: "睡眠スコア",
                    icon: "star.fill",
                    tint: .yellow
                )
                MetricTile(
                    value: "\(dataStore.sessionsForLastNDays(7).count)日",
                    label: "記録日数",
                    icon: "calendar",
                    tint: .indigo
                )
            }
        }
    }
}

struct MetricTile: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .font(.title3)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Last Session Card

struct LastSessionCard: View {
    let session: SleepSession
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("前回の記録")

            Button { showDetail = true } label: {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(session.formattedDate)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        HStack(spacing: 14) {
                            Label(session.formattedDuration, systemImage: "clock")
                            Label(String(format: "%.1f%%", session.snoringPercentage), systemImage: "waveform")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(session.qualityColor.opacity(0.25), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: CGFloat(session.qualityScore) / 100)
                            .stroke(session.qualityColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(session.qualityScore)")
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(session.qualityColor)
                    }
                    .frame(width: 46, height: 46)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showDetail) {
            SessionDetailView(session: session)
        }
    }
}

// MARK: - Tips Section

struct SleepTipsSection: View {
    private let tips: [(String, String)] = [
        ("figure.walk.motion", "横向きで寝るといびきが減ることがあります"),
        ("wineglass.slash", "就寝前のアルコールを控えましょう"),
        ("humidity.fill", "部屋の湿度を50〜60%に保ちましょう"),
        ("bed.double.fill", "枕の高さを調整してみましょう")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("睡眠のヒント")

            VStack(spacing: 0) {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    HStack(spacing: 14) {
                        Image(systemName: tip.0)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.indigo)
                            .frame(width: 24)
                        Text(tip.1)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < tips.count - 1 {
                        Divider().padding(.leading, 54)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

// MARK: - Shared Section Header

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

// MARK: - SessionManager

@MainActor
class SessionManager: ObservableObject {
    @Published var isRecording = false

    private let audioRecorder = AudioRecorder.shared
    private let detectionEngine = SnoringDetectionEngine.shared
    private let dataStore = DataStore.shared
    private var currentSession: SleepSession?

    func startRecording() {
        Task {
            guard await audioRecorder.requestPermission() else { return }
            do {
                let url = try audioRecorder.startRecording()
                detectionEngine.reset()
                var session = dataStore.startSession()
                session.audioFileURL = url
                currentSession = session

                let sessionStart = session.startDate
                detectionEngine.configure(sampleRate: 44100)

                audioRecorder.onAudioBuffer = { [weak self] buffer, _ in
                    guard let self else { return }
                    self.detectionEngine.process(buffer: buffer, sessionStartTime: sessionStart)
                    WatchConnectivityManager.shared.sendSessionStatus(
                        isRecording: true,
                        snoringDetected: self.detectionEngine.isSnoringDetected,
                        intensity: self.detectionEngine.currentIntensity
                    )
                }
                isRecording = true
            } catch {
                print("Recording failed: \(error)")
            }
        }
    }

    func stopRecording() {
        audioRecorder.stopRecording()
        if let session = currentSession {
            dataStore.endSession(session: session, events: detectionEngine.snoringEvents)
            if let finished = dataStore.sessions.first {
                WatchConnectivityManager.shared.sendSessionSummary(session: finished)
            }
        }
        currentSession = nil
        detectionEngine.reset()
        isRecording = false
    }
}
