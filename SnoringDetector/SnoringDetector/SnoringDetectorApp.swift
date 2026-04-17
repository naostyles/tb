import SwiftUI

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
