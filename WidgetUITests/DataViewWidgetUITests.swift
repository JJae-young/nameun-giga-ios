import XCTest

final class DataViewWidgetUITests: XCTestCase {
    private struct RefreshToken {
        let generatedAt: TimeInterval
        let usedBytes: Int64
        let periodStart: TimeInterval
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testRefreshButtonKeepsHomeScreenInForeground() throws {
        let dataView = XCUIApplication(bundleIdentifier: "com.edward.DataView")
        let springBoard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        switch dataView.state {
        case .runningForeground, .runningBackground, .runningBackgroundSuspended:
            dataView.terminate()
        default:
            break
        }

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(
            springBoard.wait(for: .runningForeground, timeout: 5),
            "SpringBoard 홈 화면으로 이동하지 못했습니다."
        )

        let identifiedButton = springBoard.buttons["data-usage-refresh"]
        let labeledButton = springBoard.buttons
            .matching(
                NSPredicate(
                    format: "label BEGINSWITH %@",
                    "데이터 사용량 새로고침"
                )
            )
            .firstMatch
        let refreshButton: XCUIElement
        if identifiedButton.waitForExistence(timeout: 3) {
            refreshButton = identifiedButton
        } else {
            refreshButton = labeledButton
        }

        XCTAssertTrue(
            refreshButton.waitForExistence(timeout: 5),
            "홈 화면 첫 페이지에 DataView 소형 또는 중형 위젯이 필요합니다."
        )
        XCTAssertTrue(refreshButton.isHittable)

        let beforeToken = try XCTUnwrap(
            Self.refreshToken(from: refreshButton.value),
            "새로고침 전 위젯 상태 토큰을 읽지 못했습니다."
        )

        refreshButton.tap()

        let deadline = Date().addingTimeInterval(15)
        var afterToken: RefreshToken?
        repeat {
            let currentButton = springBoard.buttons["data-usage-refresh"].exists
                ? springBoard.buttons["data-usage-refresh"]
                : springBoard.buttons
                    .matching(
                        NSPredicate(
                            format: "label BEGINSWITH %@",
                            "데이터 사용량 새로고침"
                        )
                    )
                    .firstMatch
            if currentButton.exists,
               let token = Self.refreshToken(from: currentButton.value),
               token.generatedAt > beforeToken.generatedAt {
                afterToken = token
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        } while Date() < deadline

        let refreshedToken = try XCTUnwrap(
            afterToken,
            "버튼을 눌렀지만 위젯의 실제 갱신 시각이 바뀌지 않았습니다."
        )
        if refreshedToken.periodStart == beforeToken.periodStart {
            XCTAssertGreaterThanOrEqual(
                refreshedToken.usedBytes,
                beforeToken.usedBytes,
                "같은 요금 주기 안에서 누적 사용량이 감소했습니다."
            )
        }

        XCTAssertFalse(
            dataView.wait(for: .runningForeground, timeout: 3),
            "새로고침 버튼이 DataView 앱 화면을 열었습니다."
        )
        XCTAssertEqual(
            springBoard.state,
            .runningForeground,
            "새로고침 후에도 홈 화면이 유지되어야 합니다."
        )
    }

    private static func refreshToken(from value: Any?) -> RefreshToken? {
        guard let rawValue = value as? String else { return nil }
        let fields = rawValue.split(separator: ";").reduce(into: [String: String]()) { result, pair in
            let components = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard components.count == 2 else { return }
            result[components[0]] = components[1]
        }
        guard let generatedAtText = fields["generatedAt"],
              let generatedAt = TimeInterval(generatedAtText),
              let usedBytesText = fields["usedBytes"],
              let usedBytes = Int64(usedBytesText),
              let periodStartText = fields["periodStart"],
              let periodStart = TimeInterval(periodStartText) else {
            return nil
        }
        return RefreshToken(
            generatedAt: generatedAt,
            usedBytes: usedBytes,
            periodStart: periodStart
        )
    }
}
