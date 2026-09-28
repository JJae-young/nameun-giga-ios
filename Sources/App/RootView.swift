import SwiftUI

struct RootView: View {
    enum Destination {
        case splash
        case onboarding
        case planSetup
        case main
    }

    @EnvironmentObject private var appModel: AppModel
    @State private var destination: Destination = .splash

    var body: some View {
        Group {
            switch destination {
            case .splash:
                SplashView()
            case .onboarding:
                OnboardingView {
                    destination = .planSetup
                }
            case .planSetup:
                PlanSetupView(plan: appModel.plan ?? .standard, isInitialSetup: true) { plan in
                    if appModel.savePlan(plan) {
                        destination = .main
                        appModel.refresh()
                    }
                }
            case .main:
                MainTabView()
            }
        }
        .task {
            guard destination == .splash else { return }
            try? await Task.sleep(for: .milliseconds(750))
            withAnimation(.easeOut(duration: 0.25)) {
                if appModel.hasCompletedOnboarding {
                    destination = appModel.hasConfiguredPlan ? .main : .planSetup
                } else {
                    destination = .onboarding
                }
            }
        }
    }
}

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(AppModel.preview)
    }
}
#endif
