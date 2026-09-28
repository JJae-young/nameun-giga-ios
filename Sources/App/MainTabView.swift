import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case home
        case statistics
        case settings
    }

    @Environment(\.dvTheme) private var theme
    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem { Label("홈", systemImage: "gauge.with.dots.needle.67percent") }
                .tag(Tab.home)
            StatisticsView()
                .tabItem { Label("통계", systemImage: "chart.bar.xaxis") }
                .tag(Tab.statistics)
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .tint(theme.accentMintStrong)
        .onReceive(NotificationCenter.default.publisher(for: .dataViewDeepLink)) { notification in
            guard let url = notification.object as? URL else { return }
            switch url.host {
            case "statistics": selection = .statistics
            case "dashboard": selection = .home
            default: break
            }
        }
    }
}
