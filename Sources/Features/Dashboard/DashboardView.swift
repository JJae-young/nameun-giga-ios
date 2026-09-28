import Charts
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dvTheme) private var theme
    @State private var showingCarrierSync = false

    private var summary: WidgetSummary { appModel.summary }
    private var resetLabel: String {
        summary.periodEnd.formatted(billingFormat(.dateTime.month(.defaultDigits).day()))
    }

    private func billingFormat(_ style: Date.FormatStyle) -> Date.FormatStyle {
        var style = style
        style.timeZone = appModel.billingCalendar.timeZone
        return style
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DVSpacing.l) {
                    hero
                    metrics
                    carrierSyncCard
                    recentUsage
                    measurementFooter
                }
                .padding(.horizontal, DVSpacing.l)
                .padding(.bottom, DVSpacing.xxxl)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background { DataViewThemeBackground() }
            .refreshable { appModel.refresh() }
            .navigationTitle("남은기가")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LogoMark(height: 22)
                        .accessibilityLabel("남은기가")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { appModel.refresh() } label: {
                        Image(systemName: "arrow.clockwise")
                            .opacity(appModel.isRefreshing ? 0.45 : 1)
                    }
                    .accessibilityLabel("사용량 새로고침")
                    .disabled(appModel.isRefreshing)
                }
            }
            .overlay(alignment: .top) {
                if let error = appModel.errorMessage {
                    ErrorBanner(message: error) { appModel.errorMessage = nil }
                        .padding(.horizontal, DVSpacing.l)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showingCarrierSync) {
                CarrierUsageSyncView()
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: DVSpacing.xl) {
            ViewThatFits(in: .horizontal) {
                if !dynamicTypeSize.isAccessibilitySize {
                    HStack {
                        heroHeading
                        Spacer()
                        MeasurementStatusBadge(quality: appModel.lastQuality)
                    }
                }

                VStack(alignment: .leading, spacing: DVSpacing.m) {
                    heroHeading
                    MeasurementStatusBadge(quality: appModel.lastQuality)
                }
            }

            if appModel.lastQuality == .unavailable && summary.usedBytes == 0 {
                VStack(spacing: DVSpacing.m) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 34))
                        .foregroundStyle(theme.accentMintStrong)
                    Text("측정 준비 중")
                        .font(.title3.bold())
                        .foregroundStyle(theme.textPrimary)
                    Text("셀룰러 카운터의 변화량을 확인하면 사용량을 표시합니다. 이미 쓴 데이터는 통신사 값 맞추기에서 반영할 수 있어요.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 170)
            } else if let remaining = summary.remainingBytes, let percent = summary.usagePercent {
                ViewThatFits(in: .horizontal) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        HStack(spacing: DVSpacing.xxl) {
                            usageRing(percent: percent, size: 126)
                            heroDetails(remaining: remaining, percent: percent, centered: false)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: DVSpacing.xl) {
                        usageRing(percent: percent, size: 150)
                        heroDetails(remaining: remaining, percent: percent, centered: true)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: DVSpacing.s) {
                    Text(DataAmountFormatter.string(from: summary.usedBytes))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("이번 주기 사용")
                        .font(.headline)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 170)
            }
        }
        .padding(DVSpacing.xl)
        .background(
            LinearGradient(
                colors: [theme.elevated, theme.accentMint.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: DVRadius.large)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DVRadius.large)
                .stroke(theme.borderSoft, lineWidth: 1)
        }
        .shadow(color: theme.cardShadow, radius: 24, y: 8)
    }

    private var heroHeading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("이번 주기 데이터")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            Text("다음 초기화 \(resetLabel)")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func usageRing(percent: Double, size: CGFloat) -> some View {
        UsageRing(
            progress: percent,
            primary: "\(Int((percent * 100).rounded()))%",
            secondary: "사용",
            size: size
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: percent)
    }

    private func heroDetails(
        remaining: Int64,
        percent: Double,
        centered: Bool
    ) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: DVSpacing.s) {
            Text("남은 데이터")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textSecondary)

            Text(DataAmountFormatter.remainingString(from: remaining))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text("\(DataAmountFormatter.string(from: summary.limitBytes ?? 0)) 중 \(DataAmountFormatter.string(from: summary.usedBytes)) 사용")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .multilineTextAlignment(centered ? .center : .leading)

            Text("\(Int((percent * 100).rounded()))% 사용")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.accentMintStrong)
                .padding(.horizontal, DVSpacing.m)
                .padding(.vertical, 6)
                .background(theme.accentMint.opacity(0.16), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
    }

    private var metrics: some View {
        ViewThatFits(in: .horizontal) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: DVSpacing.m) {
                    cellularMetric
                    todayMetric
                }
            }
            VStack(spacing: DVSpacing.m) {
                cellularMetric
                todayMetric
            }
        }
    }

    private var cellularMetric: some View {
        MetricTile(
            icon: "antenna.radiowaves.left.and.right",
            title: "현재 사용량",
            value: DataAmountFormatter.string(from: summary.usedBytes),
            caption: appModel.plan?.manualAdjustmentPeriodStart == nil ? "앱 측정 기준" : "통신사 기준값 반영",
            tint: theme.accentSkyForeground,
            surface: theme.tintSky
        )
    }

    private var carrierSyncCard: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: DVSpacing.m) {
                HStack(alignment: .top, spacing: DVSpacing.m) {
                    Image(systemName: "equal.circle.fill")
                        .font(.title2)
                        .foregroundStyle(theme.accentMintStrong)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("통신사와 값이 다른가요?")
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        Text("앱 측정값은 통신사와 다를 수 있어요. 최신 사용량으로 기준을 맞춰 주세요.")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    showingCarrierSync = true
                } label: {
                    Label("통신사 값으로 맞추기", systemImage: "arrow.left.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accentMintStrong)
            }
        }
    }

    private var todayMetric: some View {
        MetricTile(
            icon: "sun.max.fill",
            title: "오늘 사용",
            value: DataAmountFormatter.string(from: summary.todayBytes),
            caption: "오늘 00:00부터",
            tint: theme.accentPinkForeground,
            surface: theme.tintPink
        )
    }

    private var recentUsage: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: DVSpacing.l) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("최근 7일")
                            .font(.headline)
                        Text(DataAmountFormatter.string(from: recentUsageTotal))
                            .font(.title3.bold())
                            .monospacedDigit()
                    }
                    Spacer()
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(theme.accentMintStrong)
                }

                Chart(lastSevenDays) { day in
                    BarMark(
                        x: .value("날짜", day.id, unit: .day),
                        y: .value("사용량", day.totalBytes)
                    )
                    .foregroundStyle(barColor(for: day))
                    .cornerRadius(4)
                    .accessibilityLabel(day.id.formatted(billingFormat(.dateTime.month().day().weekday(.wide))))
                    .accessibilityValue(DataAmountFormatter.string(from: day.totalBytes))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine().foregroundStyle(theme.borderSoft.opacity(0.55))
                        AxisValueLabel(format: billingFormat(.dateTime.weekday(.narrow)))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 104)
                .accessibilityLabel("최근 7일 데이터 사용량 차트")
            }
        }
    }

    private var measurementFooter: some View {
        HStack(spacing: DVSpacing.s) {
            Image(systemName: "clock")
            Text("남은기가 추정값 · 최근 갱신 \(summary.generatedAt.formatted(date: .omitted, time: .shortened))")
        }
        .font(.caption)
        .foregroundStyle(theme.textTertiary)
        .padding(.top, DVSpacing.s)
    }

    private func barColor(for day: DailyUsage) -> Color {
        appModel.billingCalendar.isDateInToday(day.id)
            ? theme.accentMintStrong
            : theme.accentSkyForeground.opacity(0.86)
    }

    private var lastSevenDays: [DailyUsage] {
        let calendar = appModel.billingCalendar
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset - 6, to: .now) else { return nil }
            let day = calendar.startOfDay(for: date)
            return appModel.dailyUsage.first(where: { calendar.isDate($0.id, inSameDayAs: day) })
                ?? DailyUsage(id: day, cellularBytes: 0, totalBytes: 0)
        }
    }

    private var recentUsageTotal: Int64 {
        guard let start = lastSevenDays.first?.id,
              let end = appModel.billingCalendar.date(byAdding: .day, value: 1, to: appModel.billingCalendar.startOfDay(for: .now)) else { return 0 }
        return UsageHistorySummary.total(appModel.dailyUsage, in: DateInterval(start: start, end: end))
    }
}

private struct ErrorBanner: View {
    @Environment(\.dvTheme) private var theme

    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DVSpacing.m) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.subheadline.weight(.medium))
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
            }
            .accessibilityLabel("오류 메시지 닫기")
        }
        .foregroundStyle(theme.onDanger)
        .padding(DVSpacing.m)
        .background(theme.danger, in: RoundedRectangle(cornerRadius: DVRadius.small))
    }
}

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(AppModel.preview)
    }
}
#endif
