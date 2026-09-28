import XCTest
@testable import DataView

final class LegacyDataCompatibilityTests: XCTestCase {
    func testSavedPlanWithRemovedFieldsKeepsCalibrationAndPreferences() throws {
        let suiteName = "LegacyDataCompatibilityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data(Self.legacyPlan.utf8), forKey: "planSettings")
        defaults.set(true, forKey: "hasCompletedOnboarding")
        defaults.set("dark", forKey: "displayTheme")
        let repository = SettingsRepository(defaults: defaults)

        let plan = try XCTUnwrap(repository.loadPlan())

        XCTAssertEqual(plan.dataLimitBytes, 100_000_000_000)
        XCTAssertEqual(plan.resetDay, 15)
        XCTAssertFalse(plan.isUnlimited)
        XCTAssertFalse(plan.alert50)
        XCTAssertTrue(plan.alert80)
        XCTAssertTrue(plan.alert90)
        XCTAssertEqual(plan.manualAdjustmentBytes, 40_000_000_000)
        XCTAssertEqual(plan.manualAdjustmentMeasuredBytes, 250)
        XCTAssertEqual(plan.manualAdjustmentPeriodStart, Date(timeIntervalSinceReferenceDate: 799_000_000))
        XCTAssertEqual(plan.billingTimeZoneIdentifier, "Asia/Seoul")
        XCTAssertTrue(repository.hasCompletedOnboarding)
        XCTAssertEqual(defaults.string(forKey: "displayTheme"), "dark")

        try repository.save(plan: plan)
        XCTAssertEqual(repository.loadPlan(), plan)
        let saved = try XCTUnwrap(defaults.data(forKey: "planSettings"))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        XCTAssertNil(payload["hotspot"])
    }

