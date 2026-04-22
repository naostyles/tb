import SwiftUI
import UIKit
import UserNotifications

@main
struct SnoringDetectorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dataStore       = DataStore.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    @StateObject private var scheduleManager  = ScheduleManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(healthKitManager)
                .environmentObject(watchConnectivity)
                .environmentObject(scheduleManager)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.identifier == "snoring_daily_schedule" {
            Task { @MainActor in ScheduleManager.shared.shouldAutoStart = true }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.identifier == "snoring_daily_schedule" {
            Task { @MainActor in ScheduleManager.shared.shouldAutoStart = true }
        }
        completionHandler([.banner, .sound])
    }
}
