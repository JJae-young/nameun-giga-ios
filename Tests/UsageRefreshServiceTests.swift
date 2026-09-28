import XCTest
@testable import DataView

final class UsageSummaryBuilderTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testSummaryCombinesCarrierCalibrationWithOnlyNewMeasuredUsage() throws {
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 12))
        )
        let period = BillingPeriodService().currentPeriod(
            now: now,
            resetDay: 1,
            calendar: calendar
        )
        var plan = PlanSettings.standard
        plan.dataLimitBytes = 100 * DataBytes.gigabyte
        plan.manualAdjustmentBytes = 40 * DataBytes.gigabyte
        plan.manualAdjustmentPeriodStart = period.start
        plan.manualAdjustmentMeasuredBytes = 5 * DataBytes.gigabyte
        let dailyUsage = [
            DailyUsage(
                id: calendar.startOfDay(for: now),
                cellularBytes: 7 * DataBytes.gigabyte,
                hotspotBytes: nil,
                totalBytes: 7 * DataBytes.gigabyte
            )
        ]

        let result = UsageSummaryBuilder().build(
            plan: plan,
            dailyUsage: dailyUsage,
            at: now,
            calendar: calendar
        )

        XCTAssertEqual(result.summary.usedBytes, 42 * DataBytes.gigabyte)
        XCTAssertEqual(result.summary.remainingBytes, 58 * DataBytes.gigabyte)
        XCTAssertEqual(
            try XCTUnwrap(result.summary.usagePercent),
            0.42,
            accuracy: 0.000_001
        )
        XCTAssertEqual(result.summary.todayBytes, 7 * DataBytes.gigabyte)
        XCTAssertEqual(result.summary.generatedAt, now)
    }

    func testEmptySummaryDoesNotPretendItWasJustRefreshed() {
        XCTAssertLessThan(WidgetSummary.empty.generatedAt.timeIntervalSince1970, 0)
    }

    func testBillingPeriodUsesHalfOpenEndBoundary() throws {
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 12))
        )
        let period = BillingPeriodService().currentPeriod(now: now, resetDay: 1, calendar: calendar)
        let dailyUsage = [
            DailyUsage(
                id: period.start,
                cellularBytes: 100,
                hotspotBytes: nil,
                totalBytes: 100
            ),
            DailyUsage(
                id: period.end,
                cellularBytes: 900,
                hotspotBytes: nil,
                totalBytes: 900
            )
        ]

        let result = UsageSummaryBuilder().build(
            plan: .standard,
            dailyUsage: dailyUsage,
            at: now,
            calendar: calendar
        )

        XCTAssertEqual(result.summary.usedBytes, 100)
    }
}

final class UsageRefreshServiceTests: XCTestCase {
    func testWidgetRefreshPreservesManualUsageAndAddsCounterDelta() throws {
        let suiteName = "UsageRefreshServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let usageRepository = UsageRepository(defaults: defaults)
        let settingsRepository = SettingsRepository(defaults: defaults)
        let now = try XCTUnwrap(
            Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 17, hour: 12))
        )
        let period = BillingPeriodService().currentPeriod(now: now, resetDay: 1)
        var plan = PlanSettings.standard
        plan.manualAdjustmentBytes = 64 * DataBytes.gigabyte
        plan.manualAdjustmentPeriodStart = period.start
        plan.manualAdjustmentMeasuredBytes = 0
        try settingsRepository.save(plan: plan)

        try usageRepository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: now.addingTimeInterval(-60),
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 1_000,
                    sentBytes: 2_000,
                    classification: .cellular
                )
            ]
        ))
        let reader = RefreshMockCounterReader(counters: [
            NetworkInterfaceCounter(
                name: "pdp_ip0",
                receivedBytes: 1_000 + UInt64(DataBytes.gigabyte),
                sentBytes: 2_000 + 500_000_000,
                classification: .cellular
            )
        ])

        let summary = try XCTUnwrap(
            UsageRefreshService(
                settingsRepository: settingsRepository,
                usageRepository: usageRepository,
                reader: reader
            ).refresh(at: now)
        )

        XCTAssertEqual(summary.usedBytes, 65_500_000_000)
        XCTAssertEqual(summary.usedBytes - plan.manualAdjustmentBytes, 1_500_000_000)
        XCTAssertEqual(summary.todayBytes, 1_500_000_000)
        XCTAssertEqual(summary.generatedAt, now)
        XCTAssertEqual(usageRepository.dailyUsage().first?.totalBytes, 1_500_000_000)
        XCTAssertEqual(settingsRepository.loadPlan()?.manualAdjustmentBytes, 64 * DataBytes.gigabyte)
    }
}

