import XCTest

final class CarrierUsageSyncUITests: XCTestCase {
    @MainActor
    func testCarrierFormValidatesRemainingAndShowsSaveFailure() throws {
        #if targetEnvironment(simulator)
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()

        if app.buttons["건너뛰기"].waitForExistence(timeout: 3) {
            app.buttons["건너뛰기"].tap()
            let limit = app.textFields["월 데이터 용량"]
            XCTAssertTrue(limit.waitForExistence(timeout: 3))
            limit.tap()
            limit.typeText("160")
            let start = app.buttons["DataView 시작하기"]
            app.swipeUp()
            XCTAssertTrue(start.isEnabled)
            start.tap()
        }

        // iPad exposes its top tab strip outside the TabBar accessibility type.
        let settings = app.buttons["설정"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "통신사 값 맞추기")).firstMatch.tap()
        let input = app.textFields["carrier-amount-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        let save = app.navigationBars.buttons["저장"]
        XCTAssertFalse(save.isEnabled, "앱의 추정값을 통신사 값으로 무심코 재저장하면 안 됩니다.")

        app.segmentedControls.buttons["남은 데이터"].tap()
        input.tap()
        input.typeText("161")
        XCTAssertFalse(save.isEnabled)
        XCTAssertTrue(app.staticTexts["남은 데이터가 요금제 용량보다 큽니다. 같은 데이터 항목의 잔여량인지 확인해 주세요."].exists)
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "63.68")
        XCTAssertEqual(input.value as? String, "63.68")
        // SwiftUI may expose LabeledContent as a combined accessibility label.
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "96.32 GB")
        ).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(save.isEnabled)

        let usedButton = app.segmentedControls.buttons["사용량"]
        usedButton.tap()
        // On iPad the first tap can be consumed by keyboard dismissal.
        if !usedButton.isSelected { usedButton.tap() }
        XCTAssertTrue(usedButton.isSelected)
        let usedMode = XCTAttachment(screenshot: app.screenshot())
        usedMode.name = "carrier-sync-used-mode"
        usedMode.lifetime = .keepAlways
        add(usedMode)
        let disabled = expectation(for: NSPredicate(format: "enabled == false"), evaluatedWith: save)
        wait(for: [disabled], timeout: 3)
        let remainingButton = app.segmentedControls.buttons["남은 데이터"]
        remainingButton.tap()
        if !remainingButton.isSelected { remainingButton.tap() }
        XCTAssertTrue(remainingButton.isSelected)
        XCTAssertEqual(input.value as? String, "63.68")

        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "carrier-sync-preview"
        preview.lifetime = .keepAlways
        add(preview)
        save.tap()
        // Simulator has no usable cellular interface. The failure should be
        // visible inside the sheet, without dismissing it or losing input.
        XCTAssertTrue(app.staticTexts["carrier-save-error"].waitForExistence(timeout: 3))
        XCTAssertEqual(input.value as? String, "63.68")
        let failure = XCTAttachment(screenshot: app.screenshot())
        failure.name = "carrier-sync-error"
        failure.lifetime = .keepAlways
        add(failure)
        #else
        throw XCTSkip("Local simulator-only test; never installs to a physical device.")
        #endif
    }
}
