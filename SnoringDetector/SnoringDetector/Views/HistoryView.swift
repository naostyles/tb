import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedPeriod = 7
    @State private var selectedSession: SleepSession?

    private let periods = [7, 14, 30]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("期間", selection: $selectedPeriod) {
                        ForEach(periods, id: \.self) { p in
                            Text("過去\(p)日").tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if dataStore.sessions.isEmpty {
                        EmptyHistoryView()
                    } else {
                        SnoringChartView(sessions: dataStore.sessionsForLastNDays(selectedPeriod))
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            ForEach(dataStore.sessionsForLastNDays(selectedPeriod)) { session in
                                SessionRowView(session: session)
                                    .onTapGesture { selectedSession = session }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            dataStore.delete(session: session)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("睡眠履歴")
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
        }
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 64))
                .foregroundStyle(.indigo.opacity(0.4))
            Text("まだ記録がありません")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("ダッシュボードから計測を開始しましょう")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }
}

struct SessionRowView: View {
    let session: SleepSession

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(session.qualityColor.opacity(0.2), lineWidth: 4)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: CGFloat(session.qualityScore) / 100)
                    .stroke(session.qualityColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)
                Text("\(session.qualityScore)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(session.qualityColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.formattedDate)
                    .font(.subheadline.bold())
                HStack(spacing: 12) {
                    Label(session.formattedDuration, systemImage: "clock")
                    Label(String(format: "%.0f%%", session.snoringPercentage), systemImage: "waveform")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}
