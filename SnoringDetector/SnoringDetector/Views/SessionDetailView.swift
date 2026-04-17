import SwiftUI

struct SessionDetailView: View {
    let session: SleepSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = AudioPlayerManager()

    private var hasAudio: Bool {
        guard let url = session.audioFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    var body: some View {
        NavigationStack {
            List {
                // Score hero
                Section {
                    ScoreHeroView(session: session)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                // Playback
                if hasAudio {
                    Section {
                        AudioPlaybackSection(
                            snoringEvents: session.snoringEvents,
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
                            SnoringEventRow(event: event, onSeek: hasAudio ? {
                                audioPlayer.seek(to: event.timeOffset)
                                if !audioPlayer.isPlaying { audioPlayer.play() }
                            } : nil)
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
        .onAppear {
            if let url = session.audioFileURL, FileManager.default.fileExists(atPath: url.path) {
                try? audioPlayer.load(url: url)
            }
        }
        .onDisappear { audioPlayer.stop() }
    }

    private func formatSnoringTime(_ d: TimeInterval) -> String {
        let m = Int(d) / 60, s = Int(d) % 60
        return m > 0 ? "\(m)分\(s)秒" : "\(s)秒"
    }
}

// MARK: - Playback Section

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
                Text(formatTime(player.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatTime(player.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
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

    private func formatTime(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Snoring Timeline Scrubber

struct SnoringTimeline: View {
    let progress: Double
    let snoringEvents: [SnoringEvent]
    let duration: TimeInterval
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.secondary.opacity(0.15))
                    .frame(height: 6)

                ForEach(snoringEvents) { event in
                    if duration > 0 {
                        Capsule()
                            .fill(event.intensityLevel.color.opacity(0.85))
                            .frame(
                                width: max(CGFloat(event.duration / duration) * w, 4),
                                height: 6
                            )
                            .offset(x: CGFloat(event.timeOffset / duration) * w)
                            .onTapGesture { onSeek(event.timeOffset / duration) }
                    }
                }

                Capsule()
                    .fill(.indigo.opacity(0.45))
                    .frame(width: CGFloat(progress) * w, height: 6)

                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(Color.indigo, lineWidth: 2))
                    .frame(width: 16, height: 16)
                    .shadow(color: .indigo.opacity(0.3), radius: 3)
                    .offset(x: CGFloat(progress) * (w - 16))
            }
            .frame(height: 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in onSeek(max(0, min(1, v.location.x / w))) }
            )
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
    var onSeek: (() -> Void)? = nil

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

            if let onSeek {
                Button(action: onSeek) {
                    Image(systemName: "play.circle")
                        .font(.title3)
                        .foregroundStyle(.indigo)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
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
