import SwiftUI

// MARK: - Design tokens

private extension Color {
    static let slumberPurple = Color(hue: 0.74, saturation: 0.56, brightness: 0.60)
    static let slumberDeep   = Color(hue: 0.74, saturation: 0.65, brightness: 0.28)
    static let slumberCard   = Color(.secondarySystemGroupedBackground)
}

private extension LinearGradient {
    static let hero = LinearGradient(
        colors: [
            Color(hue: 0.72, saturation: 0.60, brightness: 0.52),
            Color(hue: 0.77, saturation: 0.55, brightness: 0.40)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let button = LinearGradient(
        colors: [Color.indigo, Color(hue: 0.74, saturation: 0.55, brightness: 0.68)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Dashboard

struct DashboardView: View {
    @EnvironmentObject var dataStore: DataStore
    @EnvironmentObject var scheduleManager: ScheduleManager
    @StateObject private var sessionManager = SessionManager()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Hero: last session card or welcome
                    if let last = dataStore.sessions.first {
                        LastNightCard(session: last)
                    } else {
                        WelcomeCard()
                    }

                    // Primary action
                    RecordButton(sessionManager: sessionManager)

                    // Weekly stats (only after first session)
                    if !dataStore.sessionsForLastNDays(7).isEmpty {
                        WeeklyOverviewCard(dataStore: dataStore)
                    }

                    // Tips carousel
                    TipsCarousel()

                    // Privacy footer
                    PrivacyNote()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Slumber")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $sessionManager.isRecording) {
            SessionView(sessionManager: sessionManager).interactiveDismissDisabled()
        }
        .onChange(of: scheduleManager.shouldAutoStart) { _, shouldStart in
            guard shouldStart, !sessionManager.isRecording else { return }
            scheduleManager.shouldAutoStart = false
            sessionManager.startRecording()
        }
    }
}

// MARK: - Last Night Card

struct LastNightCard: View {
    let session: SleepSession
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(spacing: 0) {
                // Top row: date + score ring
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("前回の睡眠")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.65))
                            .tracking(0.4)
                        Text(session.formattedDate)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    ScoreRing(score: session.qualityScore, color: .white, diameter: 58)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 0.5)
                    .padding(.horizontal, 20)

                // Bottom stats row
                HStack(spacing: 0) {
                    HeroStat(value: session.formattedDuration,
                             label: "睡眠時間", icon: "clock.fill")
                    StatDivider()
                    HeroStat(value: String(format: "%.0f%%", session.snoringPercentage),
                             label: "いびき割合", icon: "waveform")
                    StatDivider()
                    HeroStat(value: session.qualityLabel,
                             label: "評価", icon: "sparkles")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(.hero, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.slumberDeep.opacity(0.35), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            SessionDetailView(session: session)
        }
    }
}

private struct HeroStat: View {
    let value: String; let label: String; let icon: String
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.18))
            .frame(width: 0.5, height: 36)
    }
}

// MARK: - Welcome Card (no data yet)

