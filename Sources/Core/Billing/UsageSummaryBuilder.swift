import Foundation

struct UsageSummaryBuildResult: Equatable {
    let summary: WidgetSummary
    let plan: PlanSettings
}

struct UsageSummaryBuilder {
    private let billingService = BillingPeriodService()
    private let calibrationService = UsageCalibrationService()
    private let hotspotCalibrationService = HotspotCalibrationService()

    func build(
        plan: PlanSettings,
        dailyUsage: [DailyUsage],
        at date: Date,
        calendar: Calendar = .current,
        generatedAt: Date? = nil,
        measurementQuality: MeasurementQuality? = nil
    ) -> UsageSummaryBuildResult {
        let period = billingService.currentPeriod(
            now: date,
            resetDay: plan.resetDay,
            calendar: calendar
        )
        let measured = dailyUsage
            .filter { $0.id >= period.start && $0.id < period.end }
            .reduce(Int64(0)) { safeAdd($0, $1.totalBytes) }
        let calibration = calibrationService.resolve(
            plan: plan,
            measuredBytes: measured,
            period: period,
            at: date
        )
        var effectivePlan = calibration.plan
        let used = calibration.usedBytes
        let limit = effectivePlan.isUnlimited ? nil : effectivePlan.dataLimitBytes
        let remaining = limit.map { max(0, $0 - min($0, used)) }
        let percent = limit.map { $0 > 0 ? min(1, Double(used) / Double($0)) : 0 }
        let today = dailyUsage.first(where: { calendar.isDate($0.id, inSameDayAs: date) })?.totalBytes ?? 0

        // Hotspot is a subset of cellular. It is shown when the user tracks a
        // tethering allowance or this period has measured hotspot traffic.
        let hotspotMeasured = dailyUsage
            .filter { $0.id >= period.start && $0.id < period.end }
            .reduce(Int64(0)) { safeAdd($0, max(0, $1.hotspotBytes ?? 0)) }
        let hotspotSupportState: HotspotSupportState = dailyUsage.contains { ($0.hotspotBytes ?? 0) > 0 }
            ? .experimental
            : .unsupported
        var hotspotUsed: Int64?
        var hotspotLimit: Int64?
        if let hotspotSettings = effectivePlan.hotspot {
            let resolution = hotspotCalibrationService.resolve(
                settings: hotspotSettings,
                measuredBytes: hotspotMeasured,
                period: period
            )
            effectivePlan.hotspot = resolution.settings
            hotspotUsed = resolution.usedBytes
            hotspotLimit = hotspotSettings.hasLimit ? hotspotSettings.limitBytes : nil
        } else if hotspotMeasured > 0 {
            hotspotUsed = hotspotMeasured
        }
        var hotspotRemaining: Int64?
        var hotspotPercent: Double?
        if let hotspotLimit, let hotspotUsed {
            var allowance = max(0, hotspotLimit - min(hotspotLimit, hotspotUsed))
            // The hotspot allowance is part of the total plan (for example
            // 50 GB of 160 GB), so it is also bounded by the data left overall.
            if let remaining {
                allowance = min(allowance, remaining)
            }
            hotspotRemaining = allowance
            hotspotPercent = min(1, Double(hotspotUsed) / Double(hotspotLimit))
        }

        let summary = WidgetSummary(
            generatedAt: generatedAt ?? date,
            periodStart: period.start,
            periodEnd: period.end,
            usedBytes: used,
            limitBytes: limit,
            remainingBytes: remaining,
            usagePercent: percent,
            iPhoneBytes: used,
            hotspotBytes: hotspotUsed,
            hotspotSupportState: hotspotSupportState,
            todayBytes: today,
            isUnlimited: effectivePlan.isUnlimited,
            billingTimeZoneIdentifier: calendar.timeZone.identifier,
            measurementQuality: measurementQuality,
            hotspotLimitBytes: hotspotLimit,
            hotspotRemainingBytes: hotspotRemaining,
            hotspotUsagePercent: hotspotPercent
        )
        return UsageSummaryBuildResult(summary: summary, plan: effectivePlan)
    }

    private func safeAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : value
    }
}
