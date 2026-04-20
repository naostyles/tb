import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .dashboard

    enum Tab {
        case dashboard, history, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("ダッシュボード", systemImage: "moon.zzz.fill")
                }
                .tag(Tab.dashboard)

            HistoryView()
                .tabItem {
                    Label("履歴", systemImage: "chart.bar.fill")
                }
                .tag(Tab.history)

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(.indigo)
        .fontDesign(.rounded)
    }
}
