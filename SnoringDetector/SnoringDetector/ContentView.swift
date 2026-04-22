import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .home

    enum Tab { case home, history, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("ホーム", systemImage: "moon.zzz.fill") }
                .tag(Tab.home)

            HistoryView()
                .tabItem { Label("記録", systemImage: "chart.bar.fill") }
                .tag(Tab.history)

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .tint(.indigo)
        .fontDesign(.rounded)
    }
}
