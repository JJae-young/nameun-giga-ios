import Foundation

struct MeasurementResult: Equatable {
    let measuredAt: Date
    let cellularBytes: Int64
    let quality: MeasurementQuality
    /// Portion of `cellularBytes` attributed to Personal Hotspot clients.
    var hotspotBytes: Int64 = 0
}

struct UsageMeasurementService {
    private struct CounterContribution {
        let bytes: UInt64
        let from: Date
    }

    let reader: NetworkCounterReading
    let repository: UsageRepository
    private let systemBootTime: () -> Date?
    private let continuousTime: () -> TimeInterval?
    private let calendar: Calendar
    private let maximumCellularBytesPerSecond: Double
    private let burstAllowanceBytes: UInt64

    init(
        reader: NetworkCounterReading = NetworkCounterReader(),
        repository: UsageRepository = UsageRepository(),
        systemBootTime: @escaping () -> Date? = SystemBootTimeReader.read,
        continuousTime: @escaping () -> TimeInterval? = SystemBootTimeReader.continuousTime,
        calendar: Calendar = .current,
        maximumCellularBytesPerSecond: Double = 625_000_000,
        burstAllowanceBytes: UInt64 = 64_000_000
    ) {
        self.reader = reader
        self.repository = repository
        self.systemBootTime = systemBootTime
        self.continuousTime = continuousTime
        self.calendar = calendar
        self.maximumCellularBytesPerSecond = maximumCellularBytesPerSecond
        self.burstAllowanceBytes = burstAllowanceBytes
    }

    func measure(at date: Date = .now) throws -> MeasurementResult {
        try measure(at: date, preparingCalibration: false)
    }

    /// Takes a fresh carrier-calibration boundary while retaining enough
    /// history to avoid counting an absent interface's old traffic on return.
    func prepareCalibrationBaseline(at date: Date = .now) throws -> MeasurementResult {
        let result = try measure(at: date, preparingCalibration: true)
        guard let snapshot = repository.latestSnapshot(),
              snapshot.measuredAt == date,
              snapshot.counters.contains(where: {
                  $0.classification == .cellular && $0.observedAt == date
              }) else { throw MeasurementError.interfaceReadFailed }
        return result
    }

