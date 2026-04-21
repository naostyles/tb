import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @StateObject private var powerManager = PowerManager.shared
    @AppStorage("amplitudeThreshold")    var amplitudeThreshold:    Double = 0.006
    @AppStorage("snoringFrequencyLow")   var snoringFrequencyLow:   Double = 50
    @AppStorage("snoringFrequencyHigh")  var snoringFrequencyHigh:  Double = 500
    @AppStorage("confirmationWindow")    var confirmationWindow:    Double = 0.5
    @AppStorage("snoringEnergyRatio")    var snoringEnergyRatio:    Double = 0.28
    @AppStorage("rejectNonSnoring")      var rejectNonSnoring:      Bool   = true
    @AppStorage("detectSleepTalking")    var detectSleepTalking:    Bool   = true
    @AppStorage("motionSensitivity")     var motionSensitivity:     Double = 0.5
    @AppStorage("notifyOnSnoring")       var notifyOnSnoring:       Bool   = true
    @AppStorage("snoringAlertEnabled")   var snoringAlertEnabled:   Bool   = true
    @AppStorage("snoringAlertMinutes")   var snoringAlertMinutes:   Double = 3.0

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
                            Button("連携する") { Task { try? await HealthKitManager.shared.requestAuthorization() } }
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

                // Smart alarm
                Section {
                    Toggle(isOn: Binding(
                        get: { scheduleManager.smartAlarmEnabled },
                        set: { v in
                            scheduleManager.setSmartAlarm(
                                enabled: v,
                                wakeTime: scheduleManager.smartAlarmWakeTime,
                                windowMinutes: scheduleManager.smartAlarmWindowMinutes
                            )
                        }
                    )) {
                        Label("スマートアラーム", systemImage: "alarm.fill")
                            .symbolRenderingMode(.hierarchical)
                    }

                    if scheduleManager.smartAlarmEnabled {
                        DatePicker(
                            "起床目標時刻",
                            selection: Binding(
                                get: { scheduleManager.smartAlarmWakeTime },
                                set: { t in
                                    scheduleManager.setSmartAlarm(
                                        enabled: true,
                                        wakeTime: t,
                                        windowMinutes: scheduleManager.smartAlarmWindowMinutes
                                    )
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )

                        sliderRow(
                            "起床ウィンドウ",
                            label: "\(scheduleManager.smartAlarmWindowMinutes)分前から",
                            value: Binding(
                                get: { Double(scheduleManager.smartAlarmWindowMinutes) },
                                set: { v in
                                    scheduleManager.setSmartAlarm(
                                        enabled: true,
                                        wakeTime: scheduleManager.smartAlarmWakeTime,
                                        windowMinutes: Int(v)
                                    )
                                }
                            ),
                            in: 10...60, step: 5
                        )
                    }
                } header: {
                    Text("スマートアラーム")
                } footer: {
                    Text("起床目標時刻の前に浅い眠りを検出すると、最適なタイミングで起こします。バックアップとして目標時刻にも通知が届きます。")
                }

                // Sleep monitoring features
                Section {
                    Toggle(isOn: $detectSleepTalking) {
                        Label("寝言の検出", systemImage: "text.bubble.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .onChange(of: detectSleepTalking) { _, _ in applySettings() }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("寝返り感度", systemImage: "figure.roll")
                                .symbolRenderingMode(.hierarchical)
                                .font(.subheadline)
                            Spacer()
                            Text(motionSensitivityLabel(motionSensitivity))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Slider(value: $motionSensitivity, in: 0.2...1.2, step: 0.1) { _ in
                            MotionDetector.shared.motionSensitivity = motionSensitivity
                        }
                        .tint(.mint)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("睡眠計測")
                } footer: {
                    Text("寝言はマイクから音声解析、寝返りは加速度センサーで検出します。端末をベッドの近くに置いてください。")
                }

                // Screen
                Section {
                    Toggle(isOn: $powerManager.screenAutoDimEnabled) {
                        Label("画面の自動消灯", systemImage: "moon.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    if powerManager.screenAutoDimEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("消灯までの時間")
                                    .font(.subheadline)
                                Spacer()
                                Text(dimDelayLabel(powerManager.screenDimDelaySeconds))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Slider(value: $powerManager.screenDimDelaySeconds, in: 15...300, step: 15)
                                .tint(.indigo)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("画面")
                } footer: {
                    Text("計測開始から指定時間後に画面をほぼ消灯し、バッテリーを節約します。タップで一時的に明るくなります。")
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
                              value: $amplitudeThreshold, in: 0.003...0.04, step: 0.001)
                    sliderRow("いびきらしさ", label: String(format: "%.0f%%", snoringEnergyRatio * 100),
                              value: $snoringEnergyRatio, in: 0.15...0.55, step: 0.05)
                    sliderRow("検出周波数（低）", label: "\(Int(snoringFrequencyLow)) Hz",
                              value: $snoringFrequencyLow, in: 30...200, step: 10)
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
                Section {
                    Toggle(isOn: $notifyOnSnoring) {
                        Label("いびき検出時に通知", systemImage: "bell.badge.fill")
                            .symbolRenderingMode(.hierarchical)
                    }

                    Toggle(isOn: $snoringAlertEnabled) {
                        Label("いびき持続通知", systemImage: "bell.badge.waveform.fill")
                            .symbolRenderingMode(.hierarchical)
                    }

                    if snoringAlertEnabled {
                        sliderRow(
                            "通知するまでの時間",
                            label: "\(Int(snoringAlertMinutes))分間続いたら",
                            value: $snoringAlertMinutes,
                            in: 1...15, step: 1
                        )
                    }
                } header: {
                    Text("通知")
                } footer: {
                    Text("「いびき持続通知」は指定時間以上連続でいびきが続いた際に通知します。")
                }

                // Watch haptic intervention
                Section {
                    Toggle(isOn: Binding(
                        get: { watchConnectivity.isWatchReachable && UserDefaults.standard.bool(forKey: "watchHapticEnabled") },
                        set: { v in UserDefaults.standard.set(v, forKey: "watchHapticEnabled") }
                    )) {
                        Label("いびき検知で Apple Watch を振動", systemImage: "applewatch.radiowaves.left.and.right")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(!watchConnectivity.isWatchReachable)
                } header: {
                    Text("スマート介入")
                } footer: {
                    Text("いびきを検知すると Apple Watch が微弱な振動を発し、覚醒させずに寝返りを促します。Watch のペアリングが必要です。")
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
        config.rejectNonSnoring          = rejectNonSnoring
        config.detectSleepTalking        = detectSleepTalking
        SnoringDetectionEngine.shared.configuration = config
        MotionDetector.shared.motionSensitivity = motionSensitivity
    }

    private func motionSensitivityLabel(_ v: Double) -> String {
        switch v {
        case 0..<0.35: return "最高"
        case 0.35..<0.6: return "高"
        case 0.6..<0.9: return "中"
        default: return "低"
        }
    }

    private func dimDelayLabel(_ seconds: Double) -> String {
        let s = Int(seconds)
        return s < 60 ? "\(s)秒" : "\(s / 60)分"
    }

    private func sensitivityLabel(_ t: Double) -> String {
        switch t {
        case 0..<0.008: return "最高"
        case 0.008..<0.015: return "高"
        case 0.015..<0.025: return "中"
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
