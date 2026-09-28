import XCTest
@testable import DataView

final class BillingPeriodServiceTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testResetDayOne() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 14)))
        let period = BillingPeriodService().currentPeriod(now: now, resetDay: 1, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: period.start), DateComponents(year: 2026, month: 9, day: 1))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: period.end), DateComponents(year: 2026, month: 10, day: 1))
    }

    func testResetDayFifteenBeforeReset() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 14)))
        let period = BillingPeriodService().currentPeriod(now: now, resetDay: 15, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: period.start), DateComponents(year: 2026, month: 8, day: 15))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: period.end), DateComponents(year: 2026, month: 9, day: 15))
    }

    func testResetDayThirtyOneClampsFebruary() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 2, day: 28, hour: 12)))
        let period = BillingPeriodService().currentPeriod(now: now, resetDay: 31, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: period.start), DateComponents(year: 2027, month: 2, day: 28))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: period.end), DateComponents(year: 2027, month: 3, day: 31))
    }

    func testYearBoundary() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2027, month: 1, day: 2)))
        let period = BillingPeriodService().currentPeriod(now: now, resetDay: 15, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: period.start), DateComponents(year: 2026, month: 12, day: 15))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: period.end), DateComponents(year: 2027, month: 1, day: 15))
    }

    func testStoredBillingTimeZoneRemainsStableWhileRoaming() throws {
        var plan = PlanSettings.standard
        plan.billingTimeZoneIdentifier = "Asia/Seoul"
        let billingCalendar = BillingCalendarFactory.make(for: plan)
        let now = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-09-30T15:30:00Z")
        )
        let period = BillingPeriodService().currentPeriod(
            now: now,
            resetDay: 1,
            calendar: billingCalendar
        )
        let startComponents = billingCalendar.dateComponents(
            [.year, .month, .day, .hour],
            from: period.start
        )

        XCTAssertEqual(billingCalendar.timeZone.identifier, "Asia/Seoul")
        XCTAssertEqual(
            startComponents,
            DateComponents(year: 2026, month: 10, day: 1, hour: 0)
        )
    }

    func testLegacyPlanBillingTimeZoneIsPinnedOnlyOnce() throws {
        let suiteName = "BillingPeriodServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = SettingsRepository(defaults: defaults)
        var legacyPlan = PlanSettings.standard
        legacyPlan.billingTimeZoneIdentifier = nil
        try repository.save(plan: legacyPlan)

        let firstLoad = repository.loadPlanWithStableBillingTimeZone(
            fallback: try XCTUnwrap(TimeZone(identifier: "Asia/Seoul"))
        )
        let roamingLoad = repository.loadPlanWithStableBillingTimeZone(
            fallback: try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        )

        XCTAssertEqual(firstLoad?.billingTimeZoneIdentifier, "Asia/Seoul")
        XCTAssertEqual(roamingLoad?.billingTimeZoneIdentifier, "Asia/Seoul")
        XCTAssertEqual(repository.loadPlan()?.billingTimeZoneIdentifier, "Asia/Seoul")
    }
}

final class UsageCalibrationServiceTests: XCTestCase {
    private let service = UsageCalibrationService()

    func testRemainingCarrierValueConvertsToUsedBytes() {
        let used = service.usedBytes(
            fromRemaining: 63_680_000_000,
            limitBytes: 160 * DataBytes.gigabyte
        )

        XCTAssertEqual(used, 96_320_000_000)
    }

    func testRemainingCarrierValueRejectsValueAbovePlanLimit() {
        XCTAssertNil(service.usedBytes(
            fromRemaining: 161 * DataBytes.gigabyte,
            limitBytes: 160 * DataBytes.gigabyte
        ))
    }

    func testRemainingCarrierValueAcceptsPlanBoundary() {
        XCTAssertEqual(service.usedBytes(
            fromRemaining: 160 * DataBytes.gigabyte,
            limitBytes: 160 * DataBytes.gigabyte
        ), 0)
    }

