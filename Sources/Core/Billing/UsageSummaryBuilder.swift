import Foundation

struct UsageSummaryBuildResult: Equatable {
    let summary: WidgetSummary
    let plan: PlanSettings
}

struct UsageSummaryBuilder {
    private let billingService = BillingPeriodService()
    private let calibrationService = UsageCalibrationService()

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
        let effectivePlan = calibration.plan
        let used = calibration.usedBytes
        let limit = effectivePlan.isUnlimited ? nil : effectivePlan.dataLimitBytes
        let remaining = limit.map { max(0, $0 - min($0, used)) }
        let percent = limit.map { $0 > 0 ? min(1, Double(used) / Double($0)) : 0 }
        let today = dailyUsage.first(where: { calendar.isDate($0.id, inSameDayAs: date) })?.totalBytes ?? 0

        let summary = WidgetSummary(
            generatedAt: generatedAt ?? date,
            periodStart: period.start,
            periodEnd: period.end,
            usedBytes: used,
            limitBytes: limit,
            remainingBytes: remaining,
            usagePercent: percent,
            iPhoneBytes: used,
            todayBytes: today,
            isUnlimited: effectivePlan.isUnlimited,
            billingTimeZoneIdentifier: calendar.timeZone.identifier,
            measurementQuality: measurementQuality
        )
        return UsageSummaryBuildResult(summary: summary, plan: effectivePlan)
    }

    private func safeAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : value
    }
}