    private func measure(at date: Date, preparingCalibration: Bool) throws -> MeasurementResult {
        let currentCounters = try reader.readCounters().map { counter($0, observedAt: date) }
        if preparingCalibration, !currentCounters.contains(where: { $0.classification == .cellular }) {
            throw MeasurementError.interfaceReadFailed
        }
        let currentSnapshot = InterfaceCounterSnapshot(
            measuredAt: date,
            counters: currentCounters,
            systemBootTime: systemBootTime(),
            continuousTime: continuousTime()
        )
        let previousSnapshot = repository.latestSnapshot()

        guard let previousSnapshot else {
            let initialized = try repository.initialize(snapshot: currentSnapshot)
            if preparingCalibration, !initialized { throw MeasurementError.interfaceReadFailed }
            return MeasurementResult(measuredAt: date, cellularBytes: 0, quality: initialized ? .unavailable : .partial)
        }

        let rebooted = hasRebooted(previous: previousSnapshot, current: currentSnapshot)
        let clockShift = wallClockShift(previous: previousSnapshot, current: currentSnapshot, rebooted: rebooted)
        let previousMeasuredAt = previousSnapshot.measuredAt.addingTimeInterval(clockShift)
        // Ignore stale invocations, but permit a verified wall-clock rollback
        // while the monotonic clock continues forward. Otherwise measurement
        // would stop until wall time caught up with the old snapshot.
        guard date > previousSnapshot.measuredAt || (clockShift < 0 && date > previousMeasuredAt) else {
            if preparingCalibration { throw MeasurementError.interfaceReadFailed }
            return MeasurementResult(measuredAt: date, cellularBytes: 0, quality: .partial)
        }

        // Match against every prior interface. A classifier upgrade can turn a
        // previously stored `.unknown` interface into `.cellular`; treating it
        // as new would add its full lifetime counter as fresh usage.
        let previousAllByName = countersByName(previousSnapshot.counters)
        let previousCellularNames = Set(
            previousSnapshot.counters
                .filter { $0.classification == .cellular }
                .map(\.name)
        )
        let currentByName = countersByName(
            currentCounters.filter { $0.classification == .cellular }
        )
        let currentNames = Set(currentByName.keys)

        // Wi-Fi-only/airplane-mode route dumps can temporarily omit every
        // cellular interface. Preserve the last cellular baseline; replacing
        // it with an empty snapshot would make a later reappearance look like
        // an entirely new interface and count its historical total.
        guard !currentByName.isEmpty else {
            return MeasurementResult(measuredAt: date, cellularBytes: 0, quality: .unavailable)
        }

        let hasComparablePriorCounter = currentNames.contains {
            previousAllByName[$0] != nil
        }
        if previousCellularNames.isEmpty, !hasComparablePriorCounter {
            // If the first baseline was captured while cellular interfaces were
            // absent, the first later pdp counter may contain traffic from well
            // before that snapshot. Baseline it once instead of reporting a
            // phantom lifetime total.
            let baselineSample = UsageSample(
                id: UUID(),
                from: previousSnapshot.measuredAt,
                to: date,
                cellularBytes: 0,
                hotspotBytes: nil,
                measurementQuality: .unavailable
            )
            let committed = try repository.record(
                snapshot: currentSnapshot,
                sample: baselineSample,
                bytes: 0,
                from: previousSnapshot.measuredAt,
                to: date,
                calendar: calendar,
                expectedPreviousMeasuredAt: previousSnapshot.measuredAt,
                allocations: []
            )
            if preparingCalibration, !committed { throw MeasurementError.interfaceReadFailed }
            return MeasurementResult(
                measuredAt: date,
                cellularBytes: 0,
                quality: committed ? .unavailable : .partial
            )
        }

        let rebootIntervalStart = effectiveCounterIntervalStart(
            previous: previousSnapshot,
            current: currentSnapshot,
            rebooted: rebooted
        )
        var contributions: [CounterContribution] = []
        var quality: MeasurementQuality

        if rebooted {
            // Every current counter was created during the new boot session.
            // Its current value is safe to include as a post-reboot lower bound;
            // traffic between the old sample and reboot is unrecoverable.
            quality = .partial
            for counter in currentByName.values {
                contributions.append(
                    CounterContribution(bytes: counter.totalBytes, from: rebootIntervalStart)
                )
            }
        } else {
            quality = previousCellularNames.subtracting(currentNames).isEmpty ? .verified : .partial
            if bootEpochChanged(previous: previousSnapshot, current: currentSnapshot) {
                // Wall-clock corrections also change kern.boottime. Without
                // a confirmed monotonic reset, lifetime totals are unsafe.
                quality = .partial
            }

            for counter in currentByName.values {
                guard let previous = previousAllByName[counter.name] else {
                    // The interface appeared after the previous complete route
                    // dump, so its current cumulative value is new usage.
                    contributions.append(
                        CounterContribution(bytes: counter.totalBytes, from: previousMeasuredAt)
                    )
                    quality = .partial
                    continue
                }

                if previous.requiresBaseline == true {
                    // Its earlier traffic was already covered by a carrier
                    // calibration while this interface was absent.
                    quality = .partial
                    continue
                }

                let previousObservedAt = (previous.observedAt ?? previousSnapshot.measuredAt)
                    .addingTimeInterval(clockShift)
                if previousObservedAt < previousMeasuredAt {
                    // This counter was carried through one or more snapshots
                    // while temporarily absent. Its aggregate delta is useful,
                    // but the unobserved interval remains partial.
                    quality = .partial
                }

                let identityChanged = interfaceIdentityChanged(previous: previous, current: counter)
                let counterReset = counter.receivedBytes < previous.receivedBytes
                    || counter.sentBytes < previous.sentBytes

                if identityChanged || counterReset {
                    // RX and TX belong to one interface generation. If either
                    // side resets, use both current values rather than mixing a
                    // new RX baseline with an old TX delta.
                    contributions.append(
                        CounterContribution(bytes: counter.totalBytes, from: previousObservedAt)
                    )
                    quality = .partial
                } else {
                    let delta = safeAdd(
                        counter.receivedBytes - previous.receivedBytes,
                        counter.sentBytes - previous.sentBytes
                    )
                    contributions.append(
                        CounterContribution(bytes: delta, from: previousObservedAt)
                    )
                }
            }
        }

        var bytes: Int64 = 0
        var allocations: [UsageIntervalAllocation] = []
        for contribution in contributions where contribution.bytes > 0 {
            let elapsed = date.timeIntervalSince(contribution.from)
            guard isPlausible(bytes: contribution.bytes, elapsed: elapsed) else {
                // A malformed/unsupported route payload must not permanently
                // add a multi-gigabyte spike. The new counter is still saved as
                // a baseline, while this contribution is quarantined.
                quality = .partial
                continue
            }

            let contributionBytes = CounterDeltaCalculator.clampedInt64(contribution.bytes)
            bytes = safeAdd(bytes, contributionBytes)
            allocations.append(
                UsageIntervalAllocation(bytes: contributionBytes, from: contribution.from, to: date)
            )
        }

        if quality == .verified,
           allocations.contains(where: { spansMultipleDayBuckets(from: $0.from, to: $0.to) }) {
            // Without intermediate samples, assigning a cross-midnight delta
            // to individual days is necessarily a time-weighted estimate.
            quality = .estimated
        }

        let earliestContribution = allocations.map(\.from).min() ?? previousMeasuredAt
        let sampleStart = min(previousMeasuredAt, earliestContribution)
        // Hotspot counters are compared with the previous snapshot only, and
        // after a reboot they cover just the new boot session.
        let hotspotStart = rebooted ? rebootIntervalStart : previousMeasuredAt
        let hotspotElapsed = date.timeIntervalSince(hotspotStart)
        let hotspot = HotspotUsageCalculator.delta(
            previousCounters: previousSnapshot.counters,
            currentCounters: currentCounters,
            rebooted: rebooted,
            cellularBytes: bytes,
            isPlausible: { isPlausible(bytes: $0, elapsed: hotspotElapsed) }
        )
        // Spread hotspot bytes over the interval they were observed in, using
        // the same time-weighted day split as cellular.
        let hotspotAllocations: [UsageIntervalAllocation] = hotspot.bytes > 0
            ? [UsageIntervalAllocation(bytes: hotspot.bytes, from: hotspotStart, to: date)]
            : []
        let sample = UsageSample(
            id: UUID(),
            from: sampleStart,
            to: date,
            cellularBytes: bytes,
            hotspotBytes: hotspot.bytes > 0 ? hotspot.bytes : nil,
            measurementQuality: quality
        )
        let snapshotToStore = snapshotPreservingMissingCellularCounters(
            previous: previousSnapshot,
            current: currentSnapshot,
            rebooted: rebooted,
            preparingCalibration: preparingCalibration,
            clockShift: clockShift
        )
        let committed = try repository.record(
            snapshot: snapshotToStore,
            sample: sample,
            bytes: bytes,
            from: sampleStart,
            to: date,
            calendar: calendar,
            expectedPreviousMeasuredAt: previousSnapshot.measuredAt,
            allocations: allocations,
            hotspotAllocations: hotspotAllocations
        )
        guard committed else {
            if preparingCalibration { throw MeasurementError.interfaceReadFailed }
            return MeasurementResult(measuredAt: date, cellularBytes: 0, quality: .partial)
        }
        return MeasurementResult(
            measuredAt: date,
            cellularBytes: bytes,
            quality: quality,
            hotspotBytes: hotspot.bytes
        )
    }

