import Foundation

struct HotspotUsageResolution: Equatable {
    let usedBytes: Int64
    let settings: HotspotPlanSettings
}

/// Carrier calibration for the hotspot allowance. Mirrors
/// `UsageCalibrationService`: the carrier value becomes this period's base and
/// only hotspot traffic measured afterwards is added to it.
struct HotspotCalibrationService {
    func calibrate(
        settings: HotspotPlanSettings,
        carrierUsageBytes: Int64,
        measuredBytes: Int64,
        period: DateInterval
    ) -> HotspotPlanSettings {
        var value = settings
        value.manualAdjustmentBytes = max(0, carrierUsageBytes)
        value.manualAdjustmentPeriodStart = period.start
        value.manualAdjustmentMeasuredBytes = max(0, measuredBytes)
        return value
    }

    func resolve(
        settings: HotspotPlanSettings,
        measuredBytes: Int64,
        period: DateInterval
    ) -> HotspotUsageResolution {
        let measured = max(0, measuredBytes)
        var value = settings

        if let calibrationPeriodStart = value.manualAdjustmentPeriodStart {
            guard calibrationPeriodStart == period.start else {
                // A new billing period starts from measured hotspot usage.
                value.manualAdjustmentBytes = 0
                value.manualAdjustmentPeriodStart = nil
                value.manualAdjustmentMeasuredBytes = nil
                return HotspotUsageResolution(usedBytes: measured, settings: value)
            }

            let measuredAtCalibration: Int64
            if let stored = value.manualAdjustmentMeasuredBytes {
                measuredAtCalibration = max(0, stored)
            } else {
                measuredAtCalibration = measured
                value.manualAdjustmentMeasuredBytes = measured
            }

            if measured < measuredAtCalibration {
                // Local history restarted (for example after a data reset).
                // Keep the carrier value and count new traffic from here.
                value.manualAdjustmentMeasuredBytes = measured
                return HotspotUsageResolution(
                    usedBytes: max(0, value.manualAdjustmentBytes),
                    settings: value
                )
            }

            let used = safeAdd(max(0, value.manualAdjustmentBytes), measured - measuredAtCalibration)
            return HotspotUsageResolution(usedBytes: used, settings: value)
        }

        if value.manualAdjustmentBytes > 0 {
            // A value entered without an anchor (initial setup on an older
            // path) is anchored to the current measured total once.
            value.manualAdjustmentPeriodStart = period.start
            value.manualAdjustmentMeasuredBytes = measured
            return HotspotUsageResolution(usedBytes: value.manualAdjustmentBytes, settings: value)
        }

        value.manualAdjustmentMeasuredBytes = nil
        return HotspotUsageResolution(usedBytes: measured, settings: value)
    }

    private func safeAdd(_ lhs: Int64, _ rhs: Int64) -> Int64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int64.max : value
    }
}

/// Input rules for a hotspot allowance that sits inside the total data plan,
/// for example 50 GB of a 160 GB plan that may be used for tethering.
enum HotspotPlanValidator {
    static func limitMessage(hotspotLimitBytes: Int64, dataLimitBytes: Int64?) -> String? {
        guard let dataLimitBytes, hotspotLimitBytes > dataLimitBytes else { return nil }
        return "핫스팟 제공량은 월 데이터 용량(\(DataAmountFormatter.string(from: dataLimitBytes)))보다 클 수 없어요."
    }

    static func usageMessage(
        hotspotUsedBytes: Int64,
        hotspotLimitBytes: Int64?,
        dataUsedBytes: Int64?
    ) -> String? {
        if let hotspotLimitBytes, hotspotUsedBytes > hotspotLimitBytes {
            return "이미 쓴 핫스팟이 핫스팟 제공량보다 큽니다. 통신사 앱의 핫스팟 항목을 확인해 주세요."
        }
        if let dataUsedBytes, dataUsedBytes > 0, hotspotUsedBytes > dataUsedBytes {
            return "핫스팟 사용량은 전체 사용량에 포함되므로 이미 쓴 데이터보다 클 수 없어요."
        }
        return nil
    }
}