private struct WelcomeCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 52, weight: .thin))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(LinearGradient.button)
                .padding(.top, 8)
            VStack(spacing: 6) {
                Text("Slumberへようこそ")
                    .font(.title3.weight(.bold))
                Text("今夜、初めての睡眠計測を\n始めてみましょう")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.slumberCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Record Button

struct RecordButton: View {
    @ObservedObject var sessionManager: SessionManager
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.0

    private var isRecording: Bool { sessionManager.isRecording }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                // Pulse rings (recording only)
                if isRecording {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.red.opacity(0.18 - Double(i) * 0.04), lineWidth: 1.5)
                            .frame(width: 188 + CGFloat(i) * 28,
                                   height: 188 + CGFloat(i) * 28)
                            .scaleEffect(pulseScale)
                            .opacity(pulseOpacity)
                            .animation(
                                .easeOut(duration: 1.7)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.38),
                                value: pulseScale
                            )
                    }
                }

                // Shadow glow
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.18) : Color.indigo.opacity(0.14))
                    .frame(width: 196, height: 196)
                    .blur(radius: 24)

                // Main circle
                Circle()
                    .fill(
                        isRecording
                        ? AnyShapeStyle(Color.red.gradient)
                        : AnyShapeStyle(LinearGradient.button)
                    )
                    .frame(width: 158, height: 158)
                    .shadow(
                        color: (isRecording ? Color.red : Color.indigo).opacity(0.38),
                        radius: 28, y: 12
                    )
                    .animation(.spring(duration: 0.4), value: isRecording)

                // Inner content
                VStack(spacing: 9) {
                    Image(systemName: isRecording ? "stop.fill" : "moon.zzz.fill")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                    Text(isRecording ? "停止" : "計測開始")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                isRecording ? sessionManager.stopRecording() : sessionManager.startRecording()
            }
            .onChange(of: isRecording) { _, active in
                if active { triggerPulse() } else { stopPulse() }
            }

            Text(isRecording
                 ? "計測中 — iPhoneをそのままにしてください"
                 : "タップして睡眠計測を開始します")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.25), value: isRecording)
        }
        .padding(.vertical, 12)
    }

    private func triggerPulse() {
        pulseScale = 1.0; pulseOpacity = 0.55
        withAnimation(.easeOut(duration: 1.7).repeatForever(autoreverses: false)) {
            pulseScale = 1.45; pulseOpacity = 0
        }
    }

    private func stopPulse() {
        withAnimation(.easeOut(duration: 0.3)) {
            pulseScale = 1.0; pulseOpacity = 0
        }
    }
}

// MARK: - Weekly Overview Card

private struct WeeklyOverviewCard: View {
    let dataStore: DataStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("今週の概要")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                WeeklyTile(
                    value: String(format: "%.0f%%", dataStore.weeklyAverageSnoringPercentage),
                    label: "いびき平均",
                    icon: "waveform",
                    color: .orange
                )
                WeeklyTile(
                    value: String(format: "%.0f点", dataStore.weeklyAverageQuality),
                    label: "睡眠スコア",
                    icon: "sparkles",
                    color: .indigo
                )
                WeeklyTile(
                    value: "\(dataStore.sessionsForLastNDays(7).count)日",
                    label: "計測日数",
                    icon: "calendar",
                    color: .mint
                )
            }
        }
    }
}

private struct WeeklyTile: View {
    let value: String; let label: String; let icon: String; let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.slumberCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Score Ring (reusable)

struct ScoreRing: View {
    let score: Int
    let color: Color
    let diameter: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: diameter * 0.075)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: diameter * 0.075, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.8), value: score)
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: diameter * 0.31, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text("点")
                    .font(.system(size: diameter * 0.16))
                    .foregroundStyle(color.opacity(0.65))
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Tips Carousel

private struct TipsCarousel: View {
    private struct Tip: Identifiable {
        let id = UUID()
        let icon: String; let color: Color
        let title: String; let body: String
    }

    private let tips = [
        Tip(icon: "arrow.left.arrow.right", color: .blue,
            title: "横向き寝", body: "気道が広がり、いびきが大幅に軽減されます"),
        Tip(icon: "wineglass.slash", color: .green,
            title: "就寝前の断酒", body: "アルコールは喉の筋肉を弛緩させいびきの原因に"),
        Tip(icon: "humidity.fill", color: .cyan,
            title: "加湿の習慣", body: "部屋の湿度を50〜60%に保つと気道が潤います"),
        Tip(icon: "bed.double.fill", color: .purple,
            title: "枕の高さ調整", body: "首が自然な角度になる枕でいびきが改善します"),
        Tip(icon: "figure.mind.and.body", color: .orange,
            title: "口腔筋エクサ", body: "舌・喉のトレーニングで気道が強化されます"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("改善のヒント")
                .font(.headline)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tips) { tip in
                        TipCard(tip: tip)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .padding(.horizontal, -16)
        }
    }
}

private struct TipCard: View {
    let tip: TipsCarousel.Tip

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(tip.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: tip.icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tip.color)
                    .font(.system(size: 18, weight: .medium))
            }
            Text(tip.title)
                .font(.subheadline.weight(.semibold))
            Text(tip.body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 160, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Privacy Note

private struct PrivacyNote: View {
    var body: some View {
        Label("すべての解析はこの端末内で完結します", systemImage: "lock.fill")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
}
