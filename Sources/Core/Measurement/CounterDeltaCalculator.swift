import Foundation

struct CounterDeltaResult: Equatable {
    let bytes: UInt64
    let quality: MeasurementQuality
}

enum CounterDeltaCalculator {
    static func calculate(previous: UInt64, current: UInt64) -> CounterDeltaResult {
        if current >= previous {
            return CounterDeltaResult(bytes: current - previous, quality: .verified)
        }
        // A reboot or interface recreation resets the cumulative counter.
        // The current value was accumulated after that reset, so it is the
        // recoverable lower bound. Traffic between the prior sample and the
        // reset remains unknowable, hence the partial quality.
        return CounterDeltaResult(bytes: current, quality: .partial)
    }

    static func clampedInt64(_ value: UInt64) -> Int64 {
        value > UInt64(Int64.max) ? Int64.max : Int64(value)
    }
}