    func testLegacyPlanPayloadDecodesWithCalibrationMetadataAbsent() throws {
        let createdAt = Date(timeIntervalSinceReferenceDate: 123)
        let updatedAt = Date(timeIntervalSinceReferenceDate: 456)
        let payload = LegacyPlanSettingsPayload(
            dataLimitBytes: 160 * DataBytes.gigabyte,
            resetDay: 1,
            isUnlimited: false,
            alert50: true,
            alert80: true,
            alert90: true,
            manualAdjustmentBytes: 64 * DataBytes.gigabyte,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let decoded = try JSONDecoder().decode(
            PlanSettings.self,
            from: JSONEncoder().encode(payload)
        )

        XCTAssertEqual(decoded.manualAdjustmentBytes, 64 * DataBytes.gigabyte)
        XCTAssertNil(decoded.manualAdjustmentPeriodStart)
        XCTAssertNil(decoded.manualAdjustmentMeasuredBytes)
        XCTAssertNil(decoded.billingTimeZoneIdentifier)
        XCTAssertEqual(decoded.createdAt, createdAt)
        XCTAssertEqual(decoded.updatedAt, updatedAt)
    }

    func testCalibrationDisplaysCarrierUsageThenAddsOnlyNewMeasurement() throws {
        let period = try makePeriod(month: 9)
        let calibrated = service.calibrate(
            plan: .standard,
            carrierUsageBytes: 40 * DataBytes.gigabyte,
            measuredBytes: 10 * DataBytes.gigabyte,
            period: period,
            at: period.start
        )

        let immediately = service.resolve(
            plan: calibrated,
            measuredBytes: 10 * DataBytes.gigabyte,
            period: period,
            at: period.start
        )
        let afterTwoGigabytes = service.resolve(
            plan: calibrated,
            measuredBytes: 12 * DataBytes.gigabyte,
            period: period,
            at: period.start
        )

        XCTAssertEqual(immediately.usedBytes, 40 * DataBytes.gigabyte)
        XCTAssertEqual(afterTwoGigabytes.usedBytes, 42 * DataBytes.gigabyte)
    }

    func testCalibrationExpiresAtNextBillingPeriod() throws {
        let september = try makePeriod(month: 9)
        let october = try makePeriod(month: 10)
        let calibrated = service.calibrate(
            plan: .standard,
            carrierUsageBytes: 40 * DataBytes.gigabyte,
            measuredBytes: 10 * DataBytes.gigabyte,
            period: september,
            at: september.start
        )

        let result = service.resolve(
            plan: calibrated,
            measuredBytes: 3 * DataBytes.gigabyte,
            period: october,
            at: october.start
        )

        XCTAssertEqual(result.usedBytes, 3 * DataBytes.gigabyte)
        XCTAssertEqual(result.plan.manualAdjustmentBytes, 0)
        XCTAssertNil(result.plan.manualAdjustmentPeriodStart)
        XCTAssertNil(result.plan.manualAdjustmentMeasuredBytes)
    }

    func testLegacyAdjustmentIsAnchoredWithoutDoubleCountingExistingMeasurement() throws {
        let period = try makePeriod(month: 9)
        var legacyPlan = PlanSettings.standard
        legacyPlan.manualAdjustmentBytes = 64 * DataBytes.gigabyte

        let migrated = service.resolve(
            plan: legacyPlan,
            measuredBytes: 5 * DataBytes.gigabyte,
            period: period,
            at: period.start
        )
        let later = service.resolve(
            plan: migrated.plan,
            measuredBytes: 6 * DataBytes.gigabyte,
            period: period,
            at: period.start
        )

        XCTAssertEqual(migrated.usedBytes, 64 * DataBytes.gigabyte)
        XCTAssertEqual(migrated.plan.manualAdjustmentPeriodStart, period.start)
        XCTAssertEqual(migrated.plan.manualAdjustmentMeasuredBytes, 5 * DataBytes.gigabyte)
        XCTAssertEqual(later.usedBytes, 65 * DataBytes.gigabyte)
    }

    func testZeroCalibrationStillResetsMeasuredBaseline() throws {
        let period = try makePeriod(month: 9)
        let calibrated = service.calibrate(
            plan: .standard,
            carrierUsageBytes: 0,
            measuredBytes: 10 * DataBytes.gigabyte,
            period: period,
            at: period.start
        )

        let result = service.resolve(
            plan: calibrated,
            measuredBytes: 11 * DataBytes.gigabyte,
            period: period,
            at: period.start
        )

        XCTAssertEqual(result.usedBytes, DataBytes.gigabyte)
    }

    func testMeasurementHistoryResetReanchorsCarrierCalibration() throws {
        let period = try makePeriod(month: 9)
        let calibrated = service.calibrate(
            plan: .standard,
            carrierUsageBytes: 40 * DataBytes.gigabyte,
            measuredBytes: 19 * DataBytes.gigabyte,
            period: period,
            at: period.start
        )

        let afterHistoryReset = service.resolve(
            plan: calibrated,
            measuredBytes: 2 * DataBytes.gigabyte,
            period: period,
            at: period.start.addingTimeInterval(60)
        )
        let afterNewUsage = service.resolve(
            plan: afterHistoryReset.plan,
            measuredBytes: 3 * DataBytes.gigabyte,
            period: period,
            at: period.start.addingTimeInterval(120)
        )

        XCTAssertEqual(afterHistoryReset.usedBytes, 40 * DataBytes.gigabyte)
        XCTAssertEqual(afterHistoryReset.plan.manualAdjustmentMeasuredBytes, 2 * DataBytes.gigabyte)
        XCTAssertEqual(afterNewUsage.usedBytes, 41 * DataBytes.gigabyte)
    }

    private func makePeriod(month: Int) throws -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: month, day: 1)))
        let end = try XCTUnwrap(calendar.date(byAdding: .month, value: 1, to: start))
        return DateInterval(start: start, end: end)
    }
}

private struct LegacyPlanSettingsPayload: Encodable {
    let dataLimitBytes: Int64?
    let resetDay: Int
    let isUnlimited: Bool
    let alert50: Bool
    let alert80: Bool
    let alert90: Bool
    let manualAdjustmentBytes: Int64
    let createdAt: Date
    let updatedAt: Date
}
