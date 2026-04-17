import SwiftUI
import Charts

// MARK: - History Trend Chart (used in HistoryView)

struct SnoringTrendChart: View {
    let sessions: [SleepSession]

    private var avg: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.snoringPercentage).reduce(0, +) / Double(sessions.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("いびき割合の推移")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "平均 %.0f%%", avg))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Chart {
                ForEach(sessions) { session in
                    BarMark(
                        x: .value("日付", session.startDate, unit: .day),
                        y: .value("いびき割合", session.snoringPercentage)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo.opacity(0.5), .indigo], startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(5)
                }

                RuleMark(y: .value("平均", avg))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .trailing, alignment: .center) {
                        Text("平均").font(.system(size: 9)).foregroundStyle(.orange)
                    }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            Text("\(Int(d))%").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, sessions.count / 5))) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 160)
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - Session Timeline Chart (used in SessionDetailView)

struct SessionTimelineChart: View {
    let session: SleepSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("いびきのタイムライン")
                .font(.headline)

            if session.snoringEvents.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("いびきは検出されませんでした")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                Chart {
                    ForEach(session.snoringEvents) { event in
                        RectangleMark(
                            xStart: .value("開始", event.timeOffset / 60),
                            xEnd:   .value("終了", (event.timeOffset + max(event.duration, 0.5)) / 60),
                            y:      .value("強度", event.intensity)
                        )
                        .foregroundStyle(event.intensityLevel.color.gradient)
                        .cornerRadius(3)
                    }
                }
                .chartXAxisLabel("経過時間（分）", alignment: .trailing)
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 0.5, 1]) { v in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text(d == 0 ? "低" : d == 1 ? "高" : "")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 110)
            }
        }
    }
}
