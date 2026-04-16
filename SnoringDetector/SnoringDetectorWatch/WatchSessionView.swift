import SwiftUI
import WatchKit

struct WatchSessionView: View {
    @EnvironmentObject var dataModel: WatchDataModel
    @EnvironmentObject var connectivity: WatchConnectivityService

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(status.color.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: status.icon)
                    .font(.system(size: 26))
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
                    .frame(width: 100)
            }

            Spacer()

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
        .containerBackground(.background, for: .navigation)
        .navigationTitle("いびき検出")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var status: (color: Color, icon: String, text: String) {
        guard dataModel.isRecording else {
            return (.indigo, "moon.zzz.fill", "待機中")
        }
        return dataModel.isSnoringDetected
            ? (.orange, "waveform.badge.exclamationmark", "いびき検出!")
            : (.green,  "waveform",                      "静かです")
    }
}

struct WatchSummaryView: View {
    @EnvironmentObject var dataModel: WatchDataModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("前回の記録")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let summary = dataModel.lastSummary {
                    HStack {
                        Text("\(summary.qualityScore)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(summary.qualityColor)
                        VStack(alignment: .leading) {
                            Text("睡眠スコア")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(summary.qualityLabel)
                                .font(.caption.bold())
                                .foregroundStyle(summary.qualityColor)
                        }
                    }

                    Divider()

                    WatchStatRow(label: "睡眠時間", value: summary.formattedDuration)
                    WatchStatRow(label: "いびき",   value: String(format: "%.0f%%", summary.snoringPercentage))
                    WatchStatRow(label: "検出回数", value: "\(summary.eventCount)回")
                } else {
                    Text("まだ記録がありません")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }
}
