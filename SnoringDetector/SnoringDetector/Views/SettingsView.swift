import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @AppStorage("amplitudeThreshold")   var amplitudeThreshold:   Double = 0.015
    @AppStorage("snoringFrequencyLow")  var snoringFrequencyLow:  Double = 80
    @AppStorage("snoringFrequencyHigh") var snoringFrequencyHigh: Double = 500
    @AppStorage("confirmationWindow")   var confirmationWindow:   Double = 0.8
    @AppStorage("notifyOnSnoring")      var notifyOnSnoring:       Bool   = true

    var body: some View {
        NavigationStack {
            List {
                // Privacy section
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "lock.shield.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.indigo)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("すべての解析はこの端末内で完結します")
                                .font(.subheadline.weight(.medium))
                            Text("録音データや解析結果はサーバーに送信されません。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Integrations
                Section("連携") {
                    IntegrationRow(
                        icon: "heart.fill",
                        iconTint: .red,
                        title: "ヘルスケア",
                        isConnected: healthKitManager.isAuthorized
                    ) {
                        if !healthKitManager.isAuthorized {
                            Button("連携する") { Task { try? await healthKitManager.requestAuthorization() } }
                        }
                    }

                    IntegrationRow(
                        icon: "applewatch",
                        iconTint: .primary,
                        title: "Apple Watch",
                        isConnected: watchConnectivity.isWatchReachable
                    ) { EmptyView() }
                }

                // Detection tuning
                Section {
                    sliderRow("検出感度", label: sensitivityLabel(amplitudeThreshold),
                              value: $amplitudeThreshold, in: 0.005...0.05, step: 0.005)
                    sliderRow("検出周波数（低）", label: "\(Int(snoringFrequencyLow)) Hz",
                              value: $snoringFrequencyLow, in: 50...200, step: 10)
                    sliderRow("検出周波数（高）", label: "\(Int(snoringFrequencyHigh)) Hz",
                              value: $snoringFrequencyHigh, in: 300...800, step: 50)
                    sliderRow("確認時間", label: String(format: "%.1f 秒", confirmationWindow),
                              value: $confirmationWindow, in: 0.3...2.0, step: 0.1)
                } header: {
                    Text("検出設定")
                } footer: {
                    Text("感度を高くすると小さないびきも検出できますが、誤検出が増える場合があります。")
                }

                // Notification
                Section("通知") {
                    Toggle(isOn: $notifyOnSnoring) {
                        Label("いびき検出時に通知", systemImage: "bell.badge.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                }

                // About
                Section("このアプリについて") {
                    LabeledContent("バージョン", value: "1.0.0")
                    Link(destination: URL(string: "https://www.apple.com/jp/privacy/")!) {
                        Label("プライバシーポリシー", systemImage: "arrow.up.right.square")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("設定")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sliderRow(
        _ title: String, label: String,
        value: Binding<Double>, in range: ClosedRange<Double>, step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step) { _ in applySettings() }
                .tint(.indigo)
        }
        .padding(.vertical, 2)
    }

    private func applySettings() {
        var config = SnoringDetectionEngine.Configuration()
        config.amplitudeThreshold       = Float(amplitudeThreshold)
        config.snoringFrequencyLow      = Float(snoringFrequencyLow)
        config.snoringFrequencyHigh     = Float(snoringFrequencyHigh)
        config.confirmationWindowSeconds = confirmationWindow
        SnoringDetectionEngine.shared.configuration = config
    }

    private func sensitivityLabel(_ t: Double) -> String {
        switch t {
        case 0..<0.015: return "高"
        case 0.015..<0.030: return "中"
        default: return "低"
        }
    }
}

struct IntegrationRow<Action: View>: View {
    let icon: String
    let iconTint: Color
    let title: String
    let isConnected: Bool
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconTint)
            Spacer()
            if isConnected {
                Label("接続済み", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                action()
                    .font(.caption)
                    .foregroundStyle(.indigo)
            }
        }
    }
}
