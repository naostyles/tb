import SwiftUI
import Charts

struct SnoringChartView: View {
    let sessions: [SleepSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("いびき割合の推移")
                .font(.headline)

            if sessions.isEmpty {
                Text("データがありません")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            } else {
                Chart {
                    ForEach(sessions) { session in
                        BarMark(
                            x: .value("日付", session.startDate, unit: .day),
                            y: .value("いびき割合", session.snoringPercentage)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [.indigo, .purple], startPoint: .bottom, endPoint: .top)
                        )
                        .cornerRadius(4)
                        .annotation(position: .top, alignment: .center) {
                            if session.snoringPercentage > 5 {
                                Text(String(format: "%.0f%%", session.snoringPercentage))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    RuleMark(y: .value("平均", averageSnoringPercentage))
                        .foregroundStyle(.orange.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .annotation(position: .trailing) {
                            Text("平均")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))%").font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.month().day()).font(.caption2)
                    }
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private var averageSnoringPercentage: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.snoringPercentage).reduce(0, +) / Double(sessions.count)
    }
}

struct SessionTimelineChart: View {
    let session: SleepSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("いびきのタイムライン")
                .font(.headline)

            if session.snoringEvents.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title)
                    Text("いびきは検出されませんでした")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                Chart {
                    ForEach(session.snoringEvents) { event in
                        RectangleMark(
                            xStart: .value("開始", event.timeOffset / 60),
                            xEnd:   .value("終了", (event.timeOffset + event.duration) / 60),
                            y:      .value("強度", event.intensity)
                        )
                        .foregroundStyle(event.intensityLevel.color.opacity(0.8))
                        .cornerRadius(2)
                    }
                }
                .chartXAxisLabel("経過時間（分）")
                .chartYAxisLabel("強度")
                .chartYScale(domain: 0...1)
                .frame(height: 120)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}
