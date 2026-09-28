import Foundation

enum UsageHistorySummary {
    static func total(_ values: [DailyUsage], in interval: DateInterval) -> Int64 {
        // Billing and chart intervals are half-open: a boundary belongs only
        // to the next day/week/month, never both adjacent buckets.
        values.lazy
            .filter { $0.id >= interval.start && $0.id < interval.end }
            .reduce(Int64(0)) { partial, value in
                let (sum, overflow) = partial.addingReportingOverflow(max(0, value.totalBytes))
                return overflow ? Int64.max : sum
            }
    }
}
