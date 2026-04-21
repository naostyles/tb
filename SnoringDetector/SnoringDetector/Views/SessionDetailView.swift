import SwiftUI
import Charts

struct SessionDetailView: View {
    @EnvironmentObject var dataStore: DataStore
    let session: SleepSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = AudioPlayerManager()

    private var liveSession: SleepSession {
        dataStore.sessions.first(where: { $0.id == session.id }) ?? session
    }

    private var hasAudio: Bool {
        guard let url = liveSession.audioFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    var body: some View {
        NavigationStack {
            List {
                // Score hero
                Section {
                    ScoreHeroView(session: liveSession)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                // Playback
                if hasAudio {
                    Section {
                        AudioPlaybackSection(
                            snoringEvents: liveSession.snoringEvents,
                            player: audioPlayer
                        )
                    } header: {
                        Text("録音の再生")
                    } footer: {
                        Text("オレンジのマーカーがいびきの区間です。マーカーまたは▶ボタンで該当箇所から再生します。")
                    }
                }

                // Key metrics
                Section("詳細データ") {
                    MetricRow(label: "睡眠時間",  value: liveSession.formattedDuration,
                              icon: "clock.fill", tint: .indigo)
                    MetricRow(label: "いびき時間", value: TimeFormat.shortDuration(liveSession.totalSnoringDuration),
                              icon: "waveform",   tint: .orange)
                    MetricRow(label: "いびき割合", value: String(format: "%.1f%%", liveSession.snoringPercentage),
                              icon: "percent",    tint: .purple)
                    MetricRow(label: "いびき回数", value: "\(liveSession.snoringEvents.count)回",
                              icon: "waveform.badge.exclamationmark", tint: .red)
                    MetricRow(label: "寝言回数",   value: "\(liveSession.sleepTalkingEvents.count)回",
                              icon: "text.bubble.fill", tint: .cyan)
                    MetricRow(label: "寝返り回数", value: "\(liveSession.tossEvents.count)回",
                              icon: "figure.roll",      tint: .mint)
                }

                // Watch vitals (only shown when data is available)
                if !liveSession.vitalSamples.isEmpty {
                    VitalsSection(session: liveSession)
                }

                // SAS / Apnea risk
                if !liveSession.apneaEvents.isEmpty {
                    Section {
                        ApneaRiskSection(session: liveSession)
                    } header: {
                        Text("無呼吸リスク（SAS予兆）")
                    } footer: {
                        Text("いびきが止まった後の無音時間を検出します。スコアが高い場合は睡眠外来・耳鼻咽喉科への受診をお勧めします。")
                    }
                }

                // Breathing flow chart
                if !liveSession.breathflowSamples.isEmpty {
                    Section("呼吸フロー") {
                        BreathflowChart(samples: liveSession.breathflowSamples)
                            .padding(.vertical, 8)
                    }
                }

                // Position timeline
                if !liveSession.positionSamples.isEmpty {
                    Section("寝姿勢タイムライン") {
                        PositionTimeline(
                            samples: liveSession.positionSamples,
                            totalDuration: liveSession.duration
                        )
                        .padding(.vertical, 8)
                    }
                }

                // Pinpoint playback (high-intensity moments)
                if hasAudio && !liveSession.snoringEvents.isEmpty {
                    Section("ピンポイント再生（強度順）") {
                        ForEach(liveSession.snoringEvents.sorted { $0.intensity > $1.intensity }.prefix(5)) { event in
                            SnoringEventRow(event: event, onSeek: {
                                audioPlayer.seek(to: event.timeOffset)
                                if !audioPlayer.isPlaying { audioPlayer.play() }
                            })
                        }
                    }
                }

                // Teeth grinding events
                if !liveSession.teethGrindingEvents.isEmpty {
                    Section("歯ぎしりイベント（\(liveSession.teethGrindingEvents.count)件）") {
                        ForEach(liveSession.teethGrindingEvents) { event in
                            TeethGrindingRow(event: event)
                        }
                    }
                }

                // Sleep stage timeline
                if !liveSession.sleepStages.isEmpty {
                    Section("睡眠ステージ") {
                        SleepStageTimeline(
                            stages: liveSession.sleepStages,
                            totalDuration: liveSession.duration
                        )
                        .padding(.vertical, 8)
                    }
                }

                // Ambient noise chart
                if !liveSession.noiseSamples.isEmpty {
                    Section("環境ノイズ") {
                        NoiseLevelChart(samples: liveSession.noiseSamples)
                    }
                }

                // Timeline chart
                Section("いびきタイムライン") {
                    SessionTimelineChart(session: liveSession)
                        .padding(.vertical, 8)
                }

                // Snoring events
                if !liveSession.snoringEvents.isEmpty {
                    Section("いびきイベント（\(liveSession.snoringEvents.count)件）") {
                        ForEach(liveSession.snoringEvents) { event in
                            SnoringEventRow(event: event, onSeek: hasAudio ? {
                                audioPlayer.seek(to: event.timeOffset)
                                if !audioPlayer.isPlaying { audioPlayer.play() }
                            } : nil)
                        }
                    }
                }

                // Sleep talking events
                if !liveSession.sleepTalkingEvents.isEmpty {
                    Section("寝言イベント（\(liveSession.sleepTalkingEvents.count)件）") {
                        ForEach(liveSession.sleepTalkingEvents) { event in
                            SleepTalkingEventRow(event: event)
                        }
                    }
                }

                // Toss events
                if !liveSession.tossEvents.isEmpty {
                    Section("寝返りイベント（\(liveSession.tossEvents.count)件）") {
                        ForEach(liveSession.tossEvents) { event in
                            TossEventRow(event: event)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(liveSession.formattedDate)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear {
            if let url = liveSession.audioFileURL, FileManager.default.fileExists(atPath: url.path) {
                try? audioPlayer.load(url: url)
            }
        }
        .onDisappear { audioPlayer.stop() }
    }
}

// MARK: - Vitals Section

struct VitalsSection: View {
    let session: SleepSession

    var body: some View {
        Section("Apple Watch 計測データ") {
            if let hr = session.averageHeartRate {
                MetricRow(label: "平均心拍数",
                          value: String(format: "%.0f bpm", hr),
                          icon: "heart.fill", tint: .red)
            }
            if let spo2 = session.averageOxygen {
                MetricRow(label: "平均血中酸素",
                          value: String(format: "%.1f%%", spo2 * 100),
                          icon: "lungs.fill", tint: .blue)
            }
            if !session.heartRateSamples.isEmpty {
                HeartRateChartRow(samples: session.heartRateSamples)
            }
            if !session.oxygenSamples.isEmpty {
                OxygenChartRow(samples: session.oxygenSamples)
            }
            if !session.respiratorySamples.isEmpty {
                let avg = session.respiratorySamples.map(\.value).reduce(0, +) / Double(session.respiratorySamples.count)
                MetricRow(
                    label: "平均呼吸数",
                    value: String(format: "%.0f 回/分", avg),
                    icon: "wind", tint: .teal
                )
            }
        }
    }
}

struct HeartRateChartRow: View {
    let samples: [VitalSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("心拍数の推移")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart {
                ForEach(samples) { s in
                    LineMark(x: .value("時刻", s.date), y: .value("bpm", s.value))
                        .foregroundStyle(.red)
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("時刻", s.date), y: .value("bpm", s.value))
                        .foregroundStyle(.red.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: (samples.map(\.value).min() ?? 40) - 5 ... (samples.map(\.value).max() ?? 100) + 5)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { _ in
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))").font(.caption2) } }
                }
            }
            .frame(height: 100)
        }
        .padding(.vertical, 4)
    }
}

struct OxygenChartRow: View {
    let samples: [VitalSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("血中酸素濃度の推移")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart {
                ForEach(samples) { s in
                    LineMark(x: .value("時刻", s.date), y: .value("SpO2", s.value * 100))
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                }
                RuleMark(y: .value("低値", 94))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .trailing) {
                        Text("94%").font(.system(size: 8)).foregroundStyle(.orange)
                    }
            }
            .chartYScale(domain: 88...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { _ in
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))%").font(.caption2) } }
                }
            }
            .frame(height: 100)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sleep Talking Row

struct SleepTalkingEventRow: View {
    let event: SleepTalkingEvent
    var body: some View {
        HStack {
            Image(systemName: "text.bubble.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.cyan)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(TimeFormat.elapsed(event.timeOffset))
                    .font(.subheadline.weight(.medium))
                Text("寝言")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(TimeFormat.shortDuration(event.duration))
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Toss Event Row

struct TossEventRow: View {
    let event: TossEvent
    var body: some View {
        HStack {
            Image(systemName: "figure.roll")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.mint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(TimeFormat.elapsed(event.timeOffset))
                    .font(.subheadline.weight(.medium))
                Text("寝返り")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            // Intensity bar
            GeometryReader { g in
                Capsule().fill(.mint.opacity(0.2))
                    .frame(width: 60, height: 6)
                Capsule().fill(.mint)
                    .frame(width: 60 * event.motionLevel, height: 6)
            }
            .frame(width: 60, height: 6)
        }
    }
}

// MARK: - Playback Section (unchanged from before)

struct AudioPlaybackSection: View {
    let snoringEvents: [SnoringEvent]
    @ObservedObject var player: AudioPlayerManager

    var body: some View {
        VStack(spacing: 16) {
            SnoringTimeline(
                progress: player.progress,
                snoringEvents: snoringEvents,
                duration: player.duration,
                onSeek: { pct in player.seek(to: pct * player.duration) }
            )
            HStack {
                Text(TimeFormat.playback(player.currentTime))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Text(TimeFormat.playback(player.duration))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 44) {
                Button { player.seek(to: player.currentTime - 15) } label: {
                    Image(systemName: "gobackward.15").font(.title2)
                }
                Button { player.togglePlayback() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 54))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.indigo)
                }
                .contentTransition(.symbolEffect(.replace))
                Button { player.seek(to: player.currentTime + 15) } label: {
                    Image(systemName: "goforward.15").font(.title2)
                }
            }
            .foregroundStyle(.primary)
        }
        .padding(.vertical, 8)
    }
}

struct SnoringTimeline: View {
    let progress: Double
    let snoringEvents: [SnoringEvent]
    let duration: TimeInterval
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.15)).frame(height: 6)
                ForEach(snoringEvents) { event in
                    if duration > 0 {
                        Capsule()
                            .fill(event.intensityLevel.color.opacity(0.85))
                            .frame(width: max(CGFloat(event.duration / duration) * w, 4), height: 6)
                            .offset(x: CGFloat(event.timeOffset / duration) * w)
                            .onTapGesture { onSeek(event.timeOffset / duration) }
                    }
                }
                Capsule().fill(.indigo.opacity(0.45)).frame(width: CGFloat(progress) * w, height: 6)
                Circle()
                    .fill(.white).overlay(Circle().stroke(Color.indigo, lineWidth: 2))
                    .frame(width: 16, height: 16)
                    .shadow(color: .indigo.opacity(0.3), radius: 3)
                    .offset(x: CGFloat(progress) * (w - 16))
            }
            .frame(height: 16)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                onSeek(max(0, min(1, v.location.x / w)))
            })
        }
        .frame(height: 16)
    }
}

