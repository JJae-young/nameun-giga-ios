import XCTest

final class CellularReleaseUITests: XCTestCase {
    @MainActor
    func testCellularOnlyScreensAndUnchangedPlanSave() throws {
        #if targetEnvironment(simulator)
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()

        if app.buttons["건너뛰기"].waitForExistence(timeout: 3) {
            app.buttons["건너뛰기"].tap()
        }
        let start = app.buttons["남은기가 시작하기"]
        if start.waitForExistence(timeout: 3) {
            let limit = app.textFields["월 데이터 용량"]
            XCTAssertTrue(limit.waitForExistence(timeout: 3))
            limit.tap()
            limit.typeText("160")
            // Leave carrier usage blank: setup must not create a calibration.
            reveal(start, in: app)
            XCTAssertTrue(start.isEnabled)
            start.tap()
        }

        // iPad can expose its tabs outside the TabBar accessibility type.
        let home = app.buttons["홈"].firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        home.tap()
        XCTAssertTrue(app.navigationBars["남은기가"].waitForExistence(timeout: 3))
        capture(app, named: "cellular-release-dashboard")
        checkScrolledScreen(app)

        let settings = app.buttons["설정"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        settings.tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 3))
        capture(app, named: "cellular-release-settings")
        checkScrolledScreen(app)

        let planButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "요금제 설정")
        ).firstMatch
        XCTAssertTrue(planButton.waitForExistence(timeout: 3))
        let originalPlanLabel = planButton.label
        planButton.tap()
        let planNavigation = app.navigationBars["요금제 설정"]
        XCTAssertTrue(planNavigation.waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["현재 통신사 표시 사용량"].exists)
        capture(app, named: "cellular-release-plan")
        assertNoHotspotControls(app)

        let unlimited = app.switches["무제한 요금제"]
        XCTAssertTrue(unlimited.waitForExistence(timeout: 3))
        let originalUnlimitedValue = try XCTUnwrap(unlimited.value as? String)
        unlimited.tap()
        // Regular plan editing uses sheet dismissal to cancel its local draft.
        planNavigation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)
            ))
        waitForDismissal(planNavigation)
        XCTAssertEqual(planButton.label, originalPlanLabel)

        planButton.tap()
        XCTAssertTrue(planNavigation.waitForExistence(timeout: 3))
        XCTAssertEqual(unlimited.value as? String, originalUnlimitedValue)
        let save = app.buttons["설정 저장"]
        reveal(save, in: app)
        XCTAssertTrue(save.isEnabled)
        assertNoHotspotControls(app)
        // Save the original plan without changing its limit, reset day, alerts,
        // or carrier adjustment. Existing measured usage remains untouched.
        save.tap()
        waitForDismissal(planNavigation)
        XCTAssertEqual(planButton.label, originalPlanLabel)

        let measurement = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "측정 상태")
        ).firstMatch
        reveal(measurement, in: app)
        measurement.tap()
        XCTAssertTrue(app.navigationBars["측정 상태"].waitForExistence(timeout: 3))
        assertNoHotspotControls(app)
        XCTAssertTrue(app.staticTexts["셀룰러"].exists)
        #else
        throw XCTSkip("Simulator-only smoke test; never changes a physical device's plan.")
        #endif
    }

    @MainActor
    private func assertNoHotspotControls(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let removedControls = app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR label CONTAINS[c] %@ OR identifier CONTAINS[c] %@",
            "핫스팟", "테더링", "hotspot", "hotspot"
        ))
        XCTAssertFalse(removedControls.firstMatch.exists, "핫스팟 UI가 남아 있습니다.", file: file, line: line)
    }

    @MainActor
    private func checkScrolledScreen(_ app: XCUIApplication) {
        assertNoHotspotControls(app)
        for _ in 0..<4 {
            app.swipeUp()
            assertNoHotspotControls(app)
        }
        for _ in 0..<4 { app.swipeDown() }
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "필요한 화면 요소를 찾지 못했습니다: \(element)")
    }

    @MainActor
    private func waitForDismissal(_ element: XCUIElement) {
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        wait(for: [dismissed], timeout: 5)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
