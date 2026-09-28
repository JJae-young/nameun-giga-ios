import Foundation

enum BillingCalendarFactory {
    static func make(for plan: PlanSettings?) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let identifier = plan?.billingTimeZoneIdentifier,
           let timeZone = TimeZone(identifier: identifier) {
            calendar.timeZone = timeZone
        } else {
            calendar.timeZone = .current
        }
        return calendar
    }
}

struct BillingPeriodService {
    func currentPeriod(now: Date, resetDay: Int, calendar: Calendar = .current) -> DateInterval {
        var calendar = calendar
        calendar.timeZone = calendar.timeZone
        let safeDay = min(31, max(1, resetDay))
        let monthStart = startOfMonth(containing: now, calendar: calendar)
        let thisMonthReset = resetDate(monthStart: monthStart, resetDay: safeDay, calendar: calendar)

        let startMonth: Date
        if now >= thisMonthReset {
            startMonth = monthStart
        } else {
            startMonth = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
        }

        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startMonth) ?? startMonth
        let start = resetDate(monthStart: startMonth, resetDay: safeDay, calendar: calendar)
        let end = resetDate(monthStart: nextMonth, resetDay: safeDay, calendar: calendar)
        return DateInterval(start: start, end: end)
    }

    private func startOfMonth(containing date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func resetDate(monthStart: Date, resetDay: Int, calendar: Calendar) -> Date {
        let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        let day = min(resetDay, dayRange?.count ?? resetDay)
        return calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
    }
}

struct UsageCalibrationResolution: Equatable {
    let usedBytes: Int64
    let plan: PlanSettings
}

struct UsageCalibrationService {
    func usedBytes(fromRemaining remainingBytes: Int64, limitBytes: Int64) -> Int64? {
        guard remainingBytes >= 0,
              limitBytes >= 0,
              remainingBytes <= limitBytes else { return nil }
        return limitBytes - remainingBytes
    }

    func calibrate(
        plan: PlanSettings,
        carrierUsageBytes: Int64,
        measuredBytes: Int64,
        period: DateInterval,
        at date: Date
    ) -> PlanSettings {
        var value = plan
        value.manualAdjustmentBytes = max(0, carrierUsageBytes)
        value.manualAdjustmentPeriodStart = period.start
        value.manualAdjustmentMeasuredBytes = max(0, measuredBytes)
        value.updatedAt = date
        return value
    }

    func resolve(
        plan: PlanSettings,
        measuredBytes: Int64,
        period: DateInterval,
        at date: Date
    ) -> UsageCalibrationResolution {
        let measured = max(0, measuredBytes)
        var value = plan

        if let calibrationPeriodStart = value.manualAdjustmentPeriodStart {
            guard calibrationPeriodStart == period.start else {
                clearCalibration(in: &value, at: date)
                return UsageCalibrationResolution(usedBytes: measured, plan: value)
            }

            let measuredAtCalibration: Int64
            if let storedMeasuredBytes = value.manualAdjustmentMeasuredBytes {
                measuredAtCalibration = max(0, storedMeasuredBytes)
            } else {
                // Recover conservatively from a partially stored calibration:
                // keep the carrier value exact and start counting from now.
                measuredAtCalibration = measured
                value.manualAdjustmentMeasuredBytes = measured
                value.updatedAt = date
            }

            if measured < measuredAtCalibration {
                // Measurement history can legitimately start a new epoch after
                // a schema repair or local data reset. Preserve the carrier
                // value, but re-anchor it immediately so fresh traffic is not
                // hidden until it catches up with an obsolete measured total.
                value.manualAdjustmentMeasuredBytes = measured
                value.updatedAt = date
                return UsageCalibrationResolution(
                    usedBytes: max(0, value.manualAdjustmentBytes),
                    plan: value
                )
            }

            let postCalibrationBytes = max(0, measured - measuredAtCalibration)
            let used = safeAdd(max(0, value.manualAdjustmentBytes), postCalibrationBytes)
            return UsageCalibrationResolution(usedBytes: used, plan: value)
        }

        if value.manualAdjustmentBytes > 0 {
            // Legacy plans stored only the carrier value. Anchor it to the
            // current period and current measured total so an upgrade neither
            // loses it nor double-counts measurement history.
            value.manualAdjustmentPeriodStart = period.start
            value.manualAdjustmentMeasuredBytes = measured
            value.updatedAt = date
            return UsageCalibrationResolution(usedBytes: value.manualAdjustmentBytes, plan: value)
        }

        if value.manualAdjustmentMeasuredBytes != nil {
            clearCalibration(in: &value, at: date)
        }
        return UsageCalibrationResolution(usedBytes: measured, plan: value)
    }

    private func clearCalibration(in plan: inout PlanSettings, at date: Date) {
        plan.manualAdjustmentBytes = 0
        plan.manualAdjustmentPeriodStart = nil
        plan.manualAdjustmentMeasuredBytes = nil
        plan.updatedAt = date
    }

    private func safeAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : value
    }
}
