import SwiftUI

@main
struct SnoringDetectorApp: App {
    @StateObject private var dataStore = DataStore.shared
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(healthKitManager)
                .environmentObject(watchConnectivity)
        }
    }
}
