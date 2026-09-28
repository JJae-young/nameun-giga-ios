import Foundation

/// Performs the same durable measurement used by the app without creating UI.
/// App Intents call this while the app process is running in the background.
struct UsageRefreshService {
    private let settingsRepository: SettingsRepository
    private let usageRepository: UsageRepository
    private let measurementService: UsageMeasurementService
    private let billingCalendar: Calendar
    private let summaryBuilder = UsageSummaryBuilder()

    init(
        settingsRepository: SettingsRepository = SettingsRepository(),
        usageRepository: UsageRepository = UsageRepository(),
        reader: NetworkCounterReading = NetworkCounterReader()
    ) {
        let billingCalendar = BillingCalendarFactory.make(
            for: settingsRepository.loadPlanWithStableBillingTimeZone()
        )
        self.settingsRepository = settingsRepository
        self.usageRepository = usageRepository
        self.billingCalendar = billingCalendar
        self.measurementService = UsageMeasurementService(
            reader: reader,
            repository: usageRepository,
            calendar: billingCalendar
        )
    }

    func refresh(at date: Date = .now) throws -> WidgetSummary? {
        let measurement = try measurementService.measure(at: date)
        guard let storedPlan = settingsRepository.loadPlan() else { return nil }

        let result = summaryBuilder.build(
            plan: storedPlan,
            dailyUsage: usageRepository.dailyUsage(),
            at: date,
            calendar: billingCalendar,
            generatedAt: usageRepository.latestSnapshot()?.measuredAt ?? .distantPast,
            measurementQuality: measurement.quality
        )
        if result.plan != storedPlan {
            try settingsRepository.save(plan: result.plan)
        }
        return result.summary
    }
}
