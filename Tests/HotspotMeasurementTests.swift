import UserNotifications
import XCTest
@testable import DataView

final class HotspotMeasurementTests: XCTestCase {
    // MARK: - Classification

    func testSharingInterfacesAreHotspotCandidates() {
        XCTAssertEqual(InterfaceClassifier.classify("bridge100"), .hotspotCandidate)
        XCTAssertEqual(InterfaceClassifier.classify("ap1"), .hotspotCandidate)
        XCTAssertEqual(InterfaceClassifier.classify("anpi0"), .unknown)
        XCTAssertEqual(InterfaceClassifier.classify("en0"), .wifi)
        XCTAssertEqual(InterfaceClassifier.classify("pdp_ip0"), .cellular)
    }

    // MARK: - Measurement

    func testHotspotDeltaIsStoredSeparatelyAndNotAddedToTotal() throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }
        try repository.save(snapshot: snapshot(at: 1, [
            cellular("pdp_ip0", rx: 1_000, tx: 1_000),
            sharing("bridge100", rx: 100, tx: 100)
        ]))

        let result = try service(repository, reading: [
            cellular("pdp_ip0", rx: 501_000, tx: 101_000),
            sharing("bridge100", rx: 50_100, tx: 350_100)
        ]).measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.cellularBytes, 600_000)
        XCTAssertEqual(result.hotspotBytes, 400_000)
        let day = try XCTUnwrap(repository.dailyUsage().first)
        XCTAssertEqual(day.totalBytes, 600_000)
        XCTAssertEqual(day.cellularBytes, 600_000)
        XCTAssertEqual(day.hotspotBytes, 400_000)
        XCTAssertEqual(repository.samples().last?.hotspotBytes, 400_000)
    }

    func testBridgeAndAccessPointCarryingSameTrafficAreNotDoubleCounted() throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }
        try repository.save(snapshot: snapshot(at: 1, [
            cellular("pdp_ip0", rx: 1_000, tx: 1_000),
            sharing("ap1", rx: 10_000, tx: 10_000),
            sharing("bridge100", rx: 0, tx: 0)
        ]))

        let result = try service(repository, reading: [
            cellular("pdp_ip0", rx: 401_000, tx: 101_000),
            sharing("ap1", rx: 110_000, tx: 210_000),
            sharing("bridge100", rx: 100_000, tx: 200_000)
        ]).measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.cellularBytes, 500_000)
        XCTAssertEqual(result.hotspotBytes, 300_000)
    }

    func testHotspotNeverExceedsCellularDeltaOfSameInterval() throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }
        try repository.save(snapshot: snapshot(at: 1, [
            cellular("pdp_ip0", rx: 1_000, tx: 1_000),
            sharing("bridge100", rx: 0, tx: 0)
        ]))

        let result = try service(repository, reading: [
            cellular("pdp_ip0", rx: 101_000, tx: 1_000),
            sharing("bridge100", rx: 150_000, tx: 100_000)
        ]).measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.cellularBytes, 100_000)
        XCTAssertEqual(result.hotspotBytes, 100_000)
    }

    func testNewSharingBridgeCountsItsSessionTotal() throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }
        try repository.save(snapshot: snapshot(at: 1, [
            cellular("pdp_ip0", rx: 1_000, tx: 1_000)
        ]))

        let result = try service(repository, reading: [
            cellular("pdp_ip0", rx: 701_000, tx: 101_000),
            sharing("bridge100", rx: 200_000, tx: 300_000)
        ]).measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.hotspotBytes, 500_000)
    }

    func testSharingCounterStoredByOlderBuildIsOnlyABaseline() throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }
        // Builds before hotspot tracking stored sharing interfaces as unknown.
        try repository.save(snapshot: snapshot(at: 1, [
            cellular("pdp_ip0", rx: 1_000, tx: 1_000),
            NetworkInterfaceCounter(
                name: "bridge100",
                receivedBytes: 5_000_000,
                sentBytes: 5_000_000,
                classification: .unknown
            )
        ]))

        let result = try service(repository, reading: [
            cellular("pdp_ip0", rx: 801_000, tx: 201_000),
            sharing("bridge100", rx: 5_100_000, tx: 5_100_000)
        ]).measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.hotspotBytes, 200_000)
    }

    func testRecreatedBridgeCountsOnlyItsNewGeneration() throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }
        try repository.save(snapshot: snapshot(at: 1, [
            cellular("pdp_ip0", rx: 1_000, tx: 1_000),
            sharing("bridge100", rx: 900_000, tx: 900_000)
        ]))

        let result = try service(repository, reading: [
            cellular("pdp_ip0", rx: 501_000, tx: 1_000),
            sharing("bridge100", rx: 30_000, tx: 20_000)
        ]).measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.hotspotBytes, 50_000)
    }

    func testWithoutSharingInterfacesHotspotStaysEmpty() throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }
        try repository.save(snapshot: snapshot(at: 1, [
            cellular("pdp_ip0", rx: 1_000, tx: 1_000)
        ]))

        let result = try service(repository, reading: [
            cellular("pdp_ip0", rx: 11_000, tx: 1_000)
        ]).measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.hotspotBytes, 0)
        XCTAssertNil(repository.dailyUsage().first?.hotspotBytes)
        XCTAssertNil(repository.samples().last?.hotspotBytes)
    }

    func testUnseenAccessPointIsOnlyABaseline() throws {
        let (repository, cleanup) = try makeRepository()
        defer { cleanup() }
        try repository.save(snapshot: snapshot(at: 1, [
            cellular("pdp_ip0", rx: 1_000, tx: 1_000)
        ]))

        // A persistent soft-AP missing from the last snapshot may hold earlier
        // sessions' traffic, so it must not be counted in full.
        let result = try service(repository, reading: [
            cellular("pdp_ip0", rx: 301_000, tx: 1_000),
            sharing("ap1", rx: 4_000_000, tx: 4_000_000)
        ]).measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.cellularBytes, 300_000)
        XCTAssertEqual(result.hotspotBytes, 0)
    }

    // MARK: - Calibration and summary

    func testHotspotCalibrationAddsOnlyLaterHotspotTraffic() {
        let service = HotspotCalibrationService()
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let period = DateInterval(start: start, duration: 30 * 86_400)
        let calibrated = service.calibrate(
            settings: HotspotPlanSettings(limitBytes: 30 * DataBytes.gigabyte),
            carrierUsageBytes: 10 * DataBytes.gigabyte,
            measuredBytes: 2 * DataBytes.gigabyte,
            period: period
        )

        let resolved = service.resolve(
            settings: calibrated,
            measuredBytes: 3 * DataBytes.gigabyte,
            period: period
        )
        XCTAssertEqual(resolved.usedBytes, 11 * DataBytes.gigabyte)

        let nextPeriod = DateInterval(start: period.end, duration: 30 * 86_400)
        let nextResolved = service.resolve(
            settings: calibrated,
            measuredBytes: DataBytes.gigabyte,
            period: nextPeriod
        )
        XCTAssertEqual(nextResolved.usedBytes, DataBytes.gigabyte)
        XCTAssertNil(nextResolved.settings.manualAdjustmentPeriodStart)
        XCTAssertEqual(nextResolved.settings.limitBytes, 30 * DataBytes.gigabyte)
    }

    func testSummaryReportsHotspotAllowanceWithoutChangingDataTotal() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 12)))
        let day = calendar.startOfDay(for: now)
        var plan = PlanSettings.standard
        plan.resetDay = 1
        plan.hotspot = HotspotPlanSettings(limitBytes: 10 * DataBytes.gigabyte)

        let result = UsageSummaryBuilder().build(
            plan: plan,
            dailyUsage: [DailyUsage(
                id: day,
                cellularBytes: 5 * DataBytes.gigabyte,
                hotspotBytes: 4 * DataBytes.gigabyte,
                totalBytes: 5 * DataBytes.gigabyte
            )],
            at: now,
            calendar: calendar
        )

        XCTAssertEqual(result.summary.usedBytes, 5 * DataBytes.gigabyte)
        XCTAssertEqual(result.summary.hotspotBytes, 4 * DataBytes.gigabyte)
        XCTAssertEqual(result.summary.hotspotLimitBytes, 10 * DataBytes.gigabyte)
        XCTAssertEqual(result.summary.hotspotRemainingBytes, 6 * DataBytes.gigabyte)
        XCTAssertEqual(try XCTUnwrap(result.summary.hotspotUsagePercent), 0.4, accuracy: 0.0001)
        XCTAssertEqual(result.summary.hotspotSupportState, .experimental)
    }

    func testSummaryWithoutHotspotDataOrSettingsHidesHotspot() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15, hour: 12)))
        let result = UsageSummaryBuilder().build(
            plan: .standard,
            dailyUsage: [DailyUsage(
                id: calendar.startOfDay(for: now),
                cellularBytes: DataBytes.gigabyte,
                hotspotBytes: nil,
                totalBytes: DataBytes.gigabyte
            )],
            at: now,
            calendar: calendar
        )

        XCTAssertNil(result.summary.hotspotBytes)
        XCTAssertNil(result.summary.hotspotLimitBytes)
        XCTAssertEqual(result.summary.hotspotSupportState, .unsupported)
    }

    func testPlanSavedBeforeHotspotTrackingStillDecodes() throws {
        var legacy = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(PlanSettings.standard)) as? [String: Any]
        )
        legacy.removeValue(forKey: "hotspot")
        let data = try JSONSerialization.data(withJSONObject: legacy)

        let decoded = try JSONDecoder().decode(PlanSettings.self, from: data)
        XCTAssertNil(decoded.hotspot)
        XCTAssertEqual(decoded.resetDay, PlanSettings.standard.resetDay)
    }

    func testHotspotRemainingIsBoundedByTotalDataLeft() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12)))
        var plan = PlanSettings.standard
        plan.resetDay = 1
        plan.dataLimitBytes = 160 * DataBytes.gigabyte
        plan.hotspot = HotspotPlanSettings(limitBytes: 50 * DataBytes.gigabyte)

        let result = UsageSummaryBuilder().build(
            plan: plan,
            dailyUsage: [DailyUsage(
                id: calendar.startOfDay(for: now),
                cellularBytes: 155 * DataBytes.gigabyte,
                hotspotBytes: 20 * DataBytes.gigabyte,
                totalBytes: 155 * DataBytes.gigabyte
            )],
            at: now,
            calendar: calendar
        )

        // 30 GB of hotspot allowance is left, but only 5 GB of data overall.
        XCTAssertEqual(result.summary.remainingBytes, 5 * DataBytes.gigabyte)
        XCTAssertEqual(result.summary.hotspotRemainingBytes, 5 * DataBytes.gigabyte)
        XCTAssertEqual(try XCTUnwrap(result.summary.hotspotUsagePercent), 0.4, accuracy: 0.0001)
    }

    func testHotspotAllowanceValidationFollowsTotalPlan() {
        let gb = DataBytes.gigabyte
        XCTAssertNil(HotspotPlanValidator.limitMessage(hotspotLimitBytes: 50 * gb, dataLimitBytes: 160 * gb))
        XCTAssertNotNil(HotspotPlanValidator.limitMessage(hotspotLimitBytes: 200 * gb, dataLimitBytes: 160 * gb))
        XCTAssertNil(HotspotPlanValidator.limitMessage(hotspotLimitBytes: 200 * gb, dataLimitBytes: nil))

        XCTAssertNil(HotspotPlanValidator.usageMessage(hotspotUsedBytes: 12 * gb, hotspotLimitBytes: 50 * gb, dataUsedBytes: 40 * gb))
        XCTAssertNotNil(HotspotPlanValidator.usageMessage(hotspotUsedBytes: 55 * gb, hotspotLimitBytes: 50 * gb, dataUsedBytes: nil))
        XCTAssertNotNil(HotspotPlanValidator.usageMessage(hotspotUsedBytes: 20 * gb, hotspotLimitBytes: 50 * gb, dataUsedBytes: 10 * gb))
        XCTAssertNil(HotspotPlanValidator.usageMessage(hotspotUsedBytes: 20 * gb, hotspotLimitBytes: 50 * gb, dataUsedBytes: 0))
    }

    /// Scenario: the app was installed after the reset day. The user sets a
    /// 50 GB hotspot allowance and enters the 12 GB the carrier already shows;
    /// only hotspot traffic after saving is added to it.
    @MainActor
    func testAllowanceEnabledMidPeriodStartsFromCarrierValue() throws {
        let suiteName = "HotspotMeasurementTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsRepository(defaults: defaults)
        let usage = UsageRepository(defaults: defaults)
        var original = PlanSettings.standard
        original.alert50 = false
        original.alert80 = false
        original.alert90 = false
        try settings.save(plan: original)
        let now = Date.now
        try usage.save(snapshot: snapshot(at: now.addingTimeInterval(-120).timeIntervalSince1970, [
            cellular("pdp_ip0", rx: 1_000, tx: 1_000),
            sharing("bridge100", rx: 0, tx: 0)
        ]))

        let model = AppModel(
            settingsRepository: settings,
            usageRepository: usage,
            reader: HotspotMockCounterReader(counters: [
                cellular("pdp_ip0", rx: 2_000, tx: 2_000),
                sharing("bridge100", rx: 500, tx: 500)
            ])
        )
        var plan = try XCTUnwrap(model.plan)
        plan.hotspot = HotspotPlanSettings(
            limitBytes: 50 * DataBytes.gigabyte,
            alert80: false,
            alert90: false,
            manualAdjustmentBytes: 12 * DataBytes.gigabyte
        )

        XCTAssertTrue(model.savePlan(plan, at: now))
        XCTAssertNotNil(model.plan?.hotspot?.manualAdjustmentPeriodStart)
        // Hotspot traffic before saving is already inside the carrier value.
        XCTAssertEqual(model.summary.hotspotBytes, 12 * DataBytes.gigabyte)

        let next = try UsageRefreshService(
            settingsRepository: settings,
            usageRepository: usage,
            reader: HotspotMockCounterReader(counters: [
                cellular("pdp_ip0", rx: 3_000, tx: 3_000),
                sharing("bridge100", rx: 900, tx: 900)
            ])
        ).refresh(at: now.addingTimeInterval(60))

        XCTAssertEqual(next?.hotspotBytes, 12 * DataBytes.gigabyte + 800)
        XCTAssertEqual(next?.hotspotLimitBytes, 50 * DataBytes.gigabyte)
        XCTAssertEqual(next?.hotspotRemainingBytes, 38 * DataBytes.gigabyte - 800)
    }

    // MARK: - Alerts

    @MainActor
    func testHotspotAlertSendsOnlyHighestCrossedThresholdOnce() async throws {
        let suiteName = "HotspotMeasurementTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let center = HotspotMockNotificationCenter()
        let service = UsageNotificationService(center: center, defaults: defaults)
        var plan = PlanSettings.standard
        plan.alert50 = false
        plan.alert80 = false
        plan.alert90 = false
        plan.hotspot = HotspotPlanSettings(limitBytes: 10 * DataBytes.gigabyte)
        var summary = WidgetSummary.empty
        summary.hotspotLimitBytes = 10 * DataBytes.gigabyte
        summary.hotspotUsagePercent = 0.92

        await service.evaluate(summary: summary, plan: plan)
        await service.evaluate(summary: summary, plan: plan)

        XCTAssertEqual(center.deliveredRequests.count, 1)
        XCTAssertEqual(center.deliveredRequests.first?.content.title, "핫스팟 사용량 90% 도달")
    }

    // MARK: - Helpers

    private func makeRepository() throws -> (UsageRepository, () -> Void) {
        let suiteName = "HotspotMeasurementTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        return (UsageRepository(defaults: defaults), { defaults.removePersistentDomain(forName: suiteName) })
    }

    private func service(
        _ repository: UsageRepository,
        reading counters: [NetworkInterfaceCounter]
    ) -> UsageMeasurementService {
        UsageMeasurementService(
            reader: HotspotMockCounterReader(counters: counters),
            repository: repository,
            systemBootTime: { nil },
            continuousTime: { nil }
        )
    }

    private func snapshot(at seconds: TimeInterval, _ counters: [NetworkInterfaceCounter]) -> InterfaceCounterSnapshot {
        InterfaceCounterSnapshot(measuredAt: Date(timeIntervalSince1970: seconds), counters: counters)
    }

    private func cellular(_ name: String, rx: UInt64, tx: UInt64) -> NetworkInterfaceCounter {
        NetworkInterfaceCounter(name: name, receivedBytes: rx, sentBytes: tx, classification: .cellular)
    }

    private func sharing(_ name: String, rx: UInt64, tx: UInt64) -> NetworkInterfaceCounter {
        NetworkInterfaceCounter(name: name, receivedBytes: rx, sentBytes: tx, classification: .hotspotCandidate)
    }
}

private struct HotspotMockCounterReader: NetworkCounterReading {
    let counters: [NetworkInterfaceCounter]
    func readCounters() throws -> [NetworkInterfaceCounter] { counters }
}

@MainActor
private final class HotspotMockNotificationCenter: UsageNotificationScheduling {
    var deliveredRequests: [UNNotificationRequest] = []

    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func add(_ request: UNNotificationRequest) async throws {
        deliveredRequests.append(request)
    }
}
