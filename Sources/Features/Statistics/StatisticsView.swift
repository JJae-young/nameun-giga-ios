import Charts
import SwiftUI

struct StatisticsView: View {
    enum Period: String, CaseIterable, Identifiable {
        case daily = "일별"
        case weekly = "주별"
        case monthly = "월별"
        var id: String { rawValue }
    }

    struct ChartPoint: Identifiable {
        let id: Date
        let bytes: Int64
    }

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dvTheme) private var theme
    @State private var period: Period = .daily

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DVSpacing.l) {
                    Picker("통계 기간", selection: $period) {
                        ForEach(Period.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(theme.accentMintStrong)

                    SectionCard {
                        VStack(alignment: .leading, spacing: DVSpacing.xl) {
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("앱 측정량")
                                        .font(.subheadline)
                                        .foregroundStyle(theme.textSecondary)
                                    Text(DataAmountFormatter.string(from: displayedTotal))
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundStyle(theme.textPrimary)
                                        .monospacedDigit()
                                }
                                Spacer()
                                Text(periodDescription)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.accentMintStrong)
                            }

                            if displayedPoints.allSatisfy({ $0.bytes == 0 }) {
                                VStack(spacing: DVSpacing.m) {
                                    Image(systemName: "chart.bar.xaxis")
                                        .font(.system(size: 36))
                                        .foregroundStyle(theme.accentSkyForeground)
                                    Text("측정된 사용량이 아직 없어요")
                                        .font(.headline)
                                    Text("남은기가를 사용하면 이곳에 추이가 쌓입니다.")
                                        .font(.caption)
                                        .foregroundStyle(theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 220)
                            } else {
                                Chart(displayedPoints) { point in
                                    BarMark(
                                        x: .value("기간", point.id),
                                        y: .value("사용량", point.bytes)
                                    )
                                    .foregroundStyle(barColor(for: point))
                                    .cornerRadius(5)
                                    .accessibilityLabel(point.id.formatted(axisAccessibilityFormat))
                                    .accessibilityValue(DataAmountFormatter.string(from: point.bytes))
                                }
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: min(7, displayedPoints.count))) { value in
                                        AxisGridLine().foregroundStyle(theme.borderSoft.opacity(0.55))
                                        AxisValueLabel(format: axisFormat)
                                            .foregroundStyle(theme.textTertiary)
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading) { value in
                                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                            .foregroundStyle(theme.borderSoft)
                                        AxisValueLabel {
                                            if let bytes = value.as(Int64.self) {
                                                Text(DataAmountFormatter.string(from: bytes, compact: true))
                                                    .foregroundStyle(theme.textTertiary)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 250)
                                .accessibilityLabel("\(period.rawValue) 데이터 사용량 차트")
                            }
                        }
                    }

                    SectionCard {
                        VStack(alignment: .leading, spacing: DVSpacing.l) {
                            Text("현재 사용 주기")
                                .font(.headline)
                            UsageRatioRow(
                                icon: "antenna.radiowaves.left.and.right",
                                label: "현재 사용량",
                                value: DataAmountFormatter.string(from: appModel.summary.usedBytes),
                                percent: 1,
                                tint: theme.accentSkyForeground
                            )
                            Divider().overlay(theme.borderSoft)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(averageLabel)
                                        .font(.subheadline)
                                        .foregroundStyle(theme.textSecondary)
                                    Text(DataAmountFormatter.string(from: dailyAverage))
                                        .font(.title3.bold())
                                        .foregroundStyle(theme.textPrimary)
                                        .monospacedDigit()
                                }
                                Spacer()
                                MeasurementStatusBadge(quality: appModel.lastQuality)
                            }

                            if (appModel.plan?.manualAdjustmentBytes ?? 0) > 0 {
                                Text("통신사 사용량으로 보정한 값은 현재 사용 주기 합계에만 반영되며, 기간별 차트에는 남은기가 앱이 직접 측정한 값만 표시됩니다.")
                                    .font(.caption)
                                    .foregroundStyle(theme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(DVSpacing.l)
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            }
            .background { DataViewThemeBackground() }
            .navigationTitle("통계")
        }
    }

    private var displayedPoints: [ChartPoint] {
        switch period {
        case .daily:
            return makeDailyPoints(days: 14)
        case .weekly:
            return aggregate(component: .weekOfYear, count: 8)
        case .monthly:
            return aggregate(component: .month, count: 6)
        }
    }

    private var displayedTotal: Int64 {
        displayedPoints.reduce(0) { partial, point in
            let (sum, overflow) = partial.addingReportingOverflow(point.bytes)
            return overflow ? Int64.max : sum
        }
    }

    private var dailyAverage: Int64 {
        let nonFutureDays = max(1, displayedPoints.count)
        return displayedTotal / Int64(nonFutureDays)
    }

    private var averageLabel: String {
        switch period {
        case .daily: "일평균"
        case .weekly: "주평균"
        case .monthly: "월평균"
        }
    }

    private var periodDescription: String {
        switch period {
        case .daily: "최근 14일"
        case .weekly: "최근 8주"
        case .monthly: "최근 6개월"
        }
    }

    private var axisFormat: Date.FormatStyle {
        var format: Date.FormatStyle
        switch period {
        case .daily: format = .dateTime.day()
        case .weekly: format = .dateTime.month().day()
        case .monthly: format = .dateTime.month(.abbreviated)
        }
        format.timeZone = appModel.billingCalendar.timeZone
        return format
    }

    private var axisAccessibilityFormat: Date.FormatStyle {
        var format = Date.FormatStyle.dateTime.year().month().day()
        format.timeZone = appModel.billingCalendar.timeZone
        return format
    }

    private func barColor(for point: ChartPoint) -> Color {
        point.id == displayedPoints.last?.id
            ? theme.accentMintStrong
            : theme.accentSkyForeground.opacity(0.86)
    }

    private func makeDailyPoints(days: Int) -> [ChartPoint] {
        let calendar = appModel.billingCalendar
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - days + 1, to: .now) else { return nil }
            let day = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let bytes = UsageHistorySummary.total(appModel.dailyUsage, in: DateInterval(start: day, end: end))
            return ChartPoint(id: day, bytes: bytes)
        }
    }

    private func aggregate(component: Calendar.Component, count: Int) -> [ChartPoint] {
        let calendar = appModel.billingCalendar
        let startComponent: Calendar.Component = component == .month ? .month : .weekOfYear
        return (0..<count).compactMap { offset in
            guard let shifted = calendar.date(byAdding: startComponent, value: offset - count + 1, to: .now),
                  let interval = calendar.dateInterval(of: startComponent, for: shifted) else { return nil }
            let bytes = UsageHistorySummary.total(appModel.dailyUsage, in: interval)
            return ChartPoint(id: interval.start, bytes: bytes)
        }
    }
}

private struct UsageRatioRow: View {
    @Environment(\.dvTheme) private var theme

    let icon: String
    let label: String
    let value: String
    let percent: Double
    let tint: Color

    var body: some View {
        VStack(spacing: DVSpacing.s) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
            }
            ProgressView(value: percent)
                .tint(tint)
                .accessibilityLabel("\(label) 사용 비율")
                .accessibilityValue("\(Int(percent * 100))퍼센트")
        }
    }
}

#if DEBUG
struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        StatisticsView()
            .environmentObject(AppModel.preview)
    }
}
#endif