    private func countersByName(
        _ counters: [NetworkInterfaceCounter]
    ) -> [String: NetworkInterfaceCounter] {
        counters.reduce(into: [:]) { result, counter in
            if let existing = result[counter.name], existing.totalBytes > counter.totalBytes {
                return
            }
            result[counter.name] = counter
        }
    }

    private func hasRebooted(
        previous: InterfaceCounterSnapshot,
        current: InterfaceCounterSnapshot
    ) -> Bool {
        guard let previousTime = previous.continuousTime,
              let currentTime = current.continuousTime,
              previousTime.isFinite, currentTime.isFinite else {
            return false
        }
        return currentTime < previousTime
    }

    private func bootEpochChanged(
        previous: InterfaceCounterSnapshot,
        current: InterfaceCounterSnapshot
    ) -> Bool {
        guard let previousBootTime = previous.systemBootTime,
              let currentBootTime = current.systemBootTime else { return false }
        return abs(currentBootTime.timeIntervalSince(previousBootTime)) > 60
    }

    private func wallClockShift(
        previous: InterfaceCounterSnapshot,
        current: InterfaceCounterSnapshot,
        rebooted: Bool
    ) -> TimeInterval {
        guard !rebooted,
              bootEpochChanged(previous: previous, current: current),
              let previousTime = previous.continuousTime,
              let currentTime = current.continuousTime,
              previousTime.isFinite, currentTime.isFinite,
              currentTime > previousTime else { return 0 }
        return current.measuredAt.timeIntervalSince(previous.measuredAt) - (currentTime - previousTime)
    }

