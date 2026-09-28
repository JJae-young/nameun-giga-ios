import XCTest
@testable import DataView

final class WidgetSummaryPresentationTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return value
    }

    func testMidnightDoesNotRelabelYesterdaysUsageAsToday() {
        let measuredAt = date(day: 25, hour: 23, minute: 59)
        let summary = makeSummary(at: measuredAt)
        let presentation = WidgetSummaryPresentation(summary: summary, date: date(day: 26))

        XCTAssertTrue(presentation.hasCurrentPeriodUsage)
        XCTAssertFalse(presentation.hasCurrentDayUsage)
        XCTAssertTrue(presentation.needsRefresh)
        XCTAssertEqual(summary.todayBytes, 2 * DataBytes.gigabyte)
    }

    func testBillingResetHidesPreviousCycleUntilNewMeasurement() {
        let measuredAt = date(day: 30, hour: 23, minute: 59)
        let summary = makeSummary(at: measuredAt)
        let presentation = WidgetSummaryPresentation(summary: summary, date: summary.periodEnd)

        XCTAssertFalse(presentation.hasCurrentPeriodUsage)
        XCTAssertFalse(presentation.hasCurrentDayUsage)
        XCTAssertTrue(presentation.needsRefresh)
    }

    func testNewCycleSummaryWithOldMeasurementDoesNotClaimFreshZero() {
        let measuredAt = date(day: 30, hour: 23, minute: 59)
        let nextMonth = date(month: 10, day: 1)
        let summary = UsageSummaryBuilder().build(
            plan: .standard,
            dailyUsage: [],
            at: nextMonth,
            calendar: calendar,
            generatedAt: measuredAt
        ).summary
        let presentation = WidgetSummaryPresentation(summary: summary, date: nextMonth)

        XCTAssertEqual(summary.usedBytes, 0)
        XCTAssertFalse(presentation.hasCurrentPeriodUsage)
        XCTAssertTrue(presentation.needsRefresh)
    }

    func testUnlimitedPlanIsConfiguredWithoutLimit() {
        let now = date(day: 26, hour: 12)
        var plan = PlanSettings.standard
        plan.isUnlimited = true
        let summary = UsageSummaryBuilder().build(
            plan: plan,
            dailyUsage: [],
            at: now,
            calendar: calendar
        ).summary
        let presentation = WidgetSummaryPresentation(summary: summary, date: now)

        XCTAssertNil(summary.limitBytes)
        XCTAssertTrue(presentation.hasConfiguredPlan)
        XCTAssertTrue(presentation.isUnlimited)
        XCTAssertTrue(presentation.hasCurrentPeriodUsage)
        XCTAssertFalse(WidgetSummaryPresentation(summary: .empty, date: now).hasConfiguredPlan)
    }

    func testLegacySummaryRemainsReadableWithoutOptionalMetadata() throws {
        let now = date(day: 26, hour: 12)
        let summary = makeSummary(at: now)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(summary)) as? [String: Any])
        for key in ["isUnlimited", "billingTimeZoneIdentifier", "measurementQuality"] {
            json.removeValue(forKey: key)
        }
        let legacy = try JSONDecoder().decode(WidgetSummary.self, from: JSONSerialization.data(withJSONObject: json))

        XCTAssertEqual(legacy.usedBytes, summary.usedBytes)
        XCTAssertNil(legacy.isUnlimited)
        XCTAssertNil(legacy.measurementQuality)
        XCTAssertTrue(WidgetSummaryPresentation(summary: legacy, date: now).hasCurrentPeriodUsage)
    }

    func testTransitionsIncludeBillingMidnightAndSixHourExpiry() {
        let now = date(day: 30, hour: 18, minute: 30)
        let summary = makeSummary(at: now)
        let presentation = WidgetSummaryPresentation(summary: summary, date: now)

        XCTAssertEqual(presentation.transitionDates, [summary.periodEnd, now.addingTimeInterval(6 * 60 * 60)])
        XCTAssertFalse(presentation.needsRefresh)
        XCTAssertTrue(WidgetSummaryPresentation(summary: summary, date: now.addingTimeInterval(6 * 60 * 60)).needsRefresh)
    }

    func testBillingTimezoneIsUsedForDayBoundary() {
        let now = date(day: 26, hour: 23, minute: 59)
        let summary = makeSummary(at: now)
        let presentation = WidgetSummaryPresentation(summary: summary, date: now)

        XCTAssertEqual(presentation.calendar.timeZone.identifier, "Asia/Seoul")
        XCTAssertEqual(presentation.transitionDates.first, date(day: 27))
        XCTAssertFalse(WidgetSummaryPresentation(summary: summary, date: date(day: 27)).hasCurrentDayUsage)
    }

    func testUnavailableMeasurementAndFutureTimestampRequireRefresh() {
        let now = date(day: 26, hour: 12)
        var summary = makeSummary(at: now)
        summary.measurementQuality = .unavailable
        XCTAssertTrue(WidgetSummaryPresentation(summary: summary, date: now).needsRefresh)
        XCTAssertFalse(WidgetSummaryPresentation(summary: summary, date: now.addingTimeInterval(-60)).hasCurrentPeriodUsage)
    }

    private func makeSummary(at now: Date) -> WidgetSummary {
        UsageSummaryBuilder().build(
            plan: .standard,
            dailyUsage: [DailyUsage(
                id: calendar.startOfDay(for: now),
                cellularBytes: 2 * DataBytes.gigabyte,
                hotspotBytes: nil,
                totalBytes: 2 * DataBytes.gigabyte
            )],
            at: now,
            calendar: calendar,
            measurementQuality: .verified
        ).summary
    }

    private func date(month: Int = 9, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }
}
