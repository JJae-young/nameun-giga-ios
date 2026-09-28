import Foundation

enum DataBytes {
    static let megabyte: Int64 = 1_000_000
    static let gigabyte: Int64 = 1_000_000_000
    static let terabyte: Int64 = 1_000_000_000_000
}

struct PlanSettings: Codable, Equatable {
    var dataLimitBytes: Int64?
    var resetDay: Int
    var isUnlimited: Bool
    var alert50: Bool
    var alert80: Bool
    var alert90: Bool
    var manualAdjustmentBytes: Int64
    var manualAdjustmentPeriodStart: Date?
    var manualAdjustmentMeasuredBytes: Int64?
    /// The carrier billing timezone captured when the plan is configured.
    /// Keeping it stable prevents roaming/device timezone changes from moving
    /// reset boundaries or invalidating a manual calibration.
    var billingTimeZoneIdentifier: String?
    var createdAt: Date
    var updatedAt: Date

    static var standard: PlanSettings {
        PlanSettings(
            dataLimitBytes: 160 * DataBytes.gigabyte,
            resetDay: 1,
            isUnlimited: false,
            alert50: true,
            alert80: true,
            alert90: true,
            manualAdjustmentBytes: 0,
            manualAdjustmentPeriodStart: nil,
            manualAdjustmentMeasuredBytes: nil,
            billingTimeZoneIdentifier: TimeZone.current.identifier,
            createdAt: .now,
            updatedAt: .now
        )
    }
}

enum InterfaceClassification: String, Codable, CaseIterable {
    case cellular
    case wifi
    case vpn
    case loopback
    case unknown

    /// Retired or future classifications must not invalidate the entire
    /// saved counter snapshot and discard the cellular baseline.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = Self(rawValue: value) ?? .unknown
    }
}

enum MeasurementQuality: String, Codable {
    case verified
    case estimated
    case partial
    case unavailable
}

struct NetworkInterfaceCounter: Codable, Equatable, Identifiable {
    var id: String { name }
    let name: String
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let classification: InterfaceClassification
    /// The kernel interface index helps distinguish a recreated interface
    /// that happens to reuse the same `pdp_ip*` name.
    let interfaceIndex: UInt32?
    /// Darwin's public `ifi_type` value. `IFT_CELLULAR` is a more stable
    /// classification signal than relying on the `pdp_ip*` name alone.
    let interfaceType: UInt8?
    /// When this specific interface counter was last observed. This remains
    /// older than the enclosing snapshot when an interface temporarily
    /// disappears, allowing its later delta to keep the correct time range.
    let observedAt: Date?
    /// A carrier calibration covered this temporarily absent interface. Its
    /// next observation must establish a new baseline instead of adding bytes
    /// that may already be included in the carrier value.
    let requiresBaseline: Bool?

    init(
        name: String,
        receivedBytes: UInt64,
        sentBytes: UInt64,
        classification: InterfaceClassification,
        interfaceIndex: UInt32? = nil,
        interfaceType: UInt8? = nil,
        observedAt: Date? = nil,
        requiresBaseline: Bool? = nil
    ) {
        self.name = name
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.classification = classification
        self.interfaceIndex = interfaceIndex
        self.interfaceType = interfaceType
        self.observedAt = observedAt
        self.requiresBaseline = requiresBaseline
    }

    var totalBytes: UInt64 {
        let (sum, overflow) = receivedBytes.addingReportingOverflow(sentBytes)
        return overflow ? UInt64.max : sum
    }
}

struct InterfaceCounterSnapshot: Codable, Equatable {
    let measuredAt: Date
    let counters: [NetworkInterfaceCounter]
    let systemBootTime: Date?
    /// Monotonic seconds including sleep. Unlike the wall-clock boot epoch,
    /// a decrease is evidence that the device actually restarted.
    let continuousTime: TimeInterval?

    init(
        measuredAt: Date,
        counters: [NetworkInterfaceCounter],
        systemBootTime: Date? = nil,
        continuousTime: TimeInterval? = nil
    ) {
        self.measuredAt = measuredAt
        self.counters = counters
        self.systemBootTime = systemBootTime
        self.continuousTime = continuousTime
    }
}

