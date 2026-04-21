import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var selectedPeriod = 7
    @State private var selectedMode: Mode = .history
    @State private var selectedSession: SleepSession?
    @State private var csvExportURL: URL?
    @State private var showingCSVExport = false

    private let periods = [7, 14, 30]

    enum Mode: String, CaseIterable { case history = "履歴", analysis = "分析" }

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
                    VStack(spacing: 0) {
                        Picker("表示モード", selection: $selectedMode) {
                            ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                        switch selectedMode {
                        case .history:
                            historyList
                        case .analysis:
                            AnalysisView(sessions: sessions, periodDays: selectedPeriod)
                        }
                    }
                }
            }
            .navigationTitle(selectedMode == .analysis ? "睡眠分析" : "睡眠履歴")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("期間", selection: $selectedPeriod) {
                        ForEach(periods, id: \.self) { p in Text("過去\(p)日").tag(p) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
            .sheet(item: $selectedSession) { SessionDetailView(session: $0).environmentObject(dataStore) }
            .sheet(isPresented: $showingCSVExport) {
                if let url = csvExportURL { CSVShareSheet(url: url) }
            }
            .toolbar {
                if selectedMode == .history && !dataStore.sessions.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { exportCSV() } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func exportCSV() {
        let csv = dataStore.exportCSV(sessions: sessions)
        let name = "sleep_data_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        csvExportURL = url
        showingCSVExport = true
    }

    private var historyList: some View {
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

// MARK: - Analysis View

struct AnalysisView: View {
    let sessions: [SleepSession]
    let periodDays: Int

    private var daily:       [SleepAnalyzer.DailyPoint]     { SleepAnalyzer.dailyPoints(sessions, days: periodDays) }
    private var weekday:     [SleepAnalyzer.WeekdayPoint]   { SleepAnalyzer.weekdayPattern(sessions) }
    private var distribution:[SleepAnalyzer.IntensitySlice] { SleepAnalyzer.intensityDistribution(sessions) }
    private var highlights:  SleepAnalyzer.Highlights       { SleepAnalyzer.highlights(sessions) }

    var body: some View {
        if sessions.isEmpty {
            ContentUnavailableView(
                "分析するデータがありません",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("この期間には記録がありません")
            )
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    HighlightsCard(highlights: highlights)
                    DailyTrendCard(points: daily)
                    WeekdayCard(points: weekday)
                    IntensityCard(slices: distribution)
                    InsightsCard(highlights: highlights)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Highlights

struct HighlightsCard: View {
    let highlights: SleepAnalyzer.Highlights

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("ハイライト", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                TrendBadge(trend: highlights.trend)
            }

            HStack(spacing: 12) {
                StatTile(
                    value: "\(highlights.totalSessions)",
                    label: "回",
                    caption: "計測",
                    color: .indigo
                )
                StatTile(
                    value: String(format: "%.1f", highlights.avgDurationHours),
                    label: "h",
                    caption: "平均睡眠",
                    color: .blue
                )
                StatTile(
                    value: String(format: "%.0f", highlights.avgSnoringPercentage),
                    label: "%",
                    caption: "平均いびき",
                    color: .orange
                )
                StatTile(
                    value: String(format: "%.0f", highlights.avgQualityScore),
                    label: "点",
                    caption: "平均スコア",
                    color: .green
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let caption: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color.opacity(0.7))
            }
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrendBadge: View {
    let trend: SleepAnalyzer.Trend

    private var style: (String, String, Color)? {
        switch trend {
        case .improving: return ("改善傾向", "arrow.up.right",   .green)
        case .stable:    return ("安定",    "equal",            .blue)
        case .worsening: return ("悪化傾向", "arrow.down.right", .orange)
        case .unknown:   return nil
        }
    }

    var body: some View {
        if let (label, icon, color) = style {
            Label(label, systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: Capsule())
        }
    }
}

// MARK: - Daily Trend

struct DailyTrendCard: View {
    let points: [SleepAnalyzer.DailyPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("いびき割合とスコアの推移")
                .font(.subheadline.weight(.semibold))

            Chart {
                ForEach(points) { p in
                    BarMark(
                        x: .value("日", p.date, unit: .day),
                        y: .value("いびき%", p.snoringPercentage)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo.opacity(0.4), .indigo],
                                       startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(4)
                }
                ForEach(points.filter { $0.sessionCount > 0 }) { p in
                    LineMark(
                        x: .value("日", p.date, unit: .day),
                        y: .value("スコア", p.qualityScore)
                    )
                    .foregroundStyle(.green)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(Circle().strokeBorder(lineWidth: 1.5))
                    .symbolSize(35)
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { v in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            Text("\(Int(d))").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, points.count / 5))) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 170)

            HStack(spacing: 14) {
                LegendDot(color: .indigo, text: "いびき割合")
                LegendDot(color: .green,  text: "品質スコア")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct LegendDot: View {
    let color: Color
    let text: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }
}

// MARK: - Weekday Pattern

struct WeekdayCard: View {
    let points: [SleepAnalyzer.WeekdayPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("曜日別のいびき傾向")
                .font(.subheadline.weight(.semibold))

            Chart {
                ForEach(points) { p in
                    BarMark(
                        x: .value("曜日", p.label),
                        y: .value("いびき%", p.avgSnoringPercentage)
                    )
                    .foregroundStyle(barColor(for: p.avgSnoringPercentage))
                    .cornerRadius(4)
                    .annotation(position: .top, alignment: .center) {
                        if p.sessionCount > 0 {
                            Text(String(format: "%.0f%%", p.avgSnoringPercentage))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...max(40, points.map(\.avgSnoringPercentage).max() ?? 0))
            .chartYAxis(.hidden)
            .frame(height: 130)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func barColor(for pct: Double) -> LinearGradient {
        let base: Color = pct < 10 ? .green : pct < 25 ? .yellow : pct < 40 ? .orange : .red
        return LinearGradient(colors: [base.opacity(0.5), base], startPoint: .bottom, endPoint: .top)
    }
}

// MARK: - Intensity Distribution

struct IntensityCard: View {
    let slices: [SleepAnalyzer.IntensitySlice]

    private var total: Int { slices.reduce(0) { $0 + $1.count } }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("いびき強度の分布")
                .font(.subheadline.weight(.semibold))

            if total == 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("この期間にいびきは検出されませんでした")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                // Horizontal proportional bar
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(slices) { slice in
                            if slice.count > 0 {
                                Rectangle()
                                    .fill(color(for: slice.color))
                                    .frame(width: geo.size.width * CGFloat(slice.count) / CGFloat(total))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .frame(height: 14)

                // Legend with counts
                HStack(spacing: 14) {
                    ForEach(slices) { slice in
                        HStack(spacing: 5) {
                            Circle().fill(color(for: slice.color)).frame(width: 8, height: 8)
                            Text("\(slice.label) \(slice.count)")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func color(for name: String) -> Color {
        switch name {
        case "yellow": return .yellow
        case "orange": return .orange
        case "red":    return .red
        default:       return .gray
        }
    }
}

// MARK: - Insights

struct InsightsCard: View {
    let highlights: SleepAnalyzer.Highlights

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("気づき")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                if let best = highlights.bestSession {
                    InsightRow(
                        icon: "star.fill",
                        color: .green,
                        title: "ベストな睡眠",
                        detail: "\(AppDateFormatter.sessionDate.string(from: best.startDate))・スコア \(best.qualityScore)"
                    )
                }
                if let worst = highlights.worstSession, worst.id != highlights.bestSession?.id {
                    InsightRow(
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        title: "改善の余地",
                        detail: "\(AppDateFormatter.sessionDate.string(from: worst.startDate))・スコア \(worst.qualityScore)"
                    )
                }
                if let longest = highlights.longestSession, longest.totalSnoringDuration > 0 {
                    InsightRow(
                        icon: "waveform.path",
                        color: .indigo,
                        title: "最もいびきが多かった日",
                        detail: "\(AppDateFormatter.sessionDate.string(from: longest.startDate))・" +
                                TimeFormat.longDuration(longest.totalSnoringDuration)
                    )
                }
                InsightRow(
                    icon: "bed.double.fill",
                    color: .blue,
                    title: "就寝時刻のばらつき",
                    detail: bedtimeVarianceLabel(highlights.bedtimeVarianceMinutes)
                )
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func bedtimeVarianceLabel(_ minutes: Double) -> String {
        if minutes < 20 { return "就寝時刻は毎日ほぼ同じです（±\(Int(minutes))分）" }
        if minutes < 60 { return "少しばらつきがあります（±\(Int(minutes))分）" }
        return "就寝時刻が不規則です（±\(Int(minutes))分）。睡眠リズムを整えましょう"
    }
}

// MARK: - CSV Share Sheet

import UIKit

struct CSVShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct InsightRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