    func testSavedWidgetSummaryWithRemovedFieldsKeepsCellularPresentation() throws {
        let summary = try JSONDecoder().decode(WidgetSummary.self, from: Data(Self.legacySummary.utf8))

        XCTAssertEqual(summary.usedBytes, 40_000_000_000)
        XCTAssertEqual(summary.limitBytes, 100_000_000_000)
        XCTAssertEqual(summary.remainingBytes, 60_000_000_000)
        XCTAssertEqual(summary.usagePercent, 0.4)
        XCTAssertEqual(summary.todayBytes, 250)
        XCTAssertEqual(summary.measurementQuality, .verified)
        XCTAssertEqual(summary.billingTimeZoneIdentifier, "Asia/Seoul")
        let presentation = WidgetSummaryPresentation(summary: summary, date: summary.generatedAt)
        XCTAssertTrue(presentation.hasConfiguredPlan)
        XCTAssertTrue(presentation.hasCurrentDayUsage)
        XCTAssertFalse(presentation.isUnlimited)

        let saved = try JSONEncoder().encode(summary)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: saved) as? [String: Any])
        for key in ["hotspotBytes", "hotspotSupportState", "hotspotLimitBytes", "hotspotRemainingBytes", "hotspotUsagePercent"] {
            XCTAssertNil(payload[key])
        }
    }

    func testOldMeasurementStateRetainsHistoryAndContinuesOnlyCellularDeltas() throws {
        // Exercise both the current atomic state and older separate-key storage.
        for schemaVersion in [2, 3] {
            let suiteName = "LegacyDataCompatibilityTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }
            defaults.set(schemaVersion, forKey: "measurementSchemaVersion")
            let data = Data(Self.legacyMeasurementState.utf8)
            if schemaVersion == 3 {
                defaults.set(data, forKey: "measurementState")
            } else {
                let state = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                for (field, key) in [
                    ("snapshot", "latestInterfaceSnapshot"),
                    ("samples", "usageSamples"),
                    ("daily", "dailyUsage")
                ] {
                    let value = try XCTUnwrap(state[field])
                    defaults.set(try JSONSerialization.data(withJSONObject: value), forKey: key)
                }
            }
            let repository = UsageRepository(defaults: defaults)
            let snapshot = try XCTUnwrap(repository.latestSnapshot())
            XCTAssertEqual(snapshot.counters.map(\.classification), [.cellular, .unknown, .unknown])
            XCTAssertEqual(repository.samples().first?.cellularBytes, 250)
            XCTAssertEqual(repository.samples().first?.measurementQuality, .verified)
            XCTAssertEqual(repository.dailyUsage().first?.cellularBytes, 250)
            XCTAssertEqual(repository.dailyUsage().first?.totalBytes, 250)

            let now = snapshot.measuredAt.addingTimeInterval(60)
            let result = try UsageMeasurementService(
                reader: LegacyStateCounterReader(),
                repository: repository,
                systemBootTime: { snapshot.systemBootTime },
                continuousTime: { 10_120 }
            ).measure(at: now)

            XCTAssertEqual(result.cellularBytes, 400)
            XCTAssertEqual(result.quality, .verified)
            XCTAssertEqual(repository.samples().map(\.cellularBytes), [250, 400])
            XCTAssertEqual(repository.dailyUsage().reduce(Int64(0)) { $0 + $1.totalBytes }, 650)
            XCTAssertEqual(repository.latestSnapshot()?.measuredAt, now)
            let reopened = UsageRepository(defaults: defaults)
            XCTAssertEqual(reopened.samples(), repository.samples())
            XCTAssertEqual(reopened.dailyUsage(), repository.dailyUsage())
        }
    }

    // Literal payloads intentionally retain the pre-removal schema rather than
    // being produced by today's encoder, so accidental incompatibility is caught.
    private static let legacyPlan = """
    {
      "dataLimitBytes": 100000000000, "resetDay": 15, "isUnlimited": false,
      "alert50": false, "alert80": true, "alert90": true,
      "manualAdjustmentBytes": 40000000000,
      "manualAdjustmentPeriodStart": 799000000,
      "manualAdjustmentMeasuredBytes": 250,
      "billingTimeZoneIdentifier": "Asia/Seoul",
      "createdAt": 799000000, "updatedAt": 800000060,
      "hotspot": {
        "limitBytes": 30000000000, "alert80": true, "alert90": true,
        "manualAdjustmentBytes": 10000000000,
        "manualAdjustmentPeriodStart": 799000000,
        "manualAdjustmentMeasuredBytes": 100
      }
    }
    """

    private static let legacySummary = """
    {
      "generatedAt": 800000060, "periodStart": 799000000, "periodEnd": 802000000,
      "usedBytes": 40000000000, "limitBytes": 100000000000,
      "remainingBytes": 60000000000, "usagePercent": 0.4,
      "iPhoneBytes": 40000000000, "todayBytes": 250,
      "isUnlimited": false, "billingTimeZoneIdentifier": "Asia/Seoul",
      "measurementQuality": "verified",
      "hotspotBytes": 10000000000, "hotspotSupportState": "experimental",
      "hotspotLimitBytes": 30000000000, "hotspotRemainingBytes": 20000000000,
      "hotspotUsagePercent": 0.3333333333
    }
    """

    private static let legacyMeasurementState = """
    {
      "snapshot": {
        "measuredAt": 800000060, "systemBootTime": 799990000, "continuousTime": 10060,
        "counters": [
          {"name": "pdp_ip0", "receivedBytes": 1000, "sentBytes": 2000, "classification": "cellular"},
          {"name": "bridge100", "receivedBytes": 1000, "sentBytes": 2000, "classification": "hotspotCandidate"},
          {"name": "ap1", "receivedBytes": 1000, "sentBytes": 2000, "classification": "hotspotCandidate"}
        ]
      },
      "samples": [{
        "id": "865821B3-85E3-466A-A4E1-68A679755217",
        "from": 800000000, "to": 800000060,
        "cellularBytes": 250, "hotspotBytes": 100, "measurementQuality": "verified"
      }],
      "daily": [{"id": 800000000, "cellularBytes": 250, "hotspotBytes": 100, "totalBytes": 250}]
    }
    """
}

private struct LegacyStateCounterReader: NetworkCounterReading {
    func readCounters() throws -> [NetworkInterfaceCounter] {
        [
            NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 1_100, sentBytes: 2_300, classification: .cellular),
            NetworkInterfaceCounter(name: "bridge100", receivedBytes: 100_000, sentBytes: 200_000, classification: .unknown),
            NetworkInterfaceCounter(name: "ap1", receivedBytes: 100_000, sentBytes: 200_000, classification: .unknown)
        ]
    }
}