@MainActor
final class AppModelCalibrationTests: XCTestCase {
    func testResetInputsAnchorsZeroAndReplacementUsageWithoutDeletingHistory() throws {
        for replacementBytes in [Int64(0), 40 * DataBytes.gigabyte] {
            let suiteName = "ResetInputsTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }
            defaults.set("dark", forKey: "displayTheme")
            let usage = UsageRepository(defaults: defaults)
            let settings = SettingsRepository(defaults: defaults)
            var original = PlanSettings.standard
            original.alert50 = false
            original.alert80 = false
            original.alert90 = false
            original.billingTimeZoneIdentifier = "Asia/Seoul"
            original.hotspot = HotspotPlanSettings(limitBytes: 30 * DataBytes.gigabyte)
            try settings.save(plan: original)
            let now = Date.now
            try usage.save(snapshot: InterfaceCounterSnapshot(
                measuredAt: now.addingTimeInterval(-120),
                counters: [NetworkInterfaceCounter(
                    name: "pdp_ip0", receivedBytes: 1_000, sentBytes: 1_000,
                    classification: .cellular
                )]
            ))
            let model = AppModel(
                settingsRepository: settings, usageRepository: usage,
                reader: RefreshMockCounterReader(counters: [NetworkInterfaceCounter(
                    name: "pdp_ip0", receivedBytes: 2_000, sentBytes: 2_000,
                    classification: .cellular
                )])
            )
            XCTAssertTrue(model.saveManualCalibration(bytes: 90 * DataBytes.gigabyte, at: now.addingTimeInterval(-60)))
            let history = usage.dailyUsage()
            XCTAssertFalse(history.isEmpty)
            var replacement = PlanSettings.standard
            replacement.alert50 = false
            replacement.alert80 = false
            replacement.alert90 = false
            replacement.dataLimitBytes = 100 * DataBytes.gigabyte
            replacement.resetDay = 15
            replacement.billingTimeZoneIdentifier = "America/Los_Angeles"
            replacement.manualAdjustmentBytes = replacementBytes

            XCTAssertTrue(model.savePlan(replacement, resettingInputs: true, at: now))
            XCTAssertEqual(model.summary.usedBytes, replacementBytes)
            XCTAssertEqual(model.summary.limitBytes, 100 * DataBytes.gigabyte)
            XCTAssertEqual(model.plan?.manualAdjustmentMeasuredBytes, 2_000)
            XCTAssertEqual(model.plan?.resetDay, 15)
            XCTAssertEqual(model.plan?.billingTimeZoneIdentifier, "Asia/Seoul")
            XCTAssertNil(model.plan?.hotspot, "Discard the old hotspot input, not measurement history.")
            XCTAssertEqual(usage.dailyUsage(), history)
            XCTAssertEqual(defaults.string(forKey: "displayTheme"), "dark")
            XCTAssertEqual(settings.loadPlan(), model.plan)
            let next = try UsageRefreshService(
                settingsRepository: settings, usageRepository: usage,
                reader: RefreshMockCounterReader(counters: [NetworkInterfaceCounter(
                    name: "pdp_ip0", receivedBytes: 2_500, sentBytes: 2_500,
                    classification: .cellular
                )])
            ).refresh(at: now.addingTimeInterval(60))
            XCTAssertEqual(next?.usedBytes, replacementBytes + 1_000)
        }
    }

