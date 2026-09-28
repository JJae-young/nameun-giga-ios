import Foundation
import UserNotifications

@MainActor
protocol UsageNotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
}

@MainActor
private struct SystemUsageNotificationCenter: UsageNotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }
}

@MainActor
final class UsageNotificationService {
    private let center: any UsageNotificationScheduling
    private let defaults: UserDefaults
    private var inFlightKeys: Set<String> = []

    init(
        center: (any UsageNotificationScheduling)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.center = center ?? SystemUsageNotificationCenter()
        self.defaults = defaults
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization()) ?? false
    }

    func evaluate(summary: WidgetSummary, plan: PlanSettings) async {
        guard !plan.isUnlimited, let usagePercent = summary.usagePercent else { return }
        let thresholds: [(Int, Bool)] = [
            (50, plan.alert50),
            (80, plan.alert80),
            (90, plan.alert90)
        ]
        guard thresholds.contains(where: { $0.1 && usagePercent >= Double($0.0) / 100 }) else {
            return
        }

        let status = await center.authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            return
        }

        for (threshold, enabled) in thresholds where enabled && usagePercent >= Double(threshold) / 100 {
            let key = notificationKey(threshold: threshold, periodStart: summary.periodStart)
            guard !defaults.bool(forKey: key), !inFlightKeys.contains(key) else { continue }
            inFlightKeys.insert(key)

            let content = UNMutableNotificationContent()
            content.title = "데이터 사용량 \(threshold)% 도달"
            content.body = "이번 주기에 \(DataAmountFormatter.string(from: summary.usedBytes))를 사용했어요."
            content.sound = .default
            let request = UNNotificationRequest(identifier: key, content: content, trigger: nil)
            do {
                try await center.add(request)
                // A denied permission or a transient scheduling failure must
                // never consume this period's only opportunity to alert.
                defaults.set(true, forKey: key)
            } catch {
                // Retry at the next measurement after a scheduling failure.
            }
            inFlightKeys.remove(key)
        }
    }

    private func notificationKey(threshold: Int, periodStart: Date) -> String {
        let value = Int(periodStart.timeIntervalSince1970)
        return "usageAlert.\(value).\(threshold)"
    }

}
