import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var dataModel: WatchDataModel
    @EnvironmentObject var connectivity: WatchConnectivityService

    var body: some View {
        TabView {
            WatchSessionView()
                .environmentObject(dataModel)
                .environmentObject(connectivity)

            WatchSummaryView()
                .environmentObject(dataModel)
        }
        .tabViewStyle(.page)
    }
}
