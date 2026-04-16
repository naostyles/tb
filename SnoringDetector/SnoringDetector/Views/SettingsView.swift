import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @AppStorage("amplitudeThreshold") var amplitudeThreshold: Double = 0.015
    @AppStorage("snoringFrequencyLow") var snoringFrequencyLow: Double = 80
    @AppStorage("snoringFrequencyHigh") var snoringFrequencyHigh: Double = 500
    @AppStorage("confirmationWindow") var confirmationWindow: Double = 0.8
    @AppStorage("notifyOnSnoring") var notifyOnSnoring: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("HealthKit連携") {
                    HStack {
                        Label("ヘルスケア", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                        Spacer()
                        if healthKitManager.isAuthorized {
                            Label("連携済み", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Button("連携する") {
                                Task { try? await healthKitManager.requestAuthorization() }
                            }
                            .font(.caption)
                        }
                    }
                }

                Section("Apple Watch") {
                    HStack {
                        Label("Apple Watch", systemImage: "applewatch")
                        Spacer()
                        if watchConnectivity.isWatchReachable {
                            Label("接続済み", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text("未接続")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }

                Section {
                    sliderRow(
                        title: "検出感度",
                        valueLabel: sensitivityLabel(amplitudeThreshold),
                        value: $amplitudeThreshold,
                        range: 0.005...0.05,
                        step: 0.005
                    )
                    sliderRow(
                        title: "検出周波数（低）",
                        valueLabel: "\(Int(snoringFrequencyLow)) Hz",
                        value: $snoringFrequencyLow,
                        range: 50...200,
                        step: 10
                    )
                    sliderRow(
                        title: "検出周波数（高）",
                        valueLabel: "\(Int(snoringFrequencyHigh)) Hz",
                        value: $snoringFrequencyHigh,
                        range: 300...800,
                        step: 50
                    )
                    sliderRow(
                        title: "確認時間",
                        valueLabel: String(format: "%.1f秒", confirmationWindow),
                        value: $confirmationWindow,
                        range: 0.3...2.0,
                        step: 0.1
                    )
                } header: {
                    Text("検出設定")
                } footer: {
                    Text("感度を上げると小さないびきも検出できますが、誤検出が増える場合があります。")
                }

                Section("通知") {
                    Toggle("いびき検出時に通知", isOn: $notifyOnSnoring)
                }

                Section("このアプリについて") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0").foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://www.apple.com/jp/privacy/")!) {
                        HStack {
                            Text("プライバシーポリシー")
                            Spacer()
                            Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("設定")
        }
    }

    @ViewBuilder
    private func sliderRow(title: String, valueLabel: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(valueLabel).foregroundStyle(.secondary).font(.caption)
            }
            Slider(value: value, in: range, step: step) { _ in applySettings() }
        }
    }

    private func applySettings() {
        var config = SnoringDetectionEngine.Configuration()
        config.amplitudeThreshold      = Float(amplitudeThreshold)
        config.snoringFrequencyLow     = Float(snoringFrequencyLow)
        config.snoringFrequencyHigh    = Float(snoringFrequencyHigh)
        config.confirmationWindowSeconds = confirmationWindow
        SnoringDetectionEngine.shared.configuration = config
    }

    private func sensitivityLabel(_ threshold: Double) -> String {
        switch threshold {
        case 0..<0.015:  return "高"
        case 0.015..<0.030: return "中"
        default:         return "低"
        }
    }
}