    private func effectiveCounterIntervalStart(
        previous: InterfaceCounterSnapshot,
        current: InterfaceCounterSnapshot,
        rebooted: Bool
    ) -> Date {
        guard rebooted,
              let bootTime = current.systemBootTime,
              bootTime > previous.measuredAt,
              bootTime < current.measuredAt else {
            return previous.measuredAt
        }
        return bootTime
    }

    private func spansMultipleDayBuckets(from start: Date, to end: Date) -> Bool {
        let startDay = calendar.startOfDay(for: start)
        guard let firstBoundary = calendar.date(byAdding: .day, value: 1, to: startDay) else {
            return false
        }
        return end > firstBoundary
    }

    private func snapshotPreservingMissingCellularCounters(
        previous: InterfaceCounterSnapshot,
        current: InterfaceCounterSnapshot,
        rebooted: Bool,
        preparingCalibration: Bool,
        clockShift: TimeInterval
    ) -> InterfaceCounterSnapshot {
        guard !rebooted else { return current }

        let currentNames = Set(current.counters.map(\.name))
        let missingCellular = previous.counters.filter {
            $0.classification == .cellular && !currentNames.contains($0.name)
        }.map { value in
            NetworkInterfaceCounter(
                name: value.name,
                receivedBytes: value.receivedBytes,
                sentBytes: value.sentBytes,
                classification: value.classification,
                interfaceIndex: value.interfaceIndex,
                interfaceType: value.interfaceType,
                observedAt: (value.observedAt ?? previous.measuredAt).addingTimeInterval(clockShift),
                requiresBaseline: preparingCalibration ? true : value.requiresBaseline
            )
        }
        guard !missingCellular.isEmpty else { return current }

        return InterfaceCounterSnapshot(
            measuredAt: current.measuredAt,
            counters: (current.counters + missingCellular).sorted { $0.name < $1.name },
            systemBootTime: current.systemBootTime,
            continuousTime: current.continuousTime
        )
    }

    private func interfaceIdentityChanged(
        previous: NetworkInterfaceCounter,
        current: NetworkInterfaceCounter
    ) -> Bool {
        if let previousIndex = previous.interfaceIndex,
           let currentIndex = current.interfaceIndex,
           previousIndex != currentIndex {
            return true
        }
        if let previousType = previous.interfaceType,
           let currentType = current.interfaceType,
           previousType != currentType {
            return true
        }
        return false
    }

    private func counter(
        _ value: NetworkInterfaceCounter,
        observedAt: Date
    ) -> NetworkInterfaceCounter {
        NetworkInterfaceCounter(
            name: value.name,
            receivedBytes: value.receivedBytes,
            sentBytes: value.sentBytes,
            classification: value.classification,
            interfaceIndex: value.interfaceIndex,
            interfaceType: value.interfaceType,
            observedAt: observedAt
        )
    }

    private func isPlausible(bytes: UInt64, elapsed: TimeInterval) -> Bool {
        guard bytes > burstAllowanceBytes else { return true }
        guard elapsed > 0, elapsed.isFinite else { return false }
        let maximum = Double(burstAllowanceBytes) + elapsed * maximumCellularBytesPerSecond
        return Double(bytes) <= maximum
    }

    private func safeAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? UInt64.max : sum
    }

    private func safeAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : sum
    }
}
