import Foundation

struct SettingsRepository {
    private enum Key {
        static let plan = "planSettings"
        static let onboarding = "hasCompletedOnboarding"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Key.onboarding)
    }

    func setOnboardingCompleted() {
        defaults.set(true, forKey: Key.onboarding)
    }

    func loadPlan() -> PlanSettings? {
        guard let data = defaults.data(forKey: Key.plan) else { return nil }
        return try? JSONDecoder().decode(PlanSettings.self, from: data)
    }

    /// Pins legacy plans to a billing timezone exactly once. Subsequent device
    /// timezone changes (for example while roaming) cannot move reset dates or
    /// invalidate the carrier calibration.
    func loadPlanWithStableBillingTimeZone(
        fallback timeZone: TimeZone = .current
    ) -> PlanSettings? {
        guard var plan = loadPlan() else { return nil }
        guard plan.billingTimeZoneIdentifier == nil else { return plan }
        plan.billingTimeZoneIdentifier = timeZone.identifier
        plan.updatedAt = .now
        try? save(plan: plan)
        return plan
    }

    func save(plan: PlanSettings) throws {
        do {
            defaults.set(try JSONEncoder().encode(plan), forKey: Key.plan)
        } catch {
            throw MeasurementError.storageFailed
        }
    }
}
