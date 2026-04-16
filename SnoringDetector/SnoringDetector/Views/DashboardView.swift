import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var sessionManager = SessionManager()
    @State private var showingSession = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header stats
                    WeeklyStatsCard(dataStore: dataStore)

                    // Start/Stop button
                    RecordButton(sessionManager: sessionManager)

                    // Recent session
                    if let lastSession = dataStore.sessions.first {
                        LastSessionCard(session: lastSession)
                    }

                    // Quick tips
                    TipsCard()
                }
                .padding()
            }
            .navigationTitle("いびき検出")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $sessionManager.isRecording) {
                SessionView(sessionManager: sessionManager)
                    .interactiveDismissDisabled()
            }
        }
    }
}

// MARK: - Weekly Stats Card

struct WeeklyStatsCard: View {
    let dataStore: DataStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今週の平均")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                StatItem(
                    value: String(format: "%.0f%%", dataStore.weeklyAverageSnoringPercentage),
                    label: "いびき割合",
                    icon: "waveform",
                    color: .orange
                )
                Divider().frame(height: 50)
                StatItem(
                    value: String(format: "%.0f", dataStore.weeklyAverageQuality),
                    label: "睡眠スコア",
                    icon: "star.fill",
                    color: .yellow
                )
                Divider().frame(height: 50)
                StatItem(
                    value: "\(dataStore.sessionsForLastNDays(7).count)",
                    label: "記録日数",
                    icon: "calendar",
                    color: .indigo
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Record Button

struct RecordButton: View {
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(sessionManager.isRecording ? Color.red.opacity(0.15) : Color.indigo.opacity(0.12))
                    .frame(width: 160, height: 160)

                if sessionManager.isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        .frame(width: 160, height: 160)
                        .scaleEffect(sessionManager.pulseScale)
                        .opacity(sessionManager.pulseOpacity)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false), value: sessionManager.pulseScale)
                }

                Button {
                    if sessionManager.isRecording {
                        sessionManager.stopRecording()
                    } else {
                        sessionManager.startRecording()
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: sessionManager.isRecording ? "stop.circle.fill" : "moon.zzz.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(sessionManager.isRecording ? .red : .indigo)
                        Text(sessionManager.isRecording ? "停止" : "計測開始")
                            .font(.headline)
                            .foregroundStyle(sessionManager.isRecording ? .red : .indigo)
                    }
                }
            }
            .onAppear { sessionManager.startPulse() }

            if sessionManager.isRecording {
                Text("計測中...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("タップして睡眠中のいびきを計測")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - Last Session Card

struct LastSessionCard: View {
    let session: SleepSession
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("前回の記録")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(session.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .bottom, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("睡眠スコア")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(session.qualityScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor(session.qualityScore))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(label: "睡眠時間", value: session.formattedDuration)
                        InfoRow(label: "いびき割合", value: String(format: "%.1f%%", session.snoringPercentage))
                        InfoRow(label: "いびき回数", value: "\(session.snoringEvents.count)回")
                    }
                }

                HStack {
                    Spacer()
                    Text("詳細を見る")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            SessionDetailView(session: session)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }
}

// MARK: - Tips Card

struct TipsCard: View {
    private let tips = [
        ("pillowcase", "横向きで寝るといびきが減ることがあります"),
        ("moon.stars", "就寝前のアルコールを控えましょう"),
        ("humidity", "部屋の湿度を50〜60%に保ちましょう"),
        ("bed.double", "枕の高さを調整してみましょう")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("睡眠のヒント")
                .font(.headline)

            ForEach(tips, id: \.0) { tip in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .frame(width: 20)
                    Text(tip.1)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

// MARK: - SessionManager

@MainActor
class SessionManager: ObservableObject {
    @Published var isRecording = false
    @Published var pulseScale: CGFloat = 1.0
    @Published var pulseOpacity: Double = 0.6

    private let audioRecorder = AudioRecorder.shared
    private let detectionEngine = SnoringDetectionEngine.shared
    private let dataStore = DataStore.shared
    private var currentSession: SleepSession?

    func startRecording() {
        Task {
            let granted = await audioRecorder.requestPermission()
            guard granted else { return }
            do {
                let url = try audioRecorder.startRecording()
                detectionEngine.reset()
                var session = dataStore.startSession()
                session.audioFileURL = url
                currentSession = session

                let sessionStartTime = session.startDate
                let sampleRate = 44100.0
                detectionEngine.configure(sampleRate: sampleRate)

                audioRecorder.onAudioBuffer = { [weak self] buffer, _ in
                    guard let self else { return }
                    self.detectionEngine.process(buffer: buffer, sessionStartTime: sessionStartTime)
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
            let finished = dataStore.sessions.first!
            WatchConnectivityManager.shared.sendSessionSummary(session: finished)
        }
        currentSession = nil
        detectionEngine.reset()
        isRecording = false
    }

    func startPulse() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
            pulseScale = 1.3
            pulseOpacity = 0
        }
    }
}
