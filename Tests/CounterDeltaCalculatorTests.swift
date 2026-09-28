import XCTest
@testable import DataView

final class CounterDeltaCalculatorTests: XCTestCase {
    func testNormalDelta() {
        let result = CounterDeltaCalculator.calculate(previous: 1_000, current: 1_600)
        XCTAssertEqual(result, CounterDeltaResult(bytes: 600, quality: .verified))
    }

    func testResetCountsRecoverableCurrentValueAsPartial() {
        let result = CounterDeltaCalculator.calculate(previous: 1_000, current: 100)
        XCTAssertEqual(result, CounterDeltaResult(bytes: 100, quality: .partial))
    }

    func testSameCounterIsZero() {
        let result = CounterDeltaCalculator.calculate(previous: 1_000, current: 1_000)
        XCTAssertEqual(result.bytes, 0)
    }

    func testUInt64ToInt64ClampsOverflow() {
        XCTAssertEqual(CounterDeltaCalculator.clampedInt64(UInt64.max), Int64.max)
    }
}
