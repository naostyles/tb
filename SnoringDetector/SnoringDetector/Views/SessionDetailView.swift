import SwiftUI

struct SessionDetailView: View {
    let session: SleepSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Score hero
                Section {
                    ScoreHeroView(session: session)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                // Key metrics
                Section("詳細データ") {
                    MetricRow(label: "睡眠時間",   value: session.formattedDuration,
                              icon: "clock.fill",  tint: .indigo)
                    MetricRow(label: "いびき時間",  value: formatSnoringTime(session.totalSnoringDuration),
                              icon: "waveform",    tint: .orange)
                    MetricRow(label: "いびき割合",  value: String(format: "%.1f%%", session.snoringPercentage),
                              icon: "percent",     tint: .purple)
                    MetricRow(label: "検出回数",    value: "\(session.snoringEvents.count)回",
                              icon: "waveform.badge.exclamationmark", tint: .red)
                    MetricRow(label: "平均強度",    value: String(format: "%.0f%%", session.averageIntensity * 100),
                              icon: "speaker.wave.2.fill", tint: .pink)
                }

                // Timeline chart
                Section("タイムライン") {
                    SessionTimelineChart(session: session)
                        .padding(.vertical, 8)
                }

                // Event list
                if !session.snoringEvents.isEmpty {
                    Section("検出イベント（\(session.snoringEvents.count)件）") {
                        ForEach(session.snoringEvents) { event in
                            SnoringEventRow(event: event)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(session.formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func formatSnoringTime(_ d: TimeInterval) -> String {
        let m = Int(d) / 60, s = Int(d) % 60
        return m > 0 ? "\(m)分\(s)秒" : "\(s)秒"
    }
}

// MARK: - Score Hero

struct ScoreHeroView: View {
    let session: SleepSession

    var body: some View {
        HStack(spacing: 28) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(session.qualityColor.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(session.qualityScore) / 100)
                    .stroke(session.qualityColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 1.0), value: session.qualityScore)
                VStack(spacing: 0) {
                    Text("\(session.qualityScore)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(session.qualityColor)
                    Text("点")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 6) {
                Text(session.qualityLabel)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(session.qualityColor)
                Text("睡眠スコア")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(session.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(session.qualityColor.opacity(0.07))
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let label: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        LabeledContent {
            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold))
        } label: {
            Label(label, systemImage: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Snoring Event Row

struct SnoringEventRow: View {
    let event: SnoringEvent

    var body: some View {
        HStack {
            Image(systemName: event.intensityLevel.systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(event.intensityLevel.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(formatOffset(event.timeOffset))
                    .font(.subheadline.weight(.medium))
                Text(event.intensityLevel.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatDuration(event.duration))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func formatOffset(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600, m = (Int(t) % 3600) / 60, s = Int(t) % 60
        return h > 0 ? String(format: "%d:%02d:%02d 経過", h, m, s)
                     : String(format: "%d:%02d 経過", m, s)
    }

    private func formatDuration(_ d: TimeInterval) -> String {
        d < 60 ? "\(Int(d))秒" : "\(Int(d / 60))分\(Int(d.truncatingRemainder(dividingBy: 60)))秒"
    }
}
