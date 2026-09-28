import Foundation

struct UsageIntervalAllocation: Equatable {
    let bytes: Int64
    let from: Date
    let to: Date
}

struct UsageRepository {
    private enum Key {
        static let state = "measurementState"
        static let legacySnapshot = "latestInterfaceSnapshot"
        static let legacySamples = "usageSamples"
        static let legacyDaily = "dailyUsage"
        static let measurementSchemaVersion = "measurementSchemaVersion"
    }

    private struct MeasurementState: Codable {
        var snapshot: InterfaceCounterSnapshot?
        var samples: [UsageSample]
        var daily: [DailyUsage]

        static let empty = MeasurementState(snapshot: nil, samples: [], daily: [])
    }

    private static let currentMeasurementSchemaVersion = 3
    private static let lock = NSLock()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateMeasurementDataIfNeeded()
    }

    func latestSnapshot() -> InterfaceCounterSnapshot? {
        withLock { loadState().snapshot }
    }

    func save(snapshot: InterfaceCounterSnapshot) throws {
        try withLock {
            var state = try loadStateForMutation()
            state.snapshot = snapshot
            try save(state)
        }
    }

    /// Initial baselines participate in the same compare-and-swap protection
    /// as later samples. A concurrent first refresh cannot replace a baseline
    /// that has already been used to record usage.
    func initialize(snapshot: InterfaceCounterSnapshot) throws -> Bool {
        try withLock {
            var state = try loadStateForMutation()
            guard state.snapshot == nil else { return false }
            state.snapshot = snapshot
            try save(state)
            return true
        }
    }

    func samples() -> [UsageSample] {
        withLock { loadState().samples }
    }

    func append(sample: UsageSample) throws {
        try withLock {
            var state = try loadStateForMutation()
            append(sample, to: &state)
            try save(state)
        }
    }

    func dailyUsage() -> [DailyUsage] {
        withLock { loadState().daily }
    }

    func add(bytes: Int64, at date: Date, calendar: Calendar = .current) throws {
        try withLock {
            var state = try loadStateForMutation()
            add(bytes: bytes, on: date, to: &state.daily, calendar: calendar)
            trimDaily(&state.daily)
            try save(state)
        }
    }

    /// Commits a measurement as one encoded value. Keeping the next snapshot,
    /// interval sample, and derived daily buckets together prevents an app
    /// suspension between separate writes from either losing or double-counting
    /// a counter delta.
    @discardableResult
    func record(
        snapshot: InterfaceCounterSnapshot,
        sample: UsageSample,
        bytes: Int64,
        from start: Date,
        to end: Date,
        calendar: Calendar = .current,
        expectedPreviousMeasuredAt: Date? = nil,
        allocations: [UsageIntervalAllocation]? = nil
    ) throws -> Bool {
        try withLock {
            var state = try loadStateForMutation()

            // A repeated intent invocation for the exact same interval should
            // be idempotent even if it reaches this repository twice.
            if state.snapshot?.measuredAt == snapshot.measuredAt,
               state.samples.contains(where: { $0.from == sample.from && $0.to == sample.to }) {
                return true
            }

            // Compare-and-swap the baseline. Two refresh paths may read the
            // same snapshot before either commits; only the first may add that
            // delta. The loser leaves its bytes for the next counter reading.
            if let expectedPreviousMeasuredAt,
               state.snapshot?.measuredAt != expectedPreviousMeasuredAt {
                return false
            }

            append(sample, to: &state)
            if let allocations {
                for allocation in allocations {
                    add(
                        bytes: allocation.bytes,
                        from: allocation.from,
                        to: allocation.to,
                        to: &state.daily,
                        calendar: calendar
                    )
                }
            } else {
                add(bytes: bytes, from: start, to: end, to: &state.daily, calendar: calendar)
            }
            trimDaily(&state.daily)
            state.snapshot = snapshot
            try save(state)
            return true
        }
    }

    private func append(_ sample: UsageSample, to state: inout MeasurementState) {
        state.samples.append(sample)
        if state.samples.count > 2_000 {
            state.samples.removeFirst(state.samples.count - 2_000)
        }
    }

    private func add(
        bytes: Int64,
        from start: Date,
        to end: Date,
        to values: inout [DailyUsage],
        calendar: Calendar
    ) {
        guard bytes > 0 else { return }

        let totalDuration = end.timeIntervalSince(start)
        guard totalDuration > 0, totalDuration.isFinite else {
            add(bytes: bytes, on: end, to: &values, calendar: calendar)
            return
        }

        var cursor = start
        var remainingBytes = bytes

        while cursor < end, remainingBytes > 0 {
            let day = calendar.startOfDay(for: cursor)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
                  nextDay > cursor else {
                add(bytes: remainingBytes, on: end, to: &values, calendar: calendar)
                break
            }

            let segmentEnd = min(end, nextDay)
            let isLastSegment = segmentEnd >= end
            let allocation: Int64
            if isLastSegment {
                allocation = remainingBytes
            } else {
                let ratio = segmentEnd.timeIntervalSince(cursor) / totalDuration
                let proportional = Int64((Double(bytes) * ratio).rounded(.down))
                allocation = min(remainingBytes, max(0, proportional))
            }

            add(bytes: allocation, on: cursor, to: &values, calendar: calendar)
            remainingBytes -= allocation
            cursor = segmentEnd
        }
    }

    private func add(
        bytes: Int64,
        on date: Date,
        to values: inout [DailyUsage],
        calendar: Calendar
    ) {
        guard bytes > 0 else { return }
        let day = calendar.startOfDay(for: date)
        if let index = values.firstIndex(where: { calendar.isDate($0.id, inSameDayAs: day) }) {
            values[index].cellularBytes = safeAdd(values[index].cellularBytes, bytes)
            values[index].totalBytes = safeAdd(values[index].totalBytes, bytes)
        } else {
            values.append(DailyUsage(id: day, cellularBytes: bytes, totalBytes: bytes))
        }
    }

    private func trimDaily(_ values: inout [DailyUsage]) {
        values.sort { $0.id < $1.id }
        if values.count > 400 {
            values.removeFirst(values.count - 400)
        }
    }

    private func safeAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : sum
    }

    private func migrateMeasurementDataIfNeeded() {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        let version = defaults.integer(forKey: Key.measurementSchemaVersion)
        guard version < Self.currentMeasurementSchemaVersion else {
            removeLegacyValues()
            return
        }

        if version < 2 {
            // Version 1 interpreted getifaddrs' 32-bit if_data payload as
            // if_data64. Those values are not network bytes and cannot be
            // corrected after the fact, so discard measurement history only.
            defaults.removeObject(forKey: Key.state)
            removeLegacyValues()
            defaults.set(Self.currentMeasurementSchemaVersion, forKey: Key.measurementSchemaVersion)
        } else {
            // Version 2 stored the three related values separately. Move them
            // into one state payload without changing the measured totals. If
            // a prior migration wrote the state but was interrupted before it
            // advanced the version marker, keep that already-valid state.
            if decode(MeasurementState.self, key: Key.state) == nil {
                let legacySnapshot: InterfaceCounterSnapshot?
                if let data = defaults.data(forKey: Key.legacySnapshot) {
                    guard let value = try? decoder.decode(InterfaceCounterSnapshot.self, from: data) else {
                        return
                    }
                    legacySnapshot = value
                } else {
                    legacySnapshot = nil
                }

                let legacySamples: [UsageSample]
                if let data = defaults.data(forKey: Key.legacySamples) {
                    guard let value = try? decoder.decode([UsageSample].self, from: data) else {
                        return
                    }
                    legacySamples = value
                } else {
                    legacySamples = []
                }

                let legacyDaily: [DailyUsage]
                if let data = defaults.data(forKey: Key.legacyDaily) {
                    guard let value = try? decoder.decode([DailyUsage].self, from: data) else {
                        return
                    }
                    legacyDaily = value
                } else {
                    legacyDaily = []
                }

                let state = MeasurementState(
                    snapshot: legacySnapshot,
                    samples: legacySamples,
                    daily: legacyDaily
                )
                guard let data = try? encoder.encode(state) else { return }
                defaults.set(data, forKey: Key.state)
            }

            // Publish the new version before legacy cleanup. This ordering
            // makes every interruption point recoverable and idempotent.
            defaults.set(Self.currentMeasurementSchemaVersion, forKey: Key.measurementSchemaVersion)
            removeLegacyValues()
        }
    }

    private func removeLegacyValues() {
        defaults.removeObject(forKey: Key.legacySnapshot)
        defaults.removeObject(forKey: Key.legacySamples)
        defaults.removeObject(forKey: Key.legacyDaily)
    }

    private func loadState() -> MeasurementState {
        decode(MeasurementState.self, key: Key.state) ?? .empty
    }

    private func loadStateForMutation() throws -> MeasurementState {
        guard let data = defaults.data(forKey: Key.state) else { return .empty }
        do {
            return try decoder.decode(MeasurementState.self, from: data)
        } catch {
            // Never overwrite a state blob that a newer schema or storage
            // corruption made unreadable. Surface the failure and preserve it
            // for diagnosis/recovery instead.
            throw MeasurementError.storageFailed
        }
    }

    private func save(_ state: MeasurementState) throws {
        do {
            defaults.set(try encoder.encode(state), forKey: Key.state)
        } catch {
            throw MeasurementError.storageFailed
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return try body()
    }
}
