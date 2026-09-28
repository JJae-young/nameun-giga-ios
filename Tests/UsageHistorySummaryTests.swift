import XCTest
@testable import DataView

final class UsageHistorySummaryTests: XCTestCase {
    func testAdjacentPeriodsDoNotBothIncludeBoundaryUsage() {
        let boundary = Date(timeIntervalSince1970: 10_000)
        let history = [DailyUsage(id: boundary, cellularBytes: 500, totalBytes: 500)]
        let previous = DateInterval(start: boundary.addingTimeInterval(-1_000), end: boundary)
        let next = DateInterval(start: boundary, end: boundary.addingTimeInterval(1_000))
        XCTAssertEqual(UsageHistorySummary.total(history, in: previous), 0)
        XCTAssertEqual(UsageHistorySummary.total(history, in: next), 500)
    }

    func testCorruptExtremeHistoryCannotOverflowChartTotal() {
        let date = Date(timeIntervalSince1970: 10_000)
        let history = [
            DailyUsage(id: date, cellularBytes: Int64.max, totalBytes: Int64.max),
            DailyUsage(id: date, cellularBytes: 1, totalBytes: 1)
        ]
        XCTAssertEqual(UsageHistorySummary.total(history, in: DateInterval(start: date, duration: 1)), Int64.max)
    }
}
