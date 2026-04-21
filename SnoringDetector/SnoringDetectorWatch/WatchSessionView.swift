import SwiftUI
import WatchKit

struct WatchSessionView: View {
    @EnvironmentObject var dataModel: WatchDataModel
    @EnvironmentObject var connectivity: WatchConnectivityService

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(status.color.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: status.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(status.color)
                }
                .padding(.top, 4)

                Text(status.text)
                    .font(.headline)
                    .foregroundStyle(status.color)
                    .multilineTextAlignment(.center)

                if dataModel.isRecording && dataModel.isSnoringDetected {
                    ProgressView(value: dataModel.intensity)
                        .tint(.orange)
                        .frame(width: 90)
                }

                // Live stats
                if dataModel.isRecording {
                    HStack(spacing: 12) {
                        if let hr = dataModel.currentHeartRate {
                            WatchLiveStat(value: "\(hr)", label: "bpm", icon: "heart.fill", color: .red)
                        }
                        WatchLiveStat(value: "\(dataModel.tossCount)", label: "寝返り", icon: "figure.roll", color: .mint)
                    }
                }

                Spacer().frame(height: 4)

                if connectivity.isPhoneReachable {
                    Button {
                        if dataModel.isRecording {
                            connectivity.stopRecordingOnPhone()
                            WKInterfaceDevice.current().play(.stop)
                        } else {
                            connectivity.startRecordingOnPhone()
                            WKInterfaceDevice.current().play(.start)
                        }
                    } label: {
                        Label(
                            dataModel.isRecording ? "停止" : "開始",
                            systemImage: dataModel.isRecording ? "stop.circle.fill" : "moon.zzz.fill"
                        )
                        .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(dataModel.isRecording ? .red : .indigo)
                } else {
                    Text("iPhoneを開いてください")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .containerBackground(.background, for: .navigation)
        .navigationTitle("いびき検出")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var status: (color: Color, icon: String, text: String) {
        guard dataModel.isRecording else {
            return (.indigo, "moon.zzz.fill", "待機中")
        }
        if dataModel.isSnoringDetected {
            return (.orange, "waveform.badge.exclamationmark", "いびき検出!")
        }
        if dataModel.isTalkingDetected {
            return (.cyan, "text.bubble.fill", "寝言検出")
        }
        return (.green, "waveform", "静かです")
    }
}

struct WatchLiveStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.caption2).foregroundStyle(color)
            Text(value)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundStyle(color)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
}

struct WatchSummaryView: View {
    @EnvironmentObject var dataModel: WatchDataModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("前回の記録")
                    .font(.caption).foregroundStyle(.secondary)

                if let s = dataModel.lastSummary {
                    HStack {
                        Text("\(s.qualityScore)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(s.qualityColor)
                        VStack(alignment: .leading) {
                            Text("睡眠スコア").font(.caption2).foregroundStyle(.secondary)
                            Text(s.qualityLabel).font(.caption.bold()).foregroundStyle(s.qualityColor)
                        }
                    }

                    Divider()

                    WatchStatRow(label: "睡眠時間", value: s.formattedDuration)
                    WatchStatRow(label: "いびき",   value: String(format: "%.0f%%", s.snoringPercentage))
                    WatchStatRow(label: "いびき回数", value: "\(s.eventCount)回")
                    if s.talkingCount > 0 {
                        WatchStatRow(label: "寝言", value: "\(s.talkingCount)回")
                    }
                    if s.tossCount > 0 {
                        WatchStatRow(label: "寝返り", value: "\(s.tossCount)回")
                    }
                    if let hr = s.avgHeartRate {
                        WatchStatRow(label: "平均心拍", value: String(format: "%.0f bpm", hr))
                    }
                    if let spo2 = s.avgOxygen {
                        WatchStatRow(label: "血中酸素", value: String(format: "%.1f%%", spo2 * 100))
                    }
                } else {
                    Text("まだ記録がありません")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                }
            }
            .padding()
        }
        .containerBackground(.background, for: .navigation)
        .navigationTitle("サマリー")
    }
}

struct WatchStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.bold())
        }
    }
}
