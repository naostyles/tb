import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedPeriod = 7
    @State private var selectedSession: SleepSession?

    private let periods = [7, 14, 30]

    private var sessions: [SleepSession] {
        dataStore.sessionsForLastNDays(selectedPeriod)
    }

    private var grouped: [(key: String, sessions: [SleepSession])] {
        let dict = Dictionary(grouping: sessions) { s in
            AppDateFormatter.sessionDate.string(from: s.startDate)
        }
        return dict.map { (key: $0.key, sessions: $0.value) }
            .sorted { a, b in
                (a.sessions.first?.startDate ?? .distantPast) > (b.sessions.first?.startDate ?? .distantPast)
            }
    }

    var body: some View {
        NavigationStack {
            Group {
                if dataStore.sessions.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        Section {
                            SnoringTrendChart(sessions: sessions)
                                .listRowBackground(Color(.systemGroupedBackground))
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                        }

                        ForEach(grouped, id: \.key) { group in
                            Section(group.key) {
                                ForEach(group.sessions) { session in
                                    SessionRow(session: session)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedSession = session }
                                }
                                .onDelete { indices in
                                    for i in indices { dataStore.delete(session: group.sessions[i]) }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("睡眠履歴")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("期間", selection: $selectedPeriod) {
                        ForEach(periods, id: \.self) { p in Text("過去\(p)日").tag(p) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
            .sheet(item: $selectedSession) { SessionDetailView(session: $0) }
        }
    }
}

// MARK: - Empty State

struct EmptyHistoryView: View {
    var body: some View {
        ContentUnavailableView(
            "記録がありません",
            systemImage: "moon.zzz",
            description: Text("ダッシュボードから計測を開始しましょう")
        )
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: SleepSession

    var body: some View {
        HStack(spacing: 14) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(session.qualityColor.opacity(0.2), lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: CGFloat(session.qualityScore) / 100)
                    .stroke(session.qualityColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(session.qualityScore)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(session.qualityColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(startTimeLabel(session.startDate))
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 10) {
                    Label(session.formattedDuration, systemImage: "clock")
                    Label(String(format: "%.0f%%", session.snoringPercentage), systemImage: "waveform")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            QualityTag(label: session.qualityLabel, color: session.qualityColor)
        }
        .padding(.vertical, 4)
    }

    private func startTimeLabel(_ date: Date) -> String {
        AppDateFormatter.bedtime.string(from: date)
    }
}

struct QualityTag: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}
