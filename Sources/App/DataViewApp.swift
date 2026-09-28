import SwiftUI
import WidgetKit

@main
struct DataViewApp: App {
    @StateObject private var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let model = AppModel()
        _appModel = StateObject(wrappedValue: model)
        BackgroundRefreshCoordinator.register(appModel: model)
    }

    var body: some Scene {
        WindowGroup {
            DataViewThemeHost {
                RootView()
            }
                .environmentObject(appModel)
                .onOpenURL { url in
                    NotificationCenter.default.post(name: .dataViewDeepLink, object: url)
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        appModel.refresh()
                    case .background:
                        appModel.refresh()
                        BackgroundRefreshCoordinator.schedule()
                    default:
                        break
                    }
                }
        }
    }
}

private struct DataViewThemeHost<Content: View>: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("displayTheme") private var appearanceMode = DataViewAppearanceMode.system.rawValue
    @AppStorage("visualTheme") private var visualTheme = DataViewVisualTheme.classicBlue.rawValue

    @ViewBuilder let content: Content

    private var preferences: WidgetAppearancePreferences {
        WidgetAppearancePreferences(
            appearanceMode: DataViewAppearanceMode(rawValue: appearanceMode) ?? .system,
            visualTheme: DataViewVisualTheme(rawValue: visualTheme) ?? .classicBlue
        )
    }

    private var palette: DVThemePalette {
        DVThemePalette.resolve(
            visualTheme: preferences.visualTheme,
            appearanceMode: preferences.appearanceMode,
            systemColorScheme: systemColorScheme
        )
    }

    var body: some View {
        content
            .environment(\.dvTheme, palette)
            .tint(palette.accentMintStrong)
            .preferredColorScheme(preferredColorScheme)
            .onAppear {
                publishAppearance(preferences)
            }
            .onChange(of: preferences) { _, newValue in
                publishAppearance(newValue)
            }
    }

    private var preferredColorScheme: ColorScheme? {
        switch preferences.appearanceMode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    private func publishAppearance(_ value: WidgetAppearancePreferences) {
        try? WidgetAppearancePreferencesStore().save(value)
        WidgetCenter.shared.reloadTimelines(ofKind: "DataViewUsageWidget")
    }
}

extension Notification.Name {
    static let dataViewDeepLink = Notification.Name("DataViewDeepLink")
}