    func testResetInputsFailureKeepsOriginalSettingsAndHistory() throws {
        let suiteName = "ResetInputsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsRepository(defaults: defaults)
        let usage = UsageRepository(defaults: defaults)
        var original = PlanSettings.standard
        original.alert50 = false
        original.alert80 = false
        original.alert90 = false
        try settings.save(plan: original)
        let snapshot = InterfaceCounterSnapshot(measuredAt: .now.addingTimeInterval(-60), counters: [])
        try usage.save(snapshot: snapshot)
        let model = AppModel(
            settingsRepository: settings, usageRepository: usage,
            reader: RefreshMockCounterReader(counters: [])
        )
        let before = try XCTUnwrap(settings.loadPlan())
        var replacement = PlanSettings.standard
        replacement.dataLimitBytes = 10 * DataBytes.gigabyte
        XCTAssertFalse(model.savePlan(replacement, resettingInputs: true))
        XCTAssertEqual(settings.loadPlan(), before)
        XCTAssertEqual(model.plan, before)
        XCTAssertEqual(usage.latestSnapshot(), snapshot)
        XCTAssertNotNil(model.errorMessage)
    }

    func testCalibrationRejectsValueEnteredInPreviousBillingPeriodWithoutMeasuring() throws {
        let suiteName = "AppModelCalibrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let usageRepository = UsageRepository(defaults: defaults)
        let settingsRepository = SettingsRepository(defaults: defaults)
        var plan = PlanSettings.standard
        plan.billingTimeZoneIdentifier = "Asia/Seoul"
        try settingsRepository.save(plan: plan)
        let calendar = BillingCalendarFactory.make(for: plan)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 10, day: 1, minute: 1
        )))
        let previousPeriod = BillingPeriodService().currentPeriod(
            now: now.addingTimeInterval(-120), resetDay: 1, calendar: calendar
        )
        let priorSnapshot = InterfaceCounterSnapshot(
            measuredAt: now.addingTimeInterval(-120),
            counters: [NetworkInterfaceCounter(
                name: "pdp_ip0", receivedBytes: 1_000, sentBytes: 1_000,
                classification: .cellular
            )]
        )
        try usageRepository.save(snapshot: priorSnapshot)
        let model = AppModel(
            settingsRepository: settingsRepository,
            usageRepository: usageRepository,
            reader: RefreshMockCounterReader(counters: [NetworkInterfaceCounter(
                name: "pdp_ip0", receivedBytes: 2_000, sentBytes: 2_000,
                classification: .cellular
            )])
        )

        XCTAssertFalse(model.saveManualCalibration(
            bytes: 100 * DataBytes.gigabyte,
            at: now,
            expectedPeriodStart: previousPeriod.start
        ))

        XCTAssertEqual(usageRepository.latestSnapshot(), priorSnapshot)
        XCTAssertTrue(usageRepository.dailyUsage().isEmpty)
        XCTAssertEqual(settingsRepository.loadPlan()?.manualAdjustmentBytes, 0)
        XCTAssertEqual(model.errorMessage, "사용 주기가 바뀌었습니다. 통신사 앱을 갱신한 뒤 새 값을 입력해 주세요.")
    }

    func testInitialPlanTakesFreshMeasurementBeforeAnchoringCarrierValue() throws {
        let suiteName = "AppModelCalibrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let usageRepository = UsageRepository(defaults: defaults)
        let settingsRepository = SettingsRepository(defaults: defaults)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        try usageRepository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: now.addingTimeInterval(-60),
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 1_000,
                    sentBytes: 1_000,
                    classification: .cellular
                )
            ]
        ))
        let model = AppModel(
            settingsRepository: settingsRepository,
            usageRepository: usageRepository,
            reader: RefreshMockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 1_500,
                    sentBytes: 1_500,
                    classification: .cellular
                )
            ])
        )
        var plan = PlanSettings.standard
        plan.alert50 = false
        plan.alert80 = false
        plan.alert90 = false
        plan.manualAdjustmentBytes = 40 * DataBytes.gigabyte

        XCTAssertTrue(model.savePlan(plan, at: now))

        XCTAssertEqual(model.plan?.manualAdjustmentMeasuredBytes, 1_000)
        XCTAssertEqual(model.summary.usedBytes, 40 * DataBytes.gigabyte)
        XCTAssertEqual(usageRepository.latestSnapshot()?.measuredAt, now)
        XCTAssertTrue(settingsRepository.hasCompletedOnboarding)

        // A following refresh with unchanged counters cannot add the 1,000
        // bytes that were already included in the carrier's 40 GB reading.
        let later = try UsageRefreshService(
            settingsRepository: settingsRepository,
            usageRepository: usageRepository,
            reader: RefreshMockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 1_500,
                    sentBytes: 1_500,
                    classification: .cellular
                )
            ])
        ).refresh(at: now.addingTimeInterval(60))
        XCTAssertEqual(later?.usedBytes, 40 * DataBytes.gigabyte)
    }

    func testInitialCarrierValueIsNotSavedWithoutFreshCellularBaseline() throws {
        let suiteName = "AppModelCalibrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let usageRepository = UsageRepository(defaults: defaults)
        let settingsRepository = SettingsRepository(defaults: defaults)
        let model = AppModel(
            settingsRepository: settingsRepository,
            usageRepository: usageRepository,
            reader: RefreshMockCounterReader(counters: [])
        )
        var plan = PlanSettings.standard
        plan.manualAdjustmentBytes = 40 * DataBytes.gigabyte

        XCTAssertFalse(model.savePlan(plan))

        XCTAssertNil(settingsRepository.loadPlan())
        XCTAssertNil(model.plan)
        XCTAssertFalse(settingsRepository.hasCompletedOnboarding)
        XCTAssertNotNil(model.errorMessage)
    }

    func testCalibrationTakesFreshMeasurementBeforeAnchoringCarrierValue() throws {
        let suiteName = "AppModelCalibrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let usageRepository = UsageRepository(defaults: defaults)
        let settingsRepository = SettingsRepository(defaults: defaults)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        var plan = PlanSettings.standard
        plan.resetDay = 1
        try settingsRepository.save(plan: plan)

        try usageRepository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: now.addingTimeInterval(-60),
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 1_000,
                    sentBytes: 1_000,
                    classification: .cellular
                )
            ]
        ))

        let model = AppModel(
            settingsRepository: settingsRepository,
            usageRepository: usageRepository,
            reader: RefreshMockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 1_500,
                    sentBytes: 1_500,
                    classification: .cellular
                )
            ])
        )

        XCTAssertTrue(model.saveManualCalibration(bytes: 40 * DataBytes.gigabyte, at: now))
        XCTAssertEqual(model.plan?.manualAdjustmentMeasuredBytes, 1_000)
        XCTAssertEqual(model.summary.usedBytes, 40 * DataBytes.gigabyte)
        XCTAssertEqual(usageRepository.dailyUsage().first?.totalBytes, 1_000)
    }

    func testCalibrationIsRejectedWhenNoFreshCellularBaselineWasCommitted() throws {
        let suiteName = "AppModelCalibrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let usageRepository = UsageRepository(defaults: defaults)
        let settingsRepository = SettingsRepository(defaults: defaults)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let plan = PlanSettings.standard
        try settingsRepository.save(plan: plan)
        try usageRepository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: now.addingTimeInterval(-60),
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 1_000,
                    sentBytes: 1_000,
                    classification: .cellular
                )
            ]
        ))

        let model = AppModel(
            settingsRepository: settingsRepository,
            usageRepository: usageRepository,
            reader: RefreshMockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "en0",
                    receivedBytes: 10_000,
                    sentBytes: 10_000,
                    classification: .wifi
                )
            ])
        )

        XCTAssertFalse(model.saveManualCalibration(bytes: 40 * DataBytes.gigabyte, at: now))
        XCTAssertEqual(model.plan?.manualAdjustmentBytes, 0)
        XCTAssertEqual(usageRepository.latestSnapshot()?.measuredAt, now.addingTimeInterval(-60))
    }
}

private struct RefreshMockCounterReader: NetworkCounterReading {
    let counters: [NetworkInterfaceCounter]

    func readCounters() throws -> [NetworkInterfaceCounter] {
        counters
    }
}
