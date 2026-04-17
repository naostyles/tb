import Foundation
import UserNotifications

@MainActor
final class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()

    @Published var isEnabled = false
    @Published var scheduledTime = Date()
    @Published var shouldAutoStart = false

    private let notificationID = "snoring_daily_schedule"
    private let enabledKey     = "scheduleEnabled"
    private let timeKey        = "scheduleTime"

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        let ts = UserDefaults.standard.double(forKey: timeKey)
        scheduledTime = ts > 0
            ? Date(timeIntervalSince1970: ts)
            : Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    }

    func setEnabled(_ enabled: Bool) async {
        if enabled {
            guard await requestPermission() else { return }
        }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        enabled ? scheduleNotification() : cancelNotification()
    }

    func setTime(_ time: Date) {
        scheduledTime = time
        UserDefaults.standard.set(time.timeIntervalSince1970, forKey: timeKey)
        if isEnabled { scheduleNotification() }
    }

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

    var formattedTime: String {
        AppDateFormatter.shortTime.string(from: scheduledTime)
    }
}
