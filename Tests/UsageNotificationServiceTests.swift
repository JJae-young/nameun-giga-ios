import UserNotifications
import XCTest
@testable import DataView

@MainActor
final class UsageNotificationServiceTests: XCTestCase {
    func testPermissionPendingDoesNotConsumeThresholdAndGrantAllowsAlert() async throws {
        let suiteName = "UsageNotificationServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let center = MockUsageNotificationCenter(status: .notDetermined)
        let service = UsageNotificationService(center: center, defaults: defaults)

        await service.evaluate(summary: summary(), plan: plan())
        XCTAssertTrue(center.attemptedRequests.isEmpty)

        let granted = await service.requestAuthorization()
        XCTAssertTrue(granted)
        await service.evaluate(summary: summary(), plan: plan())
        await service.evaluate(summary: summary(), plan: plan())

        XCTAssertEqual(center.attemptedRequests.count, 1)
        XCTAssertEqual(center.deliveredRequests.count, 1)
    }

    func testFailedSchedulingRetriesWithoutLosingCycleAlert() async throws {
        let suiteName = "UsageNotificationServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let center = MockUsageNotificationCenter(status: .authorized)
        center.failuresRemaining = 1
        let service = UsageNotificationService(center: center, defaults: defaults)

        await service.evaluate(summary: summary(), plan: plan())
        XCTAssertTrue(center.deliveredRequests.isEmpty)
        await service.evaluate(summary: summary(), plan: plan())
        await service.evaluate(summary: summary(), plan: plan())

        XCTAssertEqual(center.attemptedRequests.count, 2)
        XCTAssertEqual(center.deliveredRequests.count, 1)
    }

    func testConcurrentEvaluationSchedulesEachThresholdOnlyOnce() async throws {
        let suiteName = "UsageNotificationServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let center = MockUsageNotificationCenter(status: .authorized)
        let service = UsageNotificationService(center: center, defaults: defaults)
        let currentSummary = summary()
        let currentPlan = plan()

        async let first: Void = service.evaluate(summary: currentSummary, plan: currentPlan)
        async let second: Void = service.evaluate(summary: currentSummary, plan: currentPlan)
        _ = await (first, second)

        XCTAssertEqual(center.deliveredRequests.count, 1)
    }

    func testDeniedPermissionAndUnlimitedPlanDoNotScheduleAlerts() async throws {
        let suiteName = "UsageNotificationServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let center = MockUsageNotificationCenter(status: .denied)
        let service = UsageNotificationService(center: center, defaults: defaults)
        await service.evaluate(summary: summary(), plan: plan())
        center.status = .authorized
        var unlimited = plan()
        unlimited.isUnlimited = true
        await service.evaluate(summary: summary(), plan: unlimited)

        XCTAssertTrue(center.attemptedRequests.isEmpty)
    }

    private func plan() -> PlanSettings {
        var value = PlanSettings.standard
        value.alert50 = true
        value.alert80 = false
        value.alert90 = false
        return value
    }

    private func summary() -> WidgetSummary {
        WidgetSummary(
            generatedAt: Date(timeIntervalSince1970: 1_780_000_000),
            periodStart: Date(timeIntervalSince1970: 1_779_000_000),
            periodEnd: Date(timeIntervalSince1970: 1_782_000_000),
            usedBytes: 60 * DataBytes.gigabyte,
            limitBytes: 100 * DataBytes.gigabyte,
            remainingBytes: 40 * DataBytes.gigabyte,
            usagePercent: 0.6,
            iPhoneBytes: 60 * DataBytes.gigabyte,
            todayBytes: DataBytes.gigabyte
        )
    }
}

@MainActor
private final class MockUsageNotificationCenter: UsageNotificationScheduling {
    enum SchedulingError: Error { case failed }

    var status: UNAuthorizationStatus
    var failuresRemaining = 0
    var attemptedRequests: [UNNotificationRequest] = []
    var deliveredRequests: [UNNotificationRequest] = []

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() async -> UNAuthorizationStatus { status }

    func requestAuthorization() async throws -> Bool {
        if status == .notDetermined { status = .authorized }
        return status == .authorized
    }

    func add(_ request: UNNotificationRequest) async throws {
        attemptedRequests.append(request)
        await Task.yield()
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw SchedulingError.failed
        }
        deliveredRequests.append(request)
    }
}
