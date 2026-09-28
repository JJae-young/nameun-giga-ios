import Foundation

/// Local interfaces that carry Personal Hotspot client traffic.
///
/// iOS has no public API for hotspot totals, so DataView observes the local
/// side of the sharing path: the sharing bridge (`bridge*`, whose members are
/// the Wi-Fi/USB/Bluetooth links) and the Wi-Fi soft access point (`ap*`).
/// The same packets can cross both, so each family is measured separately and
/// only the larger delta is used.
enum HotspotInterfaceFamily: String, CaseIterable {
    case bridge
    case accessPoint

    init?(interfaceName: String) {
        let normalized = interfaceName.lowercased()
        if normalized.hasPrefix("bridge") {
            self = .bridge
        } else if normalized.hasPrefix("ap") {
            self = .accessPoint
        } else {
            return nil
        }
    }
}

struct HotspotUsageDelta: Equatable {
    /// Bytes attributed to hotspot clients during the interval.
    let bytes: Int64
    /// A sharing interface was reset/recreated or the value was capped, so
    /// part of the interval may be missing or estimated.
    let isPartial: Bool

    static let zero = HotspotUsageDelta(bytes: 0, isPartial: false)
}

enum HotspotUsageCalculator {
    /// - Parameters:
    ///   - previousCounters: Every counter of the previous snapshot. Older
    ///     builds stored sharing interfaces as `.unknown`; they are matched by
    ///     name so an upgrade never counts their lifetime totals.
    ///   - currentCounters: Counters read now.
    ///   - rebooted: The device restarted since the previous snapshot, so
    ///     every current counter belongs to the new boot session.
    ///   - cellularBytes: Cellular delta of the same interval. Hotspot clients
    ///     reach the internet through cellular, so this is a hard upper bound.
    ///   - isPlausible: The same spike guard used for cellular contributions.
    static func delta(
        previousCounters: [NetworkInterfaceCounter],
        currentCounters: [NetworkInterfaceCounter],
        rebooted: Bool,
        cellularBytes: Int64,
        isPlausible: (UInt64) -> Bool
    ) -> HotspotUsageDelta {
        guard cellularBytes > 0 else { return .zero }

        var previousByName: [String: NetworkInterfaceCounter] = [:]
        for counter in previousCounters {
            if let existing = previousByName[counter.name], existing.totalBytes > counter.totalBytes {
                continue
            }
            previousByName[counter.name] = counter
        }

        var bytesByFamily: [HotspotInterfaceFamily: UInt64] = [:]
        var isPartial = false
        var seenNames = Set<String>()

        for counter in currentCounters {
            guard counter.classification == .hotspotCandidate,
                  let family = HotspotInterfaceFamily(interfaceName: counter.name),
                  seenNames.insert(counter.name).inserted else { continue }

            let bytes: UInt64
            if rebooted {
                bytes = counter.totalBytes
                isPartial = true
            } else if let previous = previousByName[counter.name] {
                if identityChanged(previous: previous, current: counter)
                    || counter.receivedBytes < previous.receivedBytes
                    || counter.sentBytes < previous.sentBytes {
                    // A new sharing session reuses the name with fresh
                    // counters; traffic after the last reading of the old
                    // session is unrecoverable.
                    bytes = counter.totalBytes
                    isPartial = true
                } else {
                    bytes = add(
                        counter.receivedBytes - previous.receivedBytes,
                        counter.sentBytes - previous.sentBytes
                    )
                }
            } else if family == .bridge {
                // Sharing bridges are created per session, so a new bridge
                // carries only traffic since it appeared.
                bytes = counter.totalBytes
            } else {
                // The soft-AP normally persists for the whole boot session, so
                // an unseen one may hold earlier sessions' traffic. Use it as a
                // baseline; the bridge family still covers the new session.
                bytes = 0
                isPartial = true
            }

            guard bytes > 0 else { continue }
            guard isPlausible(bytes) else {
                isPartial = true
                continue
            }
            bytesByFamily[family] = add(bytesByFamily[family] ?? 0, bytes)
        }

        guard let largest = bytesByFamily.values.max(), largest > 0 else {
            return HotspotUsageDelta(bytes: 0, isPartial: isPartial)
        }
        let hotspotBytes = CounterDeltaCalculator.clampedInt64(largest)
        if hotspotBytes > cellularBytes {
            return HotspotUsageDelta(bytes: cellularBytes, isPartial: true)
        }
        return HotspotUsageDelta(bytes: hotspotBytes, isPartial: isPartial)
    }

    private static func identityChanged(
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

    private static func add(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? UInt64.max : sum
    }
}
