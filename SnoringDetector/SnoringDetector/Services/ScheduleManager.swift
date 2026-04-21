import Foundation
import UserNotifications

@MainActor
final class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()

    // Daily schedule
    @Published var isEnabled = false
    @Published var scheduledTime = Date()
    @Published var shouldAutoStart = false

    // Smart alarm
    @Published var smartAlarmEnabled = false
    @Published var smartAlarmWakeTime = Date()
    @Published var smartAlarmWindowMinutes: Int = 30
    private var smartAlarmFired = false

    private let notificationID       = "snoring_daily_schedule"
    private let smartAlarmBackupID   = "smart_alarm_backup"
    private let weeklyReportID       = "weekly_sleep_report"
    private let enabledKey           = "scheduleEnabled"
    private let timeKey              = "scheduleTime"
    private let smartAlarmEnabledKey = "smartAlarmEnabled"
    private let smartAlarmTimeKey    = "smartAlarmTime"
    private let smartAlarmWindowKey  = "smartAlarmWindow"

    private init() {
        isEnabled         = UserDefaults.standard.bool(forKey: enabledKey)
        smartAlarmEnabled = UserDefaults.standard.bool(forKey: smartAlarmEnabledKey)
        let windowRaw     = UserDefaults.standard.integer(forKey: smartAlarmWindowKey)
        smartAlarmWindowMinutes = windowRaw > 0 ? windowRaw : 30

        let ts  = UserDefaults.standard.double(forKey: timeKey)
        scheduledTime = ts > 0 ? Date(timeIntervalSince1970: ts) :
            Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()

        let sat = UserDefaults.standard.double(forKey: smartAlarmTimeKey)
        smartAlarmWakeTime = sat > 0 ? Date(timeIntervalSince1970: sat) :
            Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }

    // MARK: - Daily schedule

    func setEnabled(_ enabled: Bool) async {
        if enabled { guard await requestPermission() else { return } }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        enabled ? scheduleNotification() : cancelNotification()
        if enabled { scheduleWeeklyReport() } else { cancelWeeklyReport() }
    }

    func setTime(_ time: Date) {
        scheduledTime = time
        UserDefaults.standard.set(time.timeIntervalSince1970, forKey: timeKey)
        if isEnabled { scheduleNotification() }
    }

    // MARK: - Smart alarm

    func setSmartAlarm(enabled: Bool, wakeTime: Date, windowMinutes: Int) {
        smartAlarmEnabled = enabled
        smartAlarmWakeTime = wakeTime
        smartAlarmWindowMinutes = windowMinutes
        UserDefaults.standard.set(enabled, forKey: smartAlarmEnabledKey)
        UserDefaults.standard.set(wakeTime.timeIntervalSince1970, forKey: smartAlarmTimeKey)
        UserDefaults.standard.set(windowMinutes, forKey: smartAlarmWindowKey)
    }

    /// Schedule a backup alarm at the target wake time.
    func scheduleSmartAlarmBackup() {
        guard smartAlarmEnabled else { return }
        smartAlarmFired = false
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [smartAlarmBackupID])

        let content = UNMutableNotificationContent()
        content.title = "おはようございます"
        content.body  = "目覚まし時刻です。よく眠れましたか？"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.hour, .minute], from: smartAlarmWakeTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: smartAlarmBackupID, content: content, trigger: trigger))
    }

    func cancelSmartAlarmBackup() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [smartAlarmBackupID])
    }

    /// Called every minute to check for light-sleep trigger within the wake window.
    func checkSmartAlarm(motionAvg: Double, tossCount: Int) {
        guard smartAlarmEnabled, !smartAlarmFired else { return }
        let now = Date()
        let windowStart = smartAlarmWakeTime.addingTimeInterval(-Double(smartAlarmWindowMinutes) * 60)
        guard now >= windowStart, now <= smartAlarmWakeTime else { return }
        guard motionAvg > 0.05 || tossCount > 0 else { return }  // light-sleep indicator

        smartAlarmFired = true
        cancelSmartAlarmBackup()
        let content = UNMutableNotificationContent()
        content.title = "おはようございます"
        content.body  = "浅い眠りを検出しました。最適なタイミングでお目覚めです。"
        content.sound = .default
        let req = UNNotificationRequest(identifier: "smart_alarm_early", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - Weekly report (every Monday 08:00)

    private func scheduleWeeklyReport() {
        Task {
            guard await requestPermission() else { return }
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: [weeklyReportID])
            let content = UNMutableNotificationContent()
            content.title = "週次睡眠レポート"
            content.body  = "今週の睡眠データが揃いました。「分析」タブで確認しましょう。"
            content.sound = .default
            var comps = DateComponents()
            comps.weekday = 2; comps.hour = 8; comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: weeklyReportID, content: content, trigger: trigger))
        }
    }

    private func cancelWeeklyReport() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [weeklyReportID])
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized { return true }
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        let content = UNMutableNotificationContent()
        content.title = "いびき計測の時間です"
        content.body  = "タップして計測を自動開始します"
        content.sound = .default
        var comps = Calendar.current.dateComponents([.hour, .minute], from: scheduledTime)
        comps.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger))
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    var formattedTime: String { AppDateFormatter.shortTime.string(from: scheduledTime) }
    var formattedSmartAlarmTime: String { AppDateFormatter.shortTime.string(from: smartAlarmWakeTime) }
}
