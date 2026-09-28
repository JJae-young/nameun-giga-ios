import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var plan: PlanSettings?
    @Published private(set) var summary: WidgetSummary = .empty
    @Published private(set) var dailyUsage: [DailyUsage] = []
    @Published private(set) var lastQuality: MeasurementQuality = .unavailable
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?

    private let settingsRepository: SettingsRepository
    private let usageRepository: UsageRepository
    private let widgetRepository: WidgetSummaryRepository
    private let measurementService: UsageMeasurementService
    private let notificationService: UsageNotificationService
    private let billingService = BillingPeriodService()
    let billingCalendar: Calendar
    private let calibrationService = UsageCalibrationService()
    private let hotspotCalibrationService = HotspotCalibrationService()
    private let summaryBuilder = UsageSummaryBuilder()

    init(
        settingsRepository: SettingsRepository = SettingsRepository(),
        usageRepository: UsageRepository = UsageRepository(),
        widgetRepository: WidgetSummaryRepository = WidgetSummaryRepository(),
        reader: NetworkCounterReading = NetworkCounterReader(),
        notificationService: UsageNotificationService? = nil
    ) {
        let storedPlan = settingsRepository.loadPlanWithStableBillingTimeZone()
        let billingCalendar = BillingCalendarFactory.make(for: storedPlan)
        self.settingsRepository = settingsRepository
        self.usageRepository = usageRepository
        self.widgetRepository = widgetRepository
        self.measurementService = UsageMeasurementService(
            reader: reader,
            repository: usageRepository,
            calendar: billingCalendar
        )
        self.notificationService = notificationService ?? UsageNotificationService()
        self.billingCalendar = billingCalendar
        self.plan = storedPlan
        self.lastQuality = usageRepository.samples().last?.measurementQuality ?? .unavailable
        // An App Intent can cold-launch the app in the background. Keep this
        // initial rebuild in memory so a failed intent never looks successful
        // by overwriting the widget's last-refresh timestamp.
        rebuildSummary(at: .now, publishToWidget: false)
    }

    var hasCompletedOnboarding: Bool { settingsRepository.hasCompletedOnboarding }
    var hasConfiguredPlan: Bool { plan != nil }

    func completeOnboarding() {
        settingsRepository.setOnboardingCompleted()
    }

    @discardableResult
    func savePlan(_ newPlan: PlanSettings, resettingInputs: Bool = false, at now: Date = .now) -> Bool {
        do {
            var value = newPlan
            if resettingInputs || value.billingTimeZoneIdentifier == nil {
                value.billingTimeZoneIdentifier = billingCalendar.timeZone.identifier
            }
            // Reconfiguration also anchors an explicit zero. Simply removing
            // the old adjustment would expose all previously measured bytes.
            let needsDataAnchor = resettingInputs || (plan == nil && value.manualAdjustmentBytes > 0)
            let needsHotspotAnchor = (resettingInputs && value.hotspot != nil)
                || ((value.hotspot?.manualAdjustmentBytes ?? 0) > 0
                    && value.hotspot?.manualAdjustmentPeriodStart == nil)
            if needsDataAnchor || needsHotspotAnchor {
                // Initial setup accepts the same current carrier amount as
                // manual sync. Traffic accumulated while filling the form is
                // already included, so anchor it to a fresh counter reading.
                let measurement: MeasurementResult
                if needsDataAnchor {
                    measurement = try measurementService.prepareCalibrationBaseline(at: now)
                } else if let fresh = try? measurementService.measure(at: now),
                          usageRepository.latestSnapshot()?.measuredAt == now {
                    // A hotspot-only anchor must not change cellular baselines.
                    measurement = fresh
                } else {
                    // Without a readable cellular interface no hotspot traffic
                    // can be flowing, so the last stored reading is a safe base.
                    measurement = MeasurementResult(measuredAt: now, cellularBytes: 0, quality: lastQuality)
                }
                lastQuality = measurement.quality
                dailyUsage = usageRepository.dailyUsage()
                let period = billingService.currentPeriod(
                    now: now,
                    resetDay: value.resetDay,
                    calendar: billingCalendar
                )
                if needsDataAnchor {
                    value = calibrationService.calibrate(
                        plan: value,
                        carrierUsageBytes: value.manualAdjustmentBytes,
                        measuredBytes: measuredBytes(in: period),
                        period: period,
                        at: now
                    )
                }
                if needsHotspotAnchor, let hotspot = value.hotspot {
                    value.hotspot = hotspotCalibrationService.calibrate(
                        settings: hotspot,
                        carrierUsageBytes: hotspot.manualAdjustmentBytes,
                        measuredBytes: measuredHotspotBytes(in: period),
                        period: period
                    )
                }
            }
            value.updatedAt = now
            try settingsRepository.save(plan: value)
            plan = value
            completeOnboarding()
            errorMessage = nil
            rebuildSummary(at: now)
            let wantsHotspotAlerts = value.hotspot.map { $0.hasLimit && ($0.alert80 || $0.alert90) } ?? false
            if value.alert50 || value.alert80 || value.alert90 || wantsHotspotAlerts {
                Task {
                    guard await notificationService.requestAuthorization(),
                          let currentPlan = plan else { return }
                    // Recheck after the permission dialog, because the earlier
                    // rebuild can run while authorization is still pending.
                    await notificationService.evaluate(summary: summary, plan: currentPlan)
                }
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func saveManualCalibration(
        bytes: Int64,
        at now: Date = .now,
        expectedPeriodStart: Date? = nil
    ) -> Bool {
        guard let plan else { return false }
        let period = billingService.currentPeriod(
            now: now,
            resetDay: plan.resetDay,
            calendar: billingCalendar
        )
        guard expectedPeriodStart == nil || expectedPeriodStart == period.start else {
            errorMessage = "사용 주기가 바뀌었습니다. 통신사 앱을 갱신한 뒤 새 값을 입력해 주세요."
            return false
        }

        do {
            // Anchor the carrier value to a counter snapshot taken at the same
            // moment. Otherwise traffic since the last refresh is already in
            // the carrier value and would be added a second time later.
            let measurement = try measurementService.prepareCalibrationBaseline(at: now)
            lastQuality = measurement.quality
            dailyUsage = usageRepository.dailyUsage()

            let measured = measuredBytes(in: period)
            let calibratedPlan = calibrationService.calibrate(
                plan: plan,
                carrierUsageBytes: bytes,
                measuredBytes: measured,
                period: period,
                at: now
            )
            try settingsRepository.save(plan: calibratedPlan)
            self.plan = calibratedPlan
            errorMessage = nil
            rebuildSummary(at: now)
            return true
        } catch {
            errorMessage = "최신 측정값을 확인하지 못해 기준값을 저장하지 않았습니다. 다시 시도해 주세요."
            return false
        }
    }

    /// Saves the carrier's hotspot (tethering) usage as this period's base.
    /// Uses an ordinary measurement rather than the data calibration baseline,
    /// because a hotspot sync must not change how cellular traffic is counted.
    @discardableResult
    func saveHotspotCalibration(
        bytes: Int64,
        at now: Date = .now,
        expectedPeriodStart: Date? = nil
    ) -> Bool {
        guard let plan else { return false }
        let period = billingService.currentPeriod(
            now: now,
            resetDay: plan.resetDay,
            calendar: billingCalendar
        )
        guard expectedPeriodStart == nil || expectedPeriodStart == period.start else {
            errorMessage = "사용 주기가 바뀌었습니다. 통신사 앱을 갱신한 뒤 새 값을 입력해 주세요."
            return false
        }

        do {
            // Prefer a fresh reading. Without a readable cellular interface no
            // hotspot traffic can be flowing, so the last stored reading is a
            // safe base and the carrier value is still saved.
            if let measurement = try? measurementService.measure(at: now),
               usageRepository.latestSnapshot()?.measuredAt == now {
                lastQuality = measurement.quality
            }
            dailyUsage = usageRepository.dailyUsage()

            var updatedPlan = plan
            let settings = plan.hotspot ?? HotspotPlanSettings(limitBytes: 0, alert80: false, alert90: false)
            updatedPlan.hotspot = hotspotCalibrationService.calibrate(
                settings: settings,
                carrierUsageBytes: bytes,
                measuredBytes: measuredHotspotBytes(in: period),
                period: period
            )
            updatedPlan.updatedAt = now
            try settingsRepository.save(plan: updatedPlan)
            self.plan = updatedPlan
            errorMessage = nil
            rebuildSummary(at: now)
            return true
        } catch {
            errorMessage = "핫스팟 기준값을 저장하지 못했습니다. 다시 시도해 주세요."
            return false
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let result = try measurementService.measure()
            lastQuality = result.quality
            errorMessage = nil
            rebuildSummary(at: result.measuredAt)
        } catch {
            errorMessage = "데이터 사용량을 갱신하지 못했습니다."
            rebuildSummary(at: .now, publishToWidget: false)
        }
    }

    func rebuildSummary(at now: Date, publishToWidget: Bool = true) {
        dailyUsage = usageRepository.dailyUsage()
        guard let storedPlan = plan else {
            summary = .empty
            return
        }

        let result = summaryBuilder.build(
            plan: storedPlan,
            dailyUsage: dailyUsage,
            at: now,
            calendar: billingCalendar,
            generatedAt: usageRepository.latestSnapshot()?.measuredAt ?? .distantPast,
            measurementQuality: lastQuality
        )
        let effectivePlan = result.plan
        if effectivePlan != storedPlan {
            do {
                try settingsRepository.save(plan: effectivePlan)
                plan = effectivePlan
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        summary = result.summary

        if publishToWidget {
            do {
                try widgetRepository.write(summary: summary)
                widgetRepository.reload()
            } catch {
                // App Group may be unavailable in unsigned previews; app data remains intact.
            }
        }
        let currentSummary = summary
        Task {
            await notificationService.evaluate(summary: currentSummary, plan: effectivePlan)
        }
    }

    func diagnosticCounters() -> [NetworkInterfaceCounter] {
        (try? NetworkCounterReader().readCounters()) ?? []
    }

    private func measuredHotspotBytes(in period: DateInterval) -> Int64 {
        dailyUsage
            .filter { $0.id >= period.start && $0.id < period.end }
            .reduce(Int64(0)) { lhs, rhs in
                let (value, overflow) = lhs.addingReportingOverflow(max(0, rhs.hotspotBytes ?? 0))
                return overflow ? Int64.max : value
            }
    }

    private func measuredBytes(in period: DateInterval) -> Int64 {
        dailyUsage
            .filter { $0.id >= period.start && $0.id < period.end }
            .reduce(Int64(0)) { lhs, rhs in
                let (value, overflow) = lhs.addingReportingOverflow(rhs.totalBytes)
                return overflow ? Int64.max : value
            }
    }

    #if DEBUG
    static var preview: AppModel {
        let suiteName = "DataViewPreview.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let model = AppModel(
            settingsRepository: SettingsRepository(defaults: defaults),
            usageRepository: UsageRepository(defaults: defaults)
        )
        model.plan = .standard
        model.summary = .preview
        model.dailyUsage = Self.previewDays()
        model.lastQuality = .verified
        return model
    }

    private static func previewDays() -> [DailyUsage] {
        let values = [0.8, 1.4, 0.9, 2.2, 1.6, 3.1, 1.2]
        return values.enumerated().compactMap { offset, value in
            guard let date = Calendar.current.date(byAdding: .day, value: offset - 6, to: .now) else { return nil }
            let day = Calendar.current.startOfDay(for: date)
            let bytes = Int64(value * Double(DataBytes.gigabyte))
            return DailyUsage(id: day, cellularBytes: bytes, hotspotBytes: nil, totalBytes: bytes)
        }
    }
    #endif
}
