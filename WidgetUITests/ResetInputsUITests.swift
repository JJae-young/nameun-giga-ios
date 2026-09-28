import XCTest

final class ResetInputsUITests: XCTestCase {
    @MainActor
    func testResetCanBeCancelledAndFailedSaveKeepsDraft() throws {
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
            app.swipeUp()
            app.buttons["남은기가 시작하기"].tap()
        }
        let settings = app.buttons["설정"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        let reset = app.buttons["reset-inputs-button"]
        XCTAssertTrue(reset.waitForExistence(timeout: 3))
        let oldPlanLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "요금제 설정")).firstMatch.label
        reset.tap()
        app.alerts.buttons["취소"].tap()
        XCTAssertFalse(app.navigationBars["입력값 다시 설정"].exists)

        reset.tap()
        app.alerts.buttons["다시 설정"].tap()
        let limit = app.textFields["월 데이터 용량"]
        XCTAssertTrue(limit.waitForExistence(timeout: 3))
        let save = app.navigationBars.buttons["저장"]
        XCTAssertFalse(save.isEnabled)
        limit.tap()
        limit.typeText("100")
        XCTAssertFalse(save.isEnabled, "Reset requires an explicit starting usage, including zero.")
        app.navigationBars.buttons["취소"].tap()
        XCTAssertTrue(reset.waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "요금제 설정")).firstMatch.label, oldPlanLabel)

        reset.tap()
        app.alerts.buttons["다시 설정"].tap()
        XCTAssertTrue(limit.waitForExistence(timeout: 3))
        XCTAssertEqual(limit.value as? String, "160", "Placeholder should be shown, not the discarded 100 GB draft.")
        let form = XCTAttachment(screenshot: app.screenshot())
        form.name = "reset-inputs-form"
        form.lifetime = .keepAlways
        add(form)
        limit.tap()
        limit.typeText("100")
        let used = app.textFields["현재 통신사 표시 사용량"]
        if !used.isHittable { app.swipeUp() }
        used.tap()
        used.typeText("0")
        XCTAssertTrue(save.isEnabled)
        save.tap()
        if app.keyboards.firstMatch.exists { save.tap() }
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["plan-save-error"].waitForExistence(timeout: 5))
        XCTAssertEqual(limit.value as? String, "100")
        XCTAssertEqual(used.value as? String, "0")
        let failure = XCTAttachment(screenshot: app.screenshot())
        failure.name = "reset-inputs-save-error"
        failure.lifetime = .keepAlways
        add(failure)
        app.navigationBars.buttons["취소"].tap()
        XCTAssertTrue(reset.waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "요금제 설정")).firstMatch.label, oldPlanLabel)
        #else
        throw XCTSkip("Simulator-only test; never modifies physical-device settings.")
        #endif
    }
}
