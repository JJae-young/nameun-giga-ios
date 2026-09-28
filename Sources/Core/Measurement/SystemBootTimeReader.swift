import Darwin
import Foundation

enum SystemBootTimeReader {
    /// Reads the kernel's wall-clock boot epoch for interval allocation. The
    /// kernel adjusts this value when wall time changes, so it cannot by itself
    /// prove that the device restarted.
    static func read() -> Date? {
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.size

        guard sysctlbyname("kern.boottime", &bootTime, &size, nil, 0) == 0,
              size >= MemoryLayout<timeval>.size else {
            return nil
        }

        let seconds = TimeInterval(bootTime.tv_sec)
        let microseconds = TimeInterval(bootTime.tv_usec) / 1_000_000
        return Date(timeIntervalSince1970: seconds + microseconds)
    }

    static func continuousTime() -> TimeInterval? {
        var value = timespec()
        guard clock_gettime(CLOCK_MONOTONIC_RAW, &value) == 0 else { return nil }
        return TimeInterval(value.tv_sec) + TimeInterval(value.tv_nsec) / 1_000_000_000
    }
}
