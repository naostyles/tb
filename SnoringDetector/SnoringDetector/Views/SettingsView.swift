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
                // HealthKit section
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
                                Task {
                                    try? await healthKitManager.requestAuthorization()
                                }
                            }
                            .font(.caption)
                        }
                    }
                }

                // Apple Watch section
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

                // Detection settings
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("検出感度")
                            Spacer()
                            Text(sensitivityLabel(amplitudeThreshold))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $amplitudeThreshold, in: 0.005...0.05, step: 0.005) { _ in
                            applySettings()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("検出周波数（低）")
                            Spacer()
                            Text("\(Int(snoringFrequencyLow)) Hz")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $snoringFrequencyLow, in: 50...200, step: 10) { _ in
                            applySettings()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("検出周波数（高）")
                            Spacer()
                            Text("\(Int(snoringFrequencyHigh)) Hz")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $snoringFrequencyHigh, in: 300...800, step: 50) { _ in
                            applySettings()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("確認時間")
                            Spacer()
                            Text(String(format: "%.1f秒", confirmationWindow))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $confirmationWindow, in: 0.3...2.0, step: 0.1) { _ in
                            applySettings()
                        }
                    }
                } header: {
                    Text("検出設定")
                } footer: {
                    Text("感度を上げると小さないびきも検出できますが、誤検出が増える場合があります。")
                }

                // Notification
                Section("通知") {
                    Toggle("いびき検出時に通知", isOn: $notifyOnSnoring)
                }

                // About
                Section("このアプリについて") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(string: "https://www.apple.com/jp/privacy/")!) {
                        HStack {
                            Text("プライバシーポリシー")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("設定")
        }
    }

    private func applySettings() {
        Task { @MainActor in
            SnoringDetectionEngine.shared.amplitudeThreshold = Float(amplitudeThreshold)
            SnoringDetectionEngine.shared.snoringFrequencyLow = Float(snoringFrequencyLow)
            SnoringDetectionEngine.shared.snoringFrequencyHigh = Float(snoringFrequencyHigh)
            SnoringDetectionEngine.shared.confirmationWindowSeconds = confirmationWindow
        }
    }

    private func sensitivityLabel(_ threshold: Double) -> String {
        switch threshold {
        case 0..<0.015: return "高"
        case 0.015..<0.030: return "中"
        default: return "低"
        }
    }
}
