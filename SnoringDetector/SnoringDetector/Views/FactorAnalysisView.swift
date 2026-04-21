import SwiftUI
import Charts

// MARK: - Factor Analysis View

struct FactorAnalysisView: View {
    let sessions: [SleepSession]
    @EnvironmentObject var dataStore: DataStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CountermeasureEffectCard(sessions: sessions, logs: dataStore.lifestyleLogs)
                LifestyleCorrelationCard(sessions: sessions, logs: dataStore.lifestyleLogs)
                PositionAnalysisCard(sessions: sessions)
                ExerciseTrendCard(logs: dataStore.lifestyleLogs)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Countermeasure Effect Card

struct CountermeasureEffectCard: View {
    let sessions: [SleepSession]
    let logs: [LifestyleLog]

    private struct MeasurePoint: Identifiable {
        let id: String
        let name: String
        let withScore: Double
        let withoutScore: Double
        var improvement: Double { withoutScore - withScore }
    }

    private var points: [MeasurePoint] {
        Countermeasure.allCases.compactMap { measure in
            // Find sessions where this measure was logged
            let logDays = logs.filter { $0.countermeasures.contains(measure) }
            let logDates = Set(logDays.map { Calendar.current.startOfDay(for: $0.date) })

            let withSessions    = sessions.filter { logDates.contains(Calendar.current.startOfDay(for: $0.startDate)) }
            let withoutSessions = sessions.filter { !logDates.contains(Calendar.current.startOfDay(for: $0.startDate)) }
            guard !withSessions.isEmpty, !withoutSessions.isEmpty else { return nil }

            let withSnore    = withSessions.map(\.snoringPercentage).reduce(0, +) / Double(withSessions.count)
            let withoutSnore = withoutSessions.map(\.snoringPercentage).reduce(0, +) / Double(withoutSessions.count)
            return MeasurePoint(id: measure.rawValue, name: measure.rawValue,
                                withScore: withSnore, withoutScore: withoutSnore)
        }
        .sorted { abs($0.improvement) > abs($1.improvement) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("対策の効果比較", systemImage: "chart.bar.fill")
                .font(.subheadline.weight(.semibold))

            if points.isEmpty {
                emptyState("複数の対策を記録するとここに効果の比較が表示されます")
            } else {
                Chart(points) { p in
                    BarMark(x: .value("対策なし", p.withoutScore), y: .value("対策", p.name))
                        .foregroundStyle(.gray.opacity(0.3))
                        .cornerRadius(4)
                    BarMark(x: .value("対策あり", p.withScore), y: .value("対策", p.name))
                        .foregroundStyle(p.improvement > 0 ? Color.green.gradient : Color.orange.gradient)
                        .cornerRadius(4)
                }
                .chartXAxisLabel("いびき割合（%）")
                .frame(height: CGFloat(max(100, points.count * 44)))

                HStack(spacing: 14) {
                    LegendDot(color: .green.opacity(0.7),  text: "対策あり")
                    LegendDot(color: .gray.opacity(0.4),   text: "対策なし")
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Lifestyle Correlation Card

struct LifestyleCorrelationCard: View {
    let sessions: [SleepSession]
    let logs: [LifestyleLog]

    private enum Factor: String, CaseIterable {
        case alcohol = "飲酒量"
        case exercise = "運動（分）"
        case fatigue = "疲労度"
    }

    @State private var selectedFactor: Factor = .alcohol

    private struct ScatterPoint: Identifiable {
        let id = UUID()
        let factorValue: Double
        let snoringPct: Double
    }

    private var scatterData: [ScatterPoint] {
        sessions.compactMap { session in
            let day = Calendar.current.startOfDay(for: session.startDate)
            guard let log = logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) })
            else { return nil }
            let x: Double
            switch selectedFactor {
            case .alcohol:  x = log.alcoholUnits
            case .exercise: x = Double(log.exerciseMinutes)
            case .fatigue:  x = Double(log.fatigueLevel)
            }
            return ScatterPoint(factorValue: x, snoringPct: session.snoringPercentage)
        }
    }

    private var correlation: Double {
        guard scatterData.count >= 3 else { return 0 }
        let xs = scatterData.map(\.factorValue)
        let ys = scatterData.map(\.snoringPct)
        let xMean = xs.reduce(0, +) / Double(xs.count)
        let yMean = ys.reduce(0, +) / Double(ys.count)
        let num = zip(xs, ys).reduce(0) { $0 + ($1.0 - xMean) * ($1.1 - yMean) }
        let dX  = xs.reduce(0) { $0 + ($1 - xMean) * ($1 - xMean) }
        let dY  = ys.reduce(0) { $0 + ($1 - yMean) * ($1 - yMean) }
        let denom = sqrt(dX * dY)
        return denom > 0 ? num / denom : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ライフスタイルとの相関", systemImage: "chart.dots.scatter")
                .font(.subheadline.weight(.semibold))

            Picker("要因", selection: $selectedFactor) {
                ForEach(Factor.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if scatterData.isEmpty {
                emptyState("ライフスタイルを記録すると相関グラフが表示されます")
            } else {
                Chart(scatterData) { p in
                    PointMark(
                        x: .value(selectedFactor.rawValue, p.factorValue),
                        y: .value("いびき%", p.snoringPct)
                    )
                    .foregroundStyle(.indigo.opacity(0.7))
                    .symbolSize(60)
                }
                .chartXAxisLabel(selectedFactor.rawValue, alignment: .trailing)
                .chartYAxisLabel("いびき割合（%）")
                .frame(height: 160)

                HStack {
                    Spacer()
                    Text("相関係数: \(String(format: "%.2f", correlation))")
                        .font(.caption2)
                        .foregroundStyle(correlationColor)
                    Text(correlationLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var correlationLabel: String {
        switch abs(correlation) {
        case 0..<0.2: return "（ほぼ無相関）"
        case 0.2..<0.4: return "（弱い相関）"
        case 0.4..<0.7: return "（中程度の相関）"
        default: return "（強い相関）"
        }
    }

    private var correlationColor: Color { correlation > 0.3 ? .orange : correlation < -0.3 ? .green : .secondary }
}

// MARK: - Position Analysis Card

struct PositionAnalysisCard: View {
    let sessions: [SleepSession]

    private struct PositionPoint: Identifiable {
        let id: String
        let position: SleepPosition
        let avgSnoringPct: Double
        let sessionCount: Int
    }

    private var points: [PositionPoint] {
        var byPosition: [SleepPosition: [Double]] = [:]
        for s in sessions {
            let dur = s.duration
            guard dur > 0 else { continue }
            for (pos, snoringDur) in s.snoringDurationByPosition {
                let pct = (snoringDur / dur) * 100
                byPosition[pos, default: []].append(pct)
            }
        }
        return SleepPosition.allCases.filter { $0 != .unknown }.compactMap { pos in
            guard let vals = byPosition[pos], !vals.isEmpty else { return nil }
            return PositionPoint(
                id: pos.rawValue,
                position: pos,
                avgSnoringPct: vals.reduce(0, +) / Double(vals.count),
                sessionCount: vals.count
            )
        }
        .sorted { $0.avgSnoringPct > $1.avgSnoringPct }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("寝姿勢別いびき割合", systemImage: "person.fill")
                .font(.subheadline.weight(.semibold))

            if points.isEmpty {
                emptyState("加速度センサーによる姿勢データが計測されると表示されます")
            } else {
                Chart(points) { p in
                    BarMark(
                        x: .value("姿勢", p.position.rawValue),
                        y: .value("いびき%", p.avgSnoringPct)
                    )
                    .foregroundStyle(p.position.color.gradient)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text(String(format: "%.0f%%", p.avgSnoringPct))
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
                .chartYAxisLabel("平均いびき割合（%）")
                .chartYScale(domain: 0...max(50, (points.map(\.avgSnoringPct).max() ?? 0) + 10))
                .frame(height: 160)

                Text("横向き寝はいびきを軽減することが多いです")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Exercise Trend Card

struct ExerciseTrendCard: View {
    let logs: [LifestyleLog]

    private var recentLogs: [LifestyleLog] {
        logs.filter { $0.date > Date().addingTimeInterval(-30 * 86400) }
            .sorted { $0.date < $1.date }
    }

    private var exerciseDays: Int {
        recentLogs.filter { !$0.exercises.isEmpty }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("口腔エクササイズの継続", systemImage: "figure.mind.and.body")
                .font(.subheadline.weight(.semibold))

            if recentLogs.isEmpty {
                emptyState("エクササイズを記録すると継続状況が表示されます")
            } else {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(exerciseDays)")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(.green)
                        Text("実施日数")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        Text("\(recentLogs.count)")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(.blue)
                        Text("記録日数")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        let rate = recentLogs.isEmpty ? 0 : Double(exerciseDays) / Double(recentLogs.count) * 100
                        Text(String(format: "%.0f%%", rate))
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(.orange)
                        Text("継続率")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)

                // Weekly heatmap
                let weeks = groupByWeek(recentLogs)
                if !weeks.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(weeks.prefix(8), id: \.0) { (weekStart, weekLogs) in
                            VStack(spacing: 3) {
                                ForEach(0..<7, id: \.self) { dayOffset in
                                    let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: weekStart)!
                                    let hasExercise = weekLogs.contains {
                                        Calendar.current.isDate($0.date, inSameDayAs: day) && !$0.exercises.isEmpty
                                    }
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(hasExercise ? Color.green : Color(.systemGray5))
                                        .frame(width: 14, height: 14)
                                }
                            }
                        }
                    }
                    Text("直近8週のエクササイズ実施状況（緑=実施）")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func groupByWeek(_ logs: [LifestyleLog]) -> [(Date, [LifestyleLog])] {
        var dict: [Date: [LifestyleLog]] = [:]
        let cal = Calendar.current
        for log in logs {
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: log.date))!
            dict[weekStart, default: []].append(log)
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }
}

// MARK: - Helpers

private func emptyState(_ message: String) -> some View {
    HStack {
        Image(systemName: "chart.bar.xaxis").foregroundStyle(.secondary)
        Text(message).font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
    .padding(.vertical, 4)
}
