import SwiftUI

struct SessionDetailView: View {
    let session: SleepSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ScoreHeaderView(session: session)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        DetailStatCard(title: "睡眠時間",   value: session.formattedDuration,                           icon: "clock.fill",                  color: .indigo)
                        DetailStatCard(title: "いびき時間", value: formatSnoringTime(session.totalSnoringDuration),      icon: "waveform",                    color: .orange)
                        DetailStatCard(title: "いびき割合", value: String(format: "%.1f%%", session.snoringPercentage), icon: "percent",                     color: .purple)
                        DetailStatCard(title: "検出回数",   value: "\(session.snoringEvents.count)回",                  icon: "waveform.badge.exclamationmark", color: .red)
                    }
                    .padding(.horizontal)

                    SessionTimelineChart(session: session)
                        .padding(.horizontal)

                    if !session.snoringEvents.isEmpty {
                        EventListView(events: session.snoringEvents)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(session.formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func formatSnoringTime(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return minutes > 0 ? "\(minutes)分\(seconds)秒" : "\(seconds)秒"
    }
}

struct ScoreHeaderView: View {
    let session: SleepSession

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(session.qualityColor.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: CGFloat(session.qualityScore) / 100)
                    .stroke(session.qualityColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                VStack(spacing: 0) {
                    Text("\(session.qualityScore)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(session.qualityColor)
                    Text("点")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(session.qualityLabel)
                .font(.title3.bold())
                .foregroundStyle(session.qualityColor)

            Text("睡眠スコア")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal)
    }
}

struct DetailStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

struct EventListView: View {
    let events: [SnoringEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("いびきイベント一覧")
                .font(.headline)

            ForEach(events) { event in
                HStack {
                    Image(systemName: event.intensityLevel.systemImage)
                        .foregroundStyle(event.intensityLevel.color)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatOffset(event.timeOffset))
                            .font(.subheadline.bold())
                        Text(event.intensityLevel.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatDuration(event.duration))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)

                if event.id != events.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func formatOffset(_ offset: TimeInterval) -> String {
        let h = Int(offset) / 3600
        let m = (Int(offset) % 3600) / 60
        let s = Int(offset) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d 経過", h, m, s)
            : String(format: "%d:%02d 経過", m, s)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        duration < 60
            ? "\(Int(duration))秒"
            : "\(Int(duration / 60))分\(Int(duration.truncatingRemainder(dividingBy: 60)))秒"
    }
}