// MARK: - Score Hero

struct ScoreHeroView: View {
    let session: SleepSession

    var body: some View {
        HStack(spacing: 28) {
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
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 6) {
                Text(session.qualityLabel)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(session.qualityColor)
                Text("睡眠スコア")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(session.formattedDate)
                    .font(.caption).foregroundStyle(.tertiary)
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
            Text(value).font(.system(.body, design: .rounded).weight(.semibold))
        } label: {
            Label(label, systemImage: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
    }
}

// MARK: - Apnea Risk Section

struct ApneaRiskSection: View {
    let session: SleepSession

    var body: some View {
        VStack(spacing: 14) {
            // Gauge + label
            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(session.sasRiskColor.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(session.sasRiskScore) / 100)
                        .stroke(session.sasRiskColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(String(format: "%.0f", session.sasRiskScore))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(session.sasRiskColor)
                        Text("/ 100").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 90, height: 90)

                VStack(alignment: .leading, spacing: 6) {
                    Text(session.sasRiskLabel)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(session.sasRiskColor)
                    Text("SASリスクスコア")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("無呼吸候補: \(session.apneaEvents.count)件")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Severity breakdown
            if !session.apneaEvents.isEmpty {
                let mild   = session.apneaEvents.filter { $0.severity == .mild }.count
                let mod    = session.apneaEvents.filter { $0.severity == .moderate }.count
                let severe = session.apneaEvents.filter { $0.severity == .severe }.count
                HStack(spacing: 16) {
                    if mild   > 0 { ApneaSeverityBadge(label: "軽度",   count: mild,   color: .yellow) }
                    if mod    > 0 { ApneaSeverityBadge(label: "中等度", count: mod,    color: .orange) }
                    if severe > 0 { ApneaSeverityBadge(label: "重度",   count: severe, color: .red)    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ApneaSeverityBadge: View {
    let label: String; let count: Int; let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) \(count)件").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(color.opacity(0.1), in: Capsule())
    }
}

// MARK: - Breathflow Chart

struct BreathflowChart: View {
    let samples: [BreathflowSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("呼吸パターンの推移")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)

            Chart(samples) { s in
                BarMark(
                    x: .value("時刻", s.timeOffset / 60),
                    y: .value("RMS", s.rmsLevel)
                )
                .foregroundStyle(s.state.color)
            }
            .chartXAxisLabel("経過時間（分）", alignment: .trailing)
            .chartYAxis(.hidden)
            .frame(height: 80)

            HStack(spacing: 12) {
                ForEach([
                    ("いびき", Color.orange),
                    ("呼吸",   Color.green),
                    ("無音",   Color.red.opacity(0.7)),
                    ("歯ぎしり", Color.purple)
                ], id: \.0) { label, color in
                    HStack(spacing: 4) {
                        Circle().fill(color).frame(width: 7, height: 7)
                        Text(label)
                    }
                }
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Position Timeline

struct PositionTimeline: View {
    let samples: [SleepPositionSample]
    let totalDuration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if totalDuration > 0 {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(samples) { s in
                            if s.duration > 0 {
                                Rectangle()
                                    .fill(s.position.color)
                                    .frame(width: max(2, geo.size.width * CGFloat(s.duration / totalDuration)))
                                    .overlay(alignment: .bottom) {
                                        if s.duration / totalDuration > 0.08 {
                                            Image(systemName: s.position.icon)
                                                .font(.system(size: 8))
                                                .foregroundStyle(.white)
                                                .padding(.bottom, 2)
                                        }
                                    }
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .frame(height: 30)
            }

            let present = Set(samples.map(\.position))
            HStack(spacing: 12) {
                ForEach(SleepPosition.allCases.filter { present.contains($0) && $0 != .unknown }, id: \.self) { pos in
                    HStack(spacing: 4) {
                        Circle().fill(pos.color).frame(width: 8, height: 8)
                        Text(pos.rawValue)
                    }
                }
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Teeth Grinding Row

struct TeethGrindingRow: View {
    let event: TeethGrindingEvent
    var body: some View {
        HStack {
            Image(systemName: "mouth.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.purple)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(TimeFormat.elapsed(event.timeOffset))
                    .font(.subheadline.weight(.medium))
                Text("歯ぎしり")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(TimeFormat.shortDuration(event.duration))
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sleep Stage Timeline

struct SleepStageTimeline: View {
    let stages: [SleepStage]
    let totalDuration: TimeInterval

    private var deep:  TimeInterval { stages.filter { $0.stage == .deep  }.map(\.duration).reduce(0, +) }
    private var light: TimeInterval { stages.filter { $0.stage == .light }.map(\.duration).reduce(0, +) }
    private var rem:   TimeInterval { stages.filter { $0.stage == .rem   }.map(\.duration).reduce(0, +) }
    private var present: Set<SleepStage.Stage> { Set(stages.map(\.stage)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if totalDuration > 0 {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(stages) { stage in
                            if stage.duration > 0 {
                                Rectangle()
                                    .fill(stage.stage.color)
                                    .frame(width: max(2, geo.size.width * CGFloat(stage.duration / totalDuration)))
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .frame(height: 28)
            }

            HStack(spacing: 12) {
                ForEach(SleepStage.Stage.allCases, id: \.self) { s in
                    if present.contains(s) {
                        HStack(spacing: 4) {
                            Circle().fill(s.color).frame(width: 8, height: 8)
                            Text(s.rawValue)
                        }
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if deep + light + rem > 0 {
                HStack(spacing: 20) {
                    if deep  > 0 { StageDurationLabel(stage: .deep,  duration: deep)  }
                    if light > 0 { StageDurationLabel(stage: .light, duration: light) }
                    if rem   > 0 { StageDurationLabel(stage: .rem,   duration: rem)   }
                }
            }
        }
    }
}

struct StageDurationLabel: View {
    let stage: SleepStage.Stage
    let duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stage.rawValue)
                .font(.caption2)
                .foregroundStyle(stage.color)
            Text(TimeFormat.shortDuration(duration))
                .font(.caption2.weight(.medium))
        }
    }
}

// MARK: - Noise Level Chart

struct NoiseLevelChart: View {
    let samples: [NoiseSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("環境ノイズの推移（1分毎）")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Chart {
                ForEach(samples) { s in
                    AreaMark(x: .value("時刻", s.date), y: .value("レベル", s.rmsLevel))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.teal.opacity(0.5), .teal.opacity(0.05)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("時刻", s.date), y: .value("レベル", s.rmsLevel))
                        .foregroundStyle(.teal)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour)) { _ in
                    AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            Text(String(format: "%.2f", d)).font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 100)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Snoring Event Row

struct SnoringEventRow: View {
    let event: SnoringEvent
    var onSeek: (() -> Void)? = nil

    var body: some View {
        HStack {
            Image(systemName: event.intensityLevel.systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(event.intensityLevel.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(TimeFormat.elapsed(event.timeOffset))
                    .font(.subheadline.weight(.medium))
                Text(event.intensityLevel.rawValue)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(TimeFormat.shortDuration(event.duration))
                .font(.caption.weight(.medium)).foregroundStyle(.secondary)
            if let onSeek {
                Button(action: onSeek) {
                    Image(systemName: "play.circle").font(.title3).foregroundStyle(.indigo)
                }
                .buttonStyle(.plain).padding(.leading, 8)
            }
        }
    }
}
