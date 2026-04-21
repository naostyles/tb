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

                // Timeline chart
                Section("タイムライン") {
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
            if let avg = session.respiratorySamples.map(\.value).reduce(0, +) as Double?,
               !session.respiratorySamples.isEmpty {
                MetricRow(
                    label: "平均呼吸数",
                    value: String(format: "%.0f 回/分", avg / Double(session.respiratorySamples.count)),
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
