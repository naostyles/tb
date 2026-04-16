import SwiftUI

@main
struct SnoringDetectorWatchApp: App {
    @StateObject private var connectivityService = WatchConnectivityService.shared
    @StateObject private var dataModel = WatchDataModel.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(connectivityService)
                .environmentObject(dataModel)
        }
    }
}