struct UsageSample: Codable, Identifiable, Equatable {
    let id: UUID
    let from: Date
    let to: Date
    let cellularBytes: Int64
    let measurementQuality: MeasurementQuality
}

struct DailyUsage: Codable, Identifiable, Equatable {
    let id: Date
    var cellularBytes: Int64
    var totalBytes: Int64
}

struct WidgetSummary: Codable, Equatable {
    let generatedAt: Date
    let periodStart: Date
    let periodEnd: Date
    let usedBytes: Int64
    let limitBytes: Int64?
    let remainingBytes: Int64?
    let usagePercent: Double?
    let iPhoneBytes: Int64?
    let todayBytes: Int64
    // Optional metadata keeps summaries from older app/widget versions readable.
    var isUnlimited: Bool? = nil
    var billingTimeZoneIdentifier: String? = nil
    var measurementQuality: MeasurementQuality? = nil

    var hasRefreshTimestamp: Bool { generatedAt.timeIntervalSince1970 > 0 }

    static var empty: WidgetSummary {
        WidgetSummary(
            generatedAt: .distantPast,
            periodStart: .now,
            periodEnd: .now,
            usedBytes: 0,
            limitBytes: nil,
            remainingBytes: nil,
            usagePercent: nil,
            iPhoneBytes: 0,
            todayBytes: 0
        )
    }

    #if DEBUG
    static var preview: WidgetSummary {
        let used = Int64(72.4 * Double(DataBytes.gigabyte))
        let limit = 160 * DataBytes.gigabyte
        return WidgetSummary(
            generatedAt: .now,
            periodStart: Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 1)) ?? .now,
            periodEnd: Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1)) ?? .now,
            usedBytes: used,
            limitBytes: limit,
            remainingBytes: limit - used,
            usagePercent: Double(used) / Double(limit),
            iPhoneBytes: used,
            todayBytes: Int64(1.2 * Double(DataBytes.gigabyte))
        )
    }
    #endif
}

/// Interprets a saved measurement without inventing new usage at midnight or a
/// billing reset. The widget can redraw even when iOS hasn't run a measurement.
struct WidgetSummaryPresentation {
    let summary: WidgetSummary
    let date: Date

    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        if let identifier = summary.billingTimeZoneIdentifier,
           let timeZone = TimeZone(identifier: identifier) {
            value.timeZone = timeZone
        }
        return value
    }

    var hasConfiguredPlan: Bool {
        summary.isUnlimited != nil || summary.limitBytes != nil || summary.hasRefreshTimestamp
    }

    var isUnlimited: Bool {
        summary.isUnlimited ?? (hasConfiguredPlan && summary.limitBytes == nil)
    }

    var hasCurrentPeriodUsage: Bool {
        hasConfiguredPlan && summary.hasRefreshTimestamp
            && date >= summary.periodStart && date < summary.periodEnd
            && summary.generatedAt >= summary.periodStart
            && summary.generatedAt <= date
    }

    var hasCurrentDayUsage: Bool {
        hasCurrentPeriodUsage && calendar.isDate(summary.generatedAt, inSameDayAs: date)
    }

    var needsRefresh: Bool {
        !hasCurrentDayUsage || date.timeIntervalSince(summary.generatedAt) >= 6 * 60 * 60
            || summary.measurementQuality == .unavailable
    }

    /// Future entries ensure old values become visibly outdated even if a
    /// requested timeline reload or background measurement is delayed by iOS.
    var transitionDates: [Date] {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
        return Set([nextDay, summary.periodEnd, summary.generatedAt.addingTimeInterval(6 * 60 * 60)]
            .compactMap { $0 }
            .filter { $0 > date && $0 <= date.addingTimeInterval(24 * 60 * 60) })
            .sorted()
    }
}

enum MeasurementError: LocalizedError {
    case interfaceReadFailed
    case invalidCounter
    case storageFailed

    var errorDescription: String? {
        switch self {
        case .interfaceReadFailed: "네트워크 사용량을 읽지 못했습니다."
        case .invalidCounter: "올바르지 않은 네트워크 측정값입니다."
        case .storageFailed: "측정값을 저장하지 못했습니다."
        }
    }
}
