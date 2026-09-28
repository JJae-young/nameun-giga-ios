import SwiftUI
import UIKit
import XCTest
@testable import DataView

@MainActor
final class RemainingAmountLayoutTests: XCTestCase {
    func testRemainingAmountsInPhoneAndTabletLayouts() async throws {
        let suiteName = "RemainingAmountLayoutTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsRepository(defaults: defaults)
        var plan = PlanSettings.standard
        plan.alert50 = false
        plan.alert80 = false
        plan.alert90 = false
        plan.manualAdjustmentBytes = 107_300_000_000
        plan.hotspot = HotspotPlanSettings(
            limitBytes: 50 * DataBytes.gigabyte, alert80: false, alert90: false,
            manualAdjustmentBytes: 28_600_000_000
        )
        try settings.save(plan: plan)
        let model = AppModel(
            settingsRepository: settings,
            usageRepository: UsageRepository(defaults: defaults)
        )
        XCTAssertEqual(model.summary.remainingBytes, 52_700_000_000)
        XCTAssertEqual(model.summary.hotspotRemainingBytes, 21_400_000_000)

        for (name, size) in [
            ("remaining-phone", CGSize(width: 375, height: 812)),
            ("remaining-tablet", CGSize(width: 834, height: 1194))
        ] {
            try await capture(
                DashboardView().environmentObject(model),
                name: name, size: size
            )
        }
        try await capture(
            HotspotUsageCard(onSync: {}).environmentObject(model).padding(16),
            name: "remaining-hotspot-phone", size: CGSize(width: 375, height: 370)
        )
    }

    private func capture<Content: View>(
        _ content: Content,
        name: String,
        size: CGSize
    ) async throws {
        let host = UIHostingController(rootView: content
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .environment(\.colorScheme, .light)
            .frame(width: size.width, height: size.height))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(350))
        host.view.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            XCTAssertTrue(host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
