import XCTest
@testable import DataView

final class UsageMeasurementServiceTests: XCTestCase {
    func testForwardClockCorrectionDoesNotCountLifetimeTotalAgain() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let start = Date(timeIntervalSince1970: 100_000)
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 20_000_000_000, sentBytes: 0, classification: .cellular)],
            systemBootTime: start.addingTimeInterval(-10_000),
            continuousTime: 10_000
        ))
        let result = try UsageMeasurementService(
            reader: MockCounterReader(counters: [NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 20_000_001_000, sentBytes: 0, classification: .cellular)]),
            repository: repository,
            systemBootTime: { start.addingTimeInterval(-10_000 + 300) },
            continuousTime: { 10_060 }
        ).measure(at: start.addingTimeInterval(360))

        XCTAssertEqual(result.cellularBytes, 1_000)
        XCTAssertEqual(result.quality, .partial)
        XCTAssertEqual(repository.samples().last?.from, start.addingTimeInterval(300))
    }

    func testBackwardClockCorrectionContinuesMeasuring() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let start = Date(timeIntervalSince1970: 100_000)
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 20_000, sentBytes: 0, classification: .cellular)],
            systemBootTime: start.addingTimeInterval(-10_000),
            continuousTime: 10_000
        ))
        let date = start.addingTimeInterval(-240)
        let result = try UsageMeasurementService(
            reader: MockCounterReader(counters: [NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 21_000, sentBytes: 0, classification: .cellular)]),
            repository: repository,
            systemBootTime: { start.addingTimeInterval(-10_000 - 300) },
            continuousTime: { 10_060 }
        ).measure(at: date)

        XCTAssertEqual(result.cellularBytes, 1_000)
        XCTAssertEqual(repository.latestSnapshot()?.measuredAt, date)
        XCTAssertEqual(repository.samples().last?.from, start.addingTimeInterval(-300))
    }

    func testLegacyBootDateChangeDoesNotRecountLifetimeTotal() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let start = Date(timeIntervalSince1970: 100_000)
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 20_000_000_000, sentBytes: 0, classification: .cellular)],
            systemBootTime: start.addingTimeInterval(-10_000)
        ))
        let result = try UsageMeasurementService(
            reader: MockCounterReader(counters: [NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 20_000_001_000, sentBytes: 0, classification: .cellular)]),
            repository: repository,
            systemBootTime: { start.addingTimeInterval(-10_000 + 300) },
            continuousTime: { 10_060 }
        ).measure(at: start.addingTimeInterval(360))

        XCTAssertEqual(result.cellularBytes, 1_000)
        XCTAssertEqual(result.quality, .partial)
    }

    func testCalibrationAllowsMissingInterfaceWithoutReaddingCoveredBytesOnReturn() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let start = Date(timeIntervalSince1970: 100_000)
        let boot = start.addingTimeInterval(-10_000)
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [
                NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 100, sentBytes: 0, classification: .cellular),
                NetworkInterfaceCounter(name: "pdp_ip1", receivedBytes: 1_000, sentBytes: 0, classification: .cellular)
            ],
            systemBootTime: boot
        ))
        let date = start.addingTimeInterval(60)
        _ = try UsageMeasurementService(
            reader: MockCounterReader(counters: [NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 200, sentBytes: 0, classification: .cellular)]),
            repository: repository,
            systemBootTime: { boot },
            continuousTime: { 10_060 }
        ).prepareCalibrationBaseline(at: date)
        XCTAssertEqual(repository.latestSnapshot()?.counters.first(where: { $0.name == "pdp_ip1" })?.requiresBaseline, true)

        let result = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 250, sentBytes: 0, classification: .cellular),
                NetworkInterfaceCounter(name: "pdp_ip1", receivedBytes: 9_000, sentBytes: 0, classification: .cellular)
            ]),
            repository: repository,
            systemBootTime: { boot },
            continuousTime: { 10_120 }
        ).measure(at: start.addingTimeInterval(120))
        XCTAssertEqual(result.cellularBytes, 50)
        XCTAssertEqual(result.quality, .partial)
        XCTAssertNil(repository.latestSnapshot()?.counters.first(where: { $0.name == "pdp_ip1" })?.requiresBaseline)

        let next = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 250, sentBytes: 0, classification: .cellular),
                NetworkInterfaceCounter(name: "pdp_ip1", receivedBytes: 9_100, sentBytes: 0, classification: .cellular)
            ]),
            repository: repository,
            systemBootTime: { boot },
            continuousTime: { 10_180 }
        ).measure(at: start.addingTimeInterval(180))
        XCTAssertEqual(next.cellularBytes, 100)
    }

    func testCalibrationRejectsAllCellularInterfacesMissing() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let service = UsageMeasurementService(reader: MockCounterReader(counters: []), repository: repository)
        XCTAssertThrowsError(try service.prepareCalibrationBaseline())
        XCTAssertNil(repository.latestSnapshot())
    }

    func testFirstBaselineCompareAndSwapCannotReplaceExistingState() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let first = InterfaceCounterSnapshot(measuredAt: Date(timeIntervalSince1970: 100), counters: [])
        let stale = InterfaceCounterSnapshot(measuredAt: Date(timeIntervalSince1970: 99), counters: [])
        XCTAssertTrue(try repository.initialize(snapshot: first))
        XCTAssertFalse(try repository.initialize(snapshot: stale))
        XCTAssertEqual(repository.latestSnapshot(), first)
    }

    func testUnknownInterfacesAreExcluded() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)

        let baseline = InterfaceCounterSnapshot(
            measuredAt: Date(timeIntervalSince1970: 1),
            counters: [
                NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 100, sentBytes: 100, classification: .cellular),
                NetworkInterfaceCounter(name: "future0", receivedBytes: 100, sentBytes: 100, classification: .unknown)
            ]
        )
        try repository.save(snapshot: baseline)

        let reader = MockCounterReader(counters: [
            NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 150, sentBytes: 120, classification: .cellular),
            NetworkInterfaceCounter(name: "future0", receivedBytes: 9_000, sentBytes: 9_000, classification: .unknown)
        ])
        let service = UsageMeasurementService(reader: reader, repository: repository)
        let result = try service.measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.cellularBytes, 70)
        XCTAssertEqual(repository.dailyUsage().first?.totalBytes, 70)
    }

    func testClassifierUpgradeUsesPriorUnknownCounterAsBaseline() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let bootTime = Date(timeIntervalSince1970: 100)
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: Date(timeIntervalSince1970: 1_000),
            counters: [
                NetworkInterfaceCounter(
                    name: "future_cell0",
                    receivedBytes: 4_000_000_000,
                    sentBytes: 1_000,
                    classification: .unknown,
                    interfaceIndex: 7
                )
            ],
            systemBootTime: bootTime
        ))

        let result = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "future_cell0",
                    receivedBytes: 4_000_000_500,
                    sentBytes: 1_200,
                    classification: .cellular,
                    interfaceIndex: 7,
                    interfaceType: 0xFF
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: Date(timeIntervalSince1970: 1_060))

        XCTAssertEqual(result.cellularBytes, 700)
        XCTAssertEqual(result.quality, .verified)
    }

    func testFirstMeasurementCreatesBaselineWithoutCountingHistory() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let reader = MockCounterReader(counters: [
            NetworkInterfaceCounter(name: "pdp_ip0", receivedBytes: 500, sentBytes: 100, classification: .cellular)
        ])

        let result = try UsageMeasurementService(reader: reader, repository: repository).measure()
        XCTAssertEqual(result.cellularBytes, 0)
        XCTAssertEqual(result.quality, .unavailable)
        XCTAssertTrue(repository.dailyUsage().isEmpty)
    }

    func testFirstCellularCounterAfterWiFiOnlyBaselineIsNotCountedAsNewUsage() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let bootTime = Date(timeIntervalSince1970: 100)
        let start = Date(timeIntervalSince1970: 1_000)
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [
                NetworkInterfaceCounter(
                    name: "en0",
                    receivedBytes: 100,
                    sentBytes: 100,
                    classification: .wifi
                )
            ],
            systemBootTime: bootTime
        ))
        let existingLifetimeTotal = UInt64(19_700_000_000)

        let baseline = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: existingLifetimeTotal,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 4,
                    interfaceType: 0xFF
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: start.addingTimeInterval(60))

        XCTAssertEqual(baseline.cellularBytes, 0)
        XCTAssertEqual(baseline.quality, .unavailable)
        XCTAssertTrue(repository.dailyUsage().isEmpty)

        let next = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: existingLifetimeTotal + 1_000,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 4,
                    interfaceType: 0xFF
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: start.addingTimeInterval(120))

        XCTAssertEqual(next.cellularBytes, 1_000)
        XCTAssertEqual(next.quality, .verified)
    }

    func testCounterResetCountsRecoverablePostResetBytes() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)

        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: Date(timeIntervalSince1970: 1),
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 9_000,
                    sentBytes: 1_000,
                    classification: .cellular
                )
            ]
        ))

        let reader = MockCounterReader(counters: [
            NetworkInterfaceCounter(
                name: "pdp_ip0",
                receivedBytes: 100,
                sentBytes: 50,
                classification: .cellular
            )
        ])
        let result = try UsageMeasurementService(reader: reader, repository: repository)
            .measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.cellularBytes, 150)
        XCTAssertEqual(result.quality, .partial)
        XCTAssertEqual(repository.dailyUsage().first?.totalBytes, 150)
    }

    func testReceiveResetIsDetectedEvenWhenSentTotalIncreases() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)

        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: Date(timeIntervalSince1970: 1),
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 9_000,
                    sentBytes: 1_000,
                    classification: .cellular
                )
            ]
        ))

        let reader = MockCounterReader(counters: [
            NetworkInterfaceCounter(
                name: "pdp_ip0",
                receivedBytes: 100,
                sentBytes: 12_000,
                classification: .cellular
            )
        ])
        let result = try UsageMeasurementService(reader: reader, repository: repository)
            .measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.cellularBytes, 12_100)
        XCTAssertEqual(result.quality, .partial)
    }

    func testNewCellularInterfaceIsBaselinedAndMarksMeasurementPartial() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)

        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: Date(timeIntervalSince1970: 1),
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 100,
                    sentBytes: 100,
                    classification: .cellular
                )
            ]
        ))

        let reader = MockCounterReader(counters: [
            NetworkInterfaceCounter(
                name: "pdp_ip0",
                receivedBytes: 150,
                sentBytes: 120,
                classification: .cellular
            ),
            NetworkInterfaceCounter(
                name: "pdp_ip1",
                receivedBytes: 5_000,
                sentBytes: 2_000,
                classification: .cellular
            )
        ])
        let result = try UsageMeasurementService(reader: reader, repository: repository)
            .measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.cellularBytes, 7_070)
        XCTAssertEqual(result.quality, .partial)
    }

    func testSystemRebootCreatesNewBaselineEvenWhenCountersAreHigher() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)

        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: Date(timeIntervalSince1970: 1),
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 100,
                    sentBytes: 100,
                    classification: .cellular
                )
            ],
            systemBootTime: Date(timeIntervalSince1970: 100),
            continuousTime: 10_000
        ))

        let reader = MockCounterReader(counters: [
            NetworkInterfaceCounter(
                name: "pdp_ip0",
                receivedBytes: 10_000,
                sentBytes: 5_000,
                classification: .cellular
            )
        ])
        let service = UsageMeasurementService(
            reader: reader,
            repository: repository,
            systemBootTime: { Date(timeIntervalSince1970: 1_000) },
            continuousTime: { 100 }
        )
        let result = try service.measure(at: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.cellularBytes, 15_000)
        XCTAssertEqual(result.quality, .partial)
        XCTAssertEqual(repository.dailyUsage().first?.totalBytes, 15_000)
    }

    func testLongWallClockIntervalWithSameBootStillCountsUsage() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let bootTime = Date(timeIntervalSince1970: 100)

        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: Date(timeIntervalSince1970: 1_000),
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 100,
                    sentBytes: 100,
                    classification: .cellular
                )
            ],
            systemBootTime: bootTime
        ))

        let reader = MockCounterReader(counters: [
            NetworkInterfaceCounter(
                name: "pdp_ip0",
                receivedBytes: 180,
                sentBytes: 125,
                classification: .cellular
            )
        ])
        let service = UsageMeasurementService(
            reader: reader,
            repository: repository,
            systemBootTime: { bootTime }
        )
        let result = try service.measure(at: Date(timeIntervalSince1970: 100_000))

        XCTAssertEqual(result.cellularBytes, 105)
        XCTAssertEqual(result.quality, .estimated)
    }

    func testRecreatedInterfaceIndexUsesCurrentGenerationTotal() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let bootTime = Date(timeIntervalSince1970: 100)

        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: Date(timeIntervalSince1970: 1_000),
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 100,
                    sentBytes: 100,
                    classification: .cellular,
                    interfaceIndex: 4,
                    interfaceType: 0xFF
                )
            ],
            systemBootTime: bootTime
        ))

        let reader = MockCounterReader(counters: [
            NetworkInterfaceCounter(
                name: "pdp_ip0",
                receivedBytes: 1_000,
                sentBytes: 500,
                classification: .cellular,
                interfaceIndex: 9,
                interfaceType: 0xFF
            )
        ])
        let result = try UsageMeasurementService(
            reader: reader,
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: Date(timeIntervalSince1970: 1_060))

        XCTAssertEqual(result.cellularBytes, 1_500)
        XCTAssertEqual(result.quality, .partial)
    }

    func testCrossMidnightIntervalIsProportionallySplitAndEstimated() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 30, hour: 23, minute: 30)
        ))
        let end = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 1, hour: 0, minute: 30)
        ))
        let bootTime = Date(timeIntervalSince1970: 100)

        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 0,
                    sentBytes: 0,
                    classification: .cellular
                )
            ],
            systemBootTime: bootTime
        ))

        let result = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 1_200,
                    sentBytes: 0,
                    classification: .cellular
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime },
            calendar: calendar
        ).measure(at: end)

        XCTAssertEqual(result.cellularBytes, 1_200)
        XCTAssertEqual(result.quality, .estimated)
        XCTAssertEqual(repository.dailyUsage().map(\.totalBytes), [600, 600])
    }

    func testIntervalEndingExactlyAtMidnightStaysInOneVerifiedDayBucket() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 30, hour: 23, minute: 30)
        ))
        let end = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 1, hour: 0)
        ))
        let bootTime = Date(timeIntervalSince1970: 100)
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 0,
                    sentBytes: 0,
                    classification: .cellular
                )
            ],
            systemBootTime: bootTime
        ))

        let result = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 600,
                    sentBytes: 0,
                    classification: .cellular
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime },
            calendar: calendar
        ).measure(at: end)

        XCTAssertEqual(result.cellularBytes, 600)
        XCTAssertEqual(result.quality, .verified)
        XCTAssertEqual(repository.dailyUsage().map(\.totalBytes), [600])
        XCTAssertTrue(calendar.isDate(repository.dailyUsage()[0].id, inSameDayAs: start))
    }

    func testRebootBytesAreAllocatedOnlyAfterKnownBootTime() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let previousDate = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 30, hour: 23)
        ))
        let currentBoot = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 1, hour: 1)
        ))
        let currentDate = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 1, hour: 2)
        ))
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: previousDate,
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 10_000,
                    sentBytes: 5_000,
                    classification: .cellular
                )
            ],
            systemBootTime: previousDate.addingTimeInterval(-86_400),
            continuousTime: 86_400
        ))

        let result = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 900,
                    sentBytes: 0,
                    classification: .cellular
                )
            ]),
            repository: repository,
            systemBootTime: { currentBoot },
            continuousTime: { 3_600 },
            calendar: calendar
        ).measure(at: currentDate)

        XCTAssertEqual(result.cellularBytes, 900)
        XCTAssertEqual(result.quality, .partial)
        XCTAssertEqual(repository.dailyUsage().map(\.totalBytes), [900])
        XCTAssertTrue(calendar.isDate(repository.dailyUsage()[0].id, inSameDayAs: currentDate))
    }

    func testDailyAllocationUsesActualDSTDayDurationsAndPreservesTotal() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))

        let springStart = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 7)
        ))
        let springEnd = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 9)
        ))
        try repository.record(
            snapshot: InterfaceCounterSnapshot(measuredAt: springEnd, counters: []),
            sample: UsageSample(
                id: UUID(),
                from: springStart,
                to: springEnd,
                cellularBytes: 4_700,
                measurementQuality: .estimated
            ),
            bytes: 4_700,
            from: springStart,
            to: springEnd,
            calendar: calendar
        )

        XCTAssertEqual(repository.dailyUsage().map(\.totalBytes), [2_400, 2_300])
        XCTAssertEqual(repository.dailyUsage().reduce(0) { $0 + $1.totalBytes }, 4_700)
    }

    func testDailyAllocationHandlesDSTFallBackDay() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let start = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 31)
        ))
        let end = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 11, day: 2)
        ))

        try repository.record(
            snapshot: InterfaceCounterSnapshot(measuredAt: end, counters: []),
            sample: UsageSample(
                id: UUID(),
                from: start,
                to: end,
                cellularBytes: 4_900,
                measurementQuality: .estimated
            ),
            bytes: 4_900,
            from: start,
            to: end,
            calendar: calendar
        )

        XCTAssertEqual(repository.dailyUsage().map(\.totalBytes), [2_400, 2_500])
        XCTAssertEqual(repository.dailyUsage().reduce(0) { $0 + $1.totalBytes }, 4_900)
    }

    func testImplausibleShortIntervalSpikeIsQuarantinedAndRebaselined() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let bootTime = Date(timeIntervalSince1970: 100)
        let start = Date(timeIntervalSince1970: 1_000)

        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 0,
                    sentBytes: 0,
                    classification: .cellular
                )
            ],
            systemBootTime: bootTime
        ))

        let badCounter = NetworkInterfaceCounter(
            name: "pdp_ip0",
            receivedBytes: 20 * UInt64(DataBytes.gigabyte),
            sentBytes: 0,
            classification: .cellular
        )
        let quarantined = try UsageMeasurementService(
            reader: MockCounterReader(counters: [badCounter]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: start.addingTimeInterval(1))

        XCTAssertEqual(quarantined.cellularBytes, 0)
        XCTAssertEqual(quarantined.quality, .partial)
        XCTAssertTrue(repository.dailyUsage().isEmpty)

        let recovered = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: badCounter.receivedBytes + 1_000,
                    sentBytes: 0,
                    classification: .cellular
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: start.addingTimeInterval(2))

        XCTAssertEqual(recovered.cellularBytes, 1_000)
        XCTAssertEqual(recovered.quality, .verified)
    }

    func testLargeDeltaIsAcceptedAcrossPlausibleLongInterval() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let bootTime = Date(timeIntervalSince1970: 100)
        let start = Date(timeIntervalSince1970: 1_000)

        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 0,
                    sentBytes: 0,
                    classification: .cellular
                )
            ],
            systemBootTime: bootTime
        ))

        let result = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 20 * UInt64(DataBytes.gigabyte),
                    sentBytes: 0,
                    classification: .cellular
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: start.addingTimeInterval(60))

        XCTAssertEqual(result.cellularBytes, 20 * DataBytes.gigabyte)
        XCTAssertEqual(result.quality, .verified)
    }

    func testMissingCellularInterfacesDoNotEraseLastBaseline() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let bootTime = Date(timeIntervalSince1970: 100)
        let start = Date(timeIntervalSince1970: 1_000)
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 100,
                    sentBytes: 100,
                    classification: .cellular
                )
            ],
            systemBootTime: bootTime
        ))

        let unavailable = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "en0",
                    receivedBytes: 10_000,
                    sentBytes: 10_000,
                    classification: .wifi
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: start.addingTimeInterval(60))

        XCTAssertEqual(unavailable.quality, .unavailable)
        XCTAssertEqual(repository.latestSnapshot()?.measuredAt, start)

        let recovered = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 150,
                    sentBytes: 120,
                    classification: .cellular
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: start.addingTimeInterval(120))

        XCTAssertEqual(recovered.cellularBytes, 70)
        XCTAssertEqual(recovered.quality, .verified)
    }

    func testTemporarilyMissingCellularInterfaceDoesNotSpikeWhenItReturns() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let bootTime = Date(timeIntervalSince1970: 100)
        let start = Date(timeIntervalSince1970: 1_000)
        let largeBaseline = 10 * UInt64(DataBytes.gigabyte)
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 100,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 4
                ),
                NetworkInterfaceCounter(
                    name: "pdp_ip1",
                    receivedBytes: largeBaseline,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 5
                )
            ],
            systemBootTime: bootTime
        ))

        let partial = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 150,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 4
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: start.addingTimeInterval(60))

        XCTAssertEqual(partial.cellularBytes, 50)
        XCTAssertEqual(partial.quality, .partial)
        XCTAssertEqual(repository.latestSnapshot()?.counters.filter { $0.classification == .cellular }.count, 2)

        let returned = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 200,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 4
                ),
                NetworkInterfaceCounter(
                    name: "pdp_ip1",
                    receivedBytes: largeBaseline + 1_000,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 5
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: start.addingTimeInterval(120))

        XCTAssertEqual(returned.cellularBytes, 1_050)
        XCTAssertEqual(returned.quality, .partial)
    }

    func testReturningInterfaceUsesItsOwnLastObservedTimeAcrossMidnight() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 30, hour: 23)
        ))
        let middle = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 9, day: 30, hour: 23, minute: 30)
        ))
        let end = try XCTUnwrap(calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 1, hour: 1)
        ))
        let bootTime = start.addingTimeInterval(-86_400)
        let largeBaseline = 10 * UInt64(DataBytes.gigabyte)
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 100,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 4,
                    observedAt: start
                ),
                NetworkInterfaceCounter(
                    name: "pdp_ip1",
                    receivedBytes: largeBaseline,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 5,
                    observedAt: start
                )
            ],
            systemBootTime: bootTime
        ))

        _ = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 150,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 4
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime },
            calendar: calendar
        ).measure(at: middle)

        let returned = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 200,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 4
                ),
                NetworkInterfaceCounter(
                    name: "pdp_ip1",
                    receivedBytes: largeBaseline + 900,
                    sentBytes: 0,
                    classification: .cellular,
                    interfaceIndex: 5
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime },
            calendar: calendar
        ).measure(at: end)

        XCTAssertEqual(returned.cellularBytes, 950)
        XCTAssertEqual(returned.quality, .partial)
        XCTAssertEqual(repository.dailyUsage().map(\.totalBytes), [516, 484])
        XCTAssertEqual(repository.dailyUsage().reduce(0) { $0 + $1.totalBytes }, 1_000)
    }

    func testOutOfOrderReadingCannotMoveSnapshotBackwards() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let bootTime = Date(timeIntervalSince1970: 100)
        let start = Date(timeIntervalSince1970: 1_000)
        try repository.save(snapshot: InterfaceCounterSnapshot(
            measuredAt: start,
            counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 100,
                    sentBytes: 0,
                    classification: .cellular
                )
            ],
            systemBootTime: bootTime
        ))

        let stale = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 200,
                    sentBytes: 0,
                    classification: .cellular
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: start.addingTimeInterval(-10))

        XCTAssertEqual(stale.cellularBytes, 0)
        XCTAssertEqual(stale.quality, .partial)
        XCTAssertEqual(repository.latestSnapshot()?.measuredAt, start)

        let chronological = try UsageMeasurementService(
            reader: MockCounterReader(counters: [
                NetworkInterfaceCounter(
                    name: "pdp_ip0",
                    receivedBytes: 250,
                    sentBytes: 0,
                    classification: .cellular
                )
            ]),
            repository: repository,
            systemBootTime: { bootTime }
        ).measure(at: start.addingTimeInterval(10))

        XCTAssertEqual(chronological.cellularBytes, 150)
        XCTAssertEqual(repository.latestSnapshot()?.measuredAt, start.addingTimeInterval(10))
    }

    func testAtomicRecordIsIdempotentForSameInterval() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 1_060)
        let snapshot = InterfaceCounterSnapshot(measuredAt: end, counters: [])
        let sample = UsageSample(
            id: UUID(),
            from: start,
            to: end,
            cellularBytes: 500,
            measurementQuality: .verified
        )

        try repository.record(snapshot: snapshot, sample: sample, bytes: 500, from: start, to: end)
        try repository.record(snapshot: snapshot, sample: sample, bytes: 500, from: start, to: end)

        XCTAssertEqual(repository.samples().count, 1)
        XCTAssertEqual(repository.dailyUsage().first?.totalBytes, 500)
    }

    func testStaleAtomicRecordCannotDoubleCountSharedBaseline() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_000)
        let firstEnd = Date(timeIntervalSince1970: 1_060)
        let secondEnd = Date(timeIntervalSince1970: 1_061)
        try repository.save(snapshot: InterfaceCounterSnapshot(measuredAt: start, counters: []))

        let firstCommitted = try repository.record(
            snapshot: InterfaceCounterSnapshot(measuredAt: firstEnd, counters: []),
            sample: UsageSample(
                id: UUID(),
                from: start,
                to: firstEnd,
                cellularBytes: 500,
                measurementQuality: .verified
            ),
            bytes: 500,
            from: start,
            to: firstEnd,
            expectedPreviousMeasuredAt: start
        )
        let staleCommitted = try repository.record(
            snapshot: InterfaceCounterSnapshot(measuredAt: secondEnd, counters: []),
            sample: UsageSample(
                id: UUID(),
                from: start,
                to: secondEnd,
                cellularBytes: 700,
                measurementQuality: .verified
            ),
            bytes: 700,
            from: start,
            to: secondEnd,
            expectedPreviousMeasuredAt: start
        )

        XCTAssertTrue(firstCommitted)
        XCTAssertFalse(staleCommitted)
        XCTAssertEqual(repository.dailyUsage().first?.totalBytes, 500)
        XCTAssertEqual(repository.samples().count, 1)
        XCTAssertEqual(repository.latestSnapshot()?.measuredAt, firstEnd)
    }

    func testLegacyMeasurementMigrationRunsOnlyOnce() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacyUsage = [
            DailyUsage(
                id: Date(timeIntervalSince1970: 1),
                cellularBytes: 19_682_023_970,
                totalBytes: 19_682_023_970
            )
        ]
        defaults.set(try JSONEncoder().encode(legacyUsage), forKey: "dailyUsage")
        defaults.set(Data("plan-is-preserved".utf8), forKey: "planSettings")

        let migratedRepository = UsageRepository(defaults: defaults)
        XCTAssertTrue(migratedRepository.dailyUsage().isEmpty)
        XCTAssertEqual(defaults.data(forKey: "planSettings"), Data("plan-is-preserved".utf8))

        try migratedRepository.add(bytes: 512, at: Date(timeIntervalSince1970: 2))
        let reopenedRepository = UsageRepository(defaults: defaults)
        XCTAssertEqual(reopenedRepository.dailyUsage().first?.totalBytes, 512)
    }

    func testVersionTwoStateAndLegacyCounterPayloadMigrateWithoutDataLoss() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let measuredAt = Date(timeIntervalSince1970: 1_000)
        let legacySnapshot = LegacyInterfaceCounterSnapshotPayload(
            measuredAt: measuredAt,
            counters: [
                LegacyNetworkInterfaceCounterPayload(
                    name: "pdp_ip0",
                    receivedBytes: 4_500_000_000,
                    sentBytes: 500,
                    classification: .cellular
                )
            ],
            systemBootTime: Date(timeIntervalSince1970: 100)
        )
        let daily = [
            DailyUsage(
                id: measuredAt,
                cellularBytes: 123,
                totalBytes: 123
            )
        ]
        let samples = [
            UsageSample(
                id: UUID(),
                from: measuredAt.addingTimeInterval(-60),
                to: measuredAt,
                cellularBytes: 123,
                measurementQuality: .verified
            )
        ]
        defaults.set(2, forKey: "measurementSchemaVersion")
        defaults.set(try JSONEncoder().encode(legacySnapshot), forKey: "latestInterfaceSnapshot")
        defaults.set(try JSONEncoder().encode(samples), forKey: "usageSamples")
        defaults.set(try JSONEncoder().encode(daily), forKey: "dailyUsage")

        let repository = UsageRepository(defaults: defaults)
        let migratedCounter = try XCTUnwrap(repository.latestSnapshot()?.counters.first)

        XCTAssertEqual(migratedCounter.receivedBytes, 4_500_000_000)
        XCTAssertNil(migratedCounter.interfaceIndex)
        XCTAssertNil(migratedCounter.interfaceType)
        XCTAssertNil(migratedCounter.observedAt)
        XCTAssertEqual(repository.samples().first?.cellularBytes, 123)
        XCTAssertEqual(repository.dailyUsage().first?.totalBytes, 123)
        XCTAssertEqual(defaults.integer(forKey: "measurementSchemaVersion"), 3)
        XCTAssertNil(defaults.data(forKey: "latestInterfaceSnapshot"))
        XCTAssertNil(defaults.data(forKey: "usageSamples"))
        XCTAssertNil(defaults.data(forKey: "dailyUsage"))

        let reopenedRepository = UsageRepository(defaults: defaults)
        XCTAssertEqual(reopenedRepository.samples().first?.cellularBytes, 123)
        XCTAssertEqual(reopenedRepository.dailyUsage().first?.totalBytes, 123)
    }

    func testInterruptedVersionTwoMigrationKeepsAlreadyWrittenVersionThreeState() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstRepository = UsageRepository(defaults: defaults)
        let measuredAt = Date(timeIntervalSince1970: 1_000)
        try firstRepository.save(snapshot: InterfaceCounterSnapshot(measuredAt: measuredAt, counters: []))
        try firstRepository.add(bytes: 777, at: measuredAt)

        // Simulate termination after the new state was committed but before
        // the schema version marker was advanced.
        defaults.set(2, forKey: "measurementSchemaVersion")
        let recoveredRepository = UsageRepository(defaults: defaults)

        XCTAssertEqual(recoveredRepository.latestSnapshot()?.measuredAt, measuredAt)
        XCTAssertEqual(recoveredRepository.dailyUsage().first?.totalBytes, 777)
        XCTAssertEqual(defaults.integer(forKey: "measurementSchemaVersion"), 3)
    }

    func testCorruptVersionTwoPayloadIsPreservedForRecovery() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let corruptData = Data("not-json".utf8)
        defaults.set(2, forKey: "measurementSchemaVersion")
        defaults.set(corruptData, forKey: "dailyUsage")

        _ = UsageRepository(defaults: defaults)

        XCTAssertEqual(defaults.integer(forKey: "measurementSchemaVersion"), 2)
        XCTAssertEqual(defaults.data(forKey: "dailyUsage"), corruptData)
        XCTAssertNil(defaults.data(forKey: "measurementState"))
    }

    func testCorruptVersionThreeStateIsNotOverwrittenByMutation() throws {
        let suiteName = "UsageMeasurementServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = UsageRepository(defaults: defaults)
        let corruptData = Data("not-json".utf8)
        defaults.set(corruptData, forKey: "measurementState")

        XCTAssertThrowsError(try repository.add(bytes: 123, at: .now))
        XCTAssertEqual(defaults.data(forKey: "measurementState"), corruptData)
    }
}

private struct MockCounterReader: NetworkCounterReading {
    let counters: [NetworkInterfaceCounter]
    func readCounters() throws -> [NetworkInterfaceCounter] { counters }
}

private struct LegacyInterfaceCounterSnapshotPayload: Encodable {
    let measuredAt: Date
    let counters: [LegacyNetworkInterfaceCounterPayload]
    let systemBootTime: Date?
}

private struct LegacyNetworkInterfaceCounterPayload: Encodable {
    let name: String
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let classification: InterfaceClassification
}
