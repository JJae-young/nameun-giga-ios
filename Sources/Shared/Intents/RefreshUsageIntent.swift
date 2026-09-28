import AppIntents
import Foundation

struct RefreshUsageIntent: AppIntent {
    static let title: LocalizedStringResource = "데이터 사용량 새로고침"
    static let description = IntentDescription("앱을 열지 않고 셀룰러 데이터 사용량을 새로 측정합니다.")
    static let isDiscoverable = false

    @available(iOS 26.0, *)
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @available(iOS 27.0, *)
    static let allowedExecutionTargets: IntentExecutionTargets = .main

    @MainActor
    func perform() async throws -> some IntentResult {
        #if WIDGET_EXTENSION
        // Execution metadata routes this action to the containing app. This
        // body only keeps the shared intent type available to WidgetKit.
        #else
        do {
            if let summary = try UsageRefreshService().refresh() {
                try WidgetSummaryRepository().write(summary: summary)
            }
        } catch {
            // Preserve the last measured amounts/time, but make a failed tap
            // visible immediately instead of looking like a successful refresh.
            if var previous = WidgetSummaryStore.load() {
                previous.measurementQuality = .unavailable
                try? WidgetSummaryRepository().write(summary: previous)
            }
        }
        WidgetSummaryRepository().reload()
        #endif
        return .result()
    }
}

// This conformance makes iOS run the intent inside the containing app process,
// initially in the background. We never request a foreground continuation.
@available(iOSApplicationExtension, unavailable)
@available(iOS, introduced: 17.0, deprecated: 26.0, message: "Compatibility path for iOS 17–25 interactive widgets")
extension RefreshUsageIntent: ForegroundContinuableIntent {}
