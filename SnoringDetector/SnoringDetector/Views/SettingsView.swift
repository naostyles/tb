import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @StateObject private var powerManager = PowerManager.shared
    @AppStorage("amplitudeThreshold")   var amplitudeThreshold:   Double = 0.010
    @AppStorage("snoringFrequencyLow")  var snoringFrequencyLow:  Double = 80
    @AppStorage("snoringFrequencyHigh") var snoringFrequencyHigh: Double = 500
    @AppStorage("confirmationWindow")   var confirmationWindow:   Double = 0.5
    @AppStorage("snoringEnergyRatio")   var snoringEnergyRatio:   Double = 0.45
    @AppStorage("rejectNonSnoring")     var rejectNonSnoring:     Bool   = true
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

                // Auto-schedule
                Section {
                    Toggle(isOn: Binding(
                        get: { scheduleManager.isEnabled },
                        set: { v in Task { await scheduleManager.setEnabled(v) } }
                    )) {
                        Label("自動計測", systemImage: "clock.badge.fill")
                            .symbolRenderingMode(.hierarchical)
                    }

                    if scheduleManager.isEnabled {
                        DatePicker(
                            "計測開始時刻",
                            selection: Binding(
                                get: { scheduleManager.scheduledTime },
                                set: { scheduleManager.setTime($0) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("スケジュール")
                } footer: {
                    Text("指定した時刻に通知が届きます。タップすると計測が自動で開始されます。バックグラウンドからの自動起動はiOSの制限により通知経由となります。")
                }

                // Power saving
                Section {
                    Toggle(isOn: Binding(
                        get: { powerManager.userLowPowerPreference },
                        set: { v in
                            powerManager.userLowPowerPreference = v
                            SnoringDetectionEngine.shared.configuration.lowPowerMode = powerManager.isLowPowerActive
                        }
                    )) {
                        Label("低電力モード", systemImage: "battery.50")
                            .symbolRenderingMode(.hierarchical)
                    }

                    if powerManager.systemLowPowerMode {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.slash.fill")
                                .foregroundStyle(.yellow)
                            Text("iOSの低電力モードが有効です。自動で省電力で動作します。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("省電力")
                } footer: {
                    Text("解析頻度・画面輝度・通信頻度を抑えてバッテリー消費を約30–40%削減します。")
                }

                // Detection tuning
                Section {
                    Toggle(isOn: $rejectNonSnoring) {
                        Label("いびき以外の音を除外", systemImage: "waveform.slash")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .onChange(of: rejectNonSnoring) { _, _ in applySettings() }

                    sliderRow("検出感度", label: sensitivityLabel(amplitudeThreshold),
                              value: $amplitudeThreshold, in: 0.005...0.05, step: 0.005)
                    sliderRow("いびきらしさ", label: String(format: "%.0f%%", snoringEnergyRatio * 100),
                              value: $snoringEnergyRatio, in: 0.25...0.65, step: 0.05)
                    sliderRow("検出周波数（低）", label: "\(Int(snoringFrequencyLow)) Hz",
                              value: $snoringFrequencyLow, in: 50...200, step: 10)
                    sliderRow("検出周波数（高）", label: "\(Int(snoringFrequencyHigh)) Hz",
                              value: $snoringFrequencyHigh, in: 300...800, step: 50)
                    sliderRow("確認時間", label: String(format: "%.1f 秒", confirmationWindow),
                              value: $confirmationWindow, in: 0.3...2.0, step: 0.1)
                } header: {
                    Text("検出設定")
                } footer: {
                    Text("「いびき以外の音を除外」をオンにすると、会話・テレビ・音楽などの高周波成分が多い音を無視します。")
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
            .onAppear { applySettings() }
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
        var config = SnoringDetectionEngine.shared.configuration
        config.amplitudeThreshold        = Float(amplitudeThreshold)
        config.snoringFrequencyLow       = Float(snoringFrequencyLow)
        config.snoringFrequencyHigh      = Float(snoringFrequencyHigh)
        config.snoringEnergyRatio        = Float(snoringEnergyRatio)
        config.confirmationWindowSeconds = confirmationWindow
        // Relax the aggressive filters when the user turns off "reject non-snoring".
        config.requireRhythm             = rejectNonSnoring
        config.highFrequencyRejectRatio  = rejectNonSnoring ? 0.22 : 1.0
        config.spectralCentroidMax       = rejectNonSnoring ? 450  : 4000
        SnoringDetectionEngine.shared.configuration = config
    }

    private func sensitivityLabel(_ t: Double) -> String {
        switch t {
        case 0..<0.010: return "最高"
        case 0.010..<0.020: return "高"
        case 0.020..<0.030: return "中"
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
