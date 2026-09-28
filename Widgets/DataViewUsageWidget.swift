import AppIntents
import SwiftUI
import WidgetKit

struct UsageWidgetEntry: TimelineEntry {
    let date: Date
    let summary: WidgetSummary
    let isStale: Bool
    let appearance: WidgetAppearancePreferences

    var presentation: WidgetSummaryPresentation {
        WidgetSummaryPresentation(summary: summary, date: date)
    }
}

struct UsageTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageWidgetEntry {
        let appearance = WidgetAppearancePreferencesStore().load()
        #if DEBUG
        return UsageWidgetEntry(
            date: .now,
            summary: .preview,
            isStale: false,
            appearance: appearance
        )
        #else
        return UsageWidgetEntry(
            date: .now,
            summary: .empty,
            isStale: false,
            appearance: appearance
        )
        #endif
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageWidgetEntry) -> Void) {
        #if DEBUG
        if context.isPreview {
            completion(
                UsageWidgetEntry(
                    date: .now,
                    summary: .preview,
                    isStale: false,
                    appearance: WidgetAppearancePreferencesStore().load()
                )
            )
            return
        }
        #endif
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageWidgetEntry>) -> Void) {
        let value = entry()
        let transitions = value.presentation.transitionDates.map { date in
            UsageWidgetEntry(
                date: date,
                summary: value.summary,
                isStale: WidgetSummaryPresentation(summary: value.summary, date: date).needsRefresh,
                appearance: value.appearance
            )
        }
        let nextRefresh = value.date.addingTimeInterval(30 * 60)
        completion(Timeline(entries: [value] + transitions, policy: .after(nextRefresh)))
    }

    private func entry() -> UsageWidgetEntry {
        let summary = WidgetStore.load() ?? .empty
        let now = Date.now
        let stale = WidgetSummaryPresentation(summary: summary, date: now).needsRefresh
        return UsageWidgetEntry(
            date: now,
            summary: summary,
            isStale: stale,
            appearance: WidgetAppearancePreferencesStore().load()
        )
    }
}

private enum WidgetStore {
    static func load() -> WidgetSummary? {
        WidgetSummaryStore.load()
    }
}

struct DataViewUsageWidget: Widget {
    let kind = "DataViewUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageTimelineProvider()) { entry in
            DataViewWidgetEntryView(entry: entry)
                .widgetURL(URL(string: "dataview://dashboard"))
        }
        .configurationDisplayName("데이터 사용량")
        .description("이번 주기 남은 데이터와 사용량을 빠르게 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

private struct DataViewWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var systemColorScheme
    let entry: UsageWidgetEntry

    var body: some View {
        Group {
            if !entry.presentation.hasCurrentPeriodUsage
                || (entry.isStale && (family == .accessoryCircular || family == .accessoryRectangular)) {
                WidgetNeedsRefreshView(entry: entry)
            } else {
                switch family {
                case .systemSmall:
                    SmallWidgetView(entry: entry)
                case .systemMedium:
                    MediumWidgetView(entry: entry)
                case .accessoryCircular:
                    CircularWidgetView(entry: entry)
                case .accessoryRectangular:
                    RectangularWidgetView(entry: entry)
                default:
                    SmallWidgetView(entry: entry)
                }
            }
        }
        .environment(\.dvTheme, palette)
        .environment(\.colorScheme, resolvedColorScheme)
        .containerBackground(for: .widget) {
            WidgetThemeBackground(
                palette: palette,
                usesCustomTheme: usesCustomTheme
            )
        }
    }

    private var usesCustomTheme: Bool {
        guard renderingMode == .fullColor else { return false }
        switch family {
        case .systemSmall, .systemMedium: return true
        default: return false
        }
    }

    private var resolvedColorScheme: ColorScheme {
        guard usesCustomTheme else { return systemColorScheme }
        switch entry.appearance.appearanceMode {
        case .system: return systemColorScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var palette: DVThemePalette {
        DVThemePalette.resolve(
            visualTheme: usesCustomTheme ? entry.appearance.visualTheme : .classicBlue,
            colorScheme: resolvedColorScheme
        )
    }
}

private struct WidgetNeedsRefreshView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.dvTheme) private var theme
    let entry: UsageWidgetEntry

    private var title: String {
        entry.presentation.hasConfiguredPlan ? "사용량 갱신 필요" : "요금제 설정 필요"
    }

    var body: some View {
        if family == .accessoryCircular {
            VStack(spacing: 2) {
                Image(systemName: "arrow.clockwise")
                Text(entry.presentation.hasConfiguredPlan ? "갱신 필요" : "설정 필요")
                    .font(.system(size: 9, weight: .semibold))
            }
            .accessibilityLabel(title)
        } else if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 3) {
                Label("남은기가", systemImage: "antenna.radiowaves.left.and.right")
                Text(title)
            }
            .font(.caption)
            .accessibilityElement(children: .combine)
        } else {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("데이터 사용량", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.trailing, 42)
                    Spacer(minLength: 0)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    Text(entry.presentation.hasConfiguredPlan
                         ? "새로고침하여 이번 주기 사용량을 확인하세요."
                         : "앱에서 요금제를 설정해 주세요.")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    WidgetUpdateStatus(entry: entry)
                }
                if entry.presentation.hasConfiguredPlan {
                    WidgetRefreshButton(summary: entry.summary, isStale: true)
                }
            }
        }
    }
}

private struct WidgetThemeBackground: View {
    let palette: DVThemePalette
    let usesCustomTheme: Bool

    var body: some View {
        if usesCustomTheme {
            ZStack {
                palette.canvas
                if palette.visualTheme == .softPastel {
                    RadialGradient(
                        colors: [palette.accentMint.opacity(palette.isDark ? 0.12 : 0.22), .clear],
                        center: .topLeading,
                        startRadius: 8,
                        endRadius: 190
                    )
                    RadialGradient(
                        colors: [palette.accentLavender.opacity(palette.isDark ? 0.10 : 0.14), .clear],
                        center: .bottomTrailing,
                        startRadius: 12,
                        endRadius: 210
                    )
                }
            }
        } else {
            Color.clear
        }
    }
}

private struct SmallWidgetView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.dvTheme) private var theme
    let entry: UsageWidgetEntry

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    WidgetLogo()
                    Text("이번 주기")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                }
                .padding(.trailing, 42)

                Spacer(minLength: 0)
                Group {
                    if let remaining = entry.summary.remainingBytes, let percent = entry.summary.usagePercent {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .stroke(graphTrackColor, lineWidth: 7)
                                Circle()
                                    .trim(from: 0, to: min(1, max(0, percent)))
                                    .stroke(
                                        theme.accentMintForeground,
                                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .widgetAccentable()
                                Text("\(Int((percent * 100).rounded()))%")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(theme.textPrimary)
                                    .minimumScaleFactor(0.72)
                                    .lineLimit(1)
                                    .monospacedDigit()
                            }
                            .frame(width: 72, height: 72)
                            .frame(maxWidth: .infinity)
                            Text("\(DataAmountFormatter.remainingString(from: remaining)) 남음")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.textPrimary)
                                .minimumScaleFactor(0.72)
                                .lineLimit(1)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(DataAmountFormatter.string(from: entry.summary.usedBytes))
                                .font(.title2.bold())
                                .foregroundStyle(theme.textPrimary)
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Text("이번 주기 사용")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                            Text(entry.presentation.isUnlimited ? "무제한 요금제" : "한도 없음")
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
                .invalidatableContent()
                Spacer(minLength: 0)
                WidgetUpdateStatus(entry: entry)
            }
            WidgetRefreshButton(summary: entry.summary, isStale: entry.isStale)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityText)
    }

    private var graphTrackColor: Color {
        renderingMode == .accented ? .primary.opacity(0.18) : theme.track
    }

    private var accessibilityText: String {
        if let remaining = entry.summary.remainingBytes, let percent = entry.summary.usagePercent {
            return "데이터 \(DataAmountFormatter.remainingString(from: remaining)) 남음, \(Int(percent * 100))퍼센트 사용"
        }
        return "이번 주기 \(DataAmountFormatter.string(from: entry.summary.usedBytes)) 사용"
    }
}

private struct MediumWidgetView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.dvTheme) private var theme
    let entry: UsageWidgetEntry

    var body: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { proxy in
                HStack(alignment: .top, spacing: 12) {
                    summaryColumn
                        .frame(width: proxy.size.width * 0.43, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(totalLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.textPrimary)
                            .minimumScaleFactor(0.72)
                            .lineLimit(1)
                            .padding(.trailing, 38)
                            .invalidatableContent()
                        if entry.summary.hotspotBytes != nil {
                            // The used total is already in the headline, so the
                            // first slot shows the separate hotspot allowance.
                            WidgetMetric(
                                icon: "personalhotspot",
                                title: "핫스팟",
                                value: hotspotValue,
                                tint: theme.accentLavenderForeground,
                                surface: theme.tintLavender,
                                renderingMode: renderingMode
                            )
                        } else {
                            WidgetMetric(
                                icon: "antenna.radiowaves.left.and.right",
                                title: "현재 사용량",
                                value: DataAmountFormatter.string(from: entry.summary.iPhoneBytes ?? entry.summary.usedBytes),
                                tint: theme.accentSkyForeground,
                                surface: theme.tintSky,
                                renderingMode: renderingMode
                            )
                        }
                        WidgetMetric(
                            icon: "sun.max.fill",
                            title: "오늘 사용",
                            value: entry.presentation.hasCurrentDayUsage
                                ? DataAmountFormatter.string(from: entry.summary.todayBytes)
                                : "갱신 필요",
                            tint: theme.warning,
                            surface: theme.tintPink,
                            renderingMode: renderingMode
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            WidgetRefreshButton(summary: entry.summary, isStale: entry.isStale)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var summaryColumn: some View {
        if let remaining = entry.summary.remainingBytes,
           let percent = entry.summary.usagePercent {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    WidgetLogo()
                    Text("이번 주기 데이터")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                }
                Text(DataAmountFormatter.remainingString(from: remaining))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)
                    .monospacedDigit()
                    .invalidatableContent()
                Text("남음 · \(Int((percent * 100).rounded()))% 사용")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .monospacedDigit()
                ProgressView(value: min(1, max(0, percent)))
                    .tint(theme.accentMintForeground)
                    .widgetAccentable()
                Text("다음 초기화 \(resetDateText)")
                    .font(.caption2)
                    .foregroundStyle(theme.textTertiary)
                WidgetUpdateStatus(entry: entry)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    WidgetLogo()
                    Text("이번 주기 데이터")
                        .font(.caption.weight(.semibold))
                }
                Text(DataAmountFormatter.string(from: entry.summary.usedBytes))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .minimumScaleFactor(0.68)
                    .lineLimit(1)
                Text(entry.presentation.isUnlimited ? "무제한 요금제" : "한도 없음")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                WidgetUpdateStatus(entry: entry)
            }
        }
    }

    private var hotspotValue: String {
        guard entry.presentation.hasCurrentPeriodUsage,
              let used = entry.summary.hotspotBytes else { return "갱신 필요" }
        if let remaining = entry.summary.hotspotRemainingBytes {
            return "\(DataAmountFormatter.remainingString(from: remaining)) 남음"
        }
        return DataAmountFormatter.string(from: used)
    }

    private var totalLabel: String {
        guard let limit = entry.summary.limitBytes else {
            return "이번 주기 \(DataAmountFormatter.string(from: entry.summary.usedBytes))"
        }
        return "\(DataAmountFormatter.string(from: entry.summary.usedBytes)) / \(DataAmountFormatter.string(from: limit))"
    }

    private var resetDateText: String {
        let formatter = DateFormatter()
        formatter.timeZone = entry.presentation.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: entry.summary.periodEnd)
    }
}

private struct CircularWidgetView: View {
    let entry: UsageWidgetEntry

    var body: some View {
        if let percent = entry.summary.usagePercent {
            Gauge(value: percent) {
                Image(systemName: "antenna.radiowaves.left.and.right")
            } currentValueLabel: {
                Text("\(Int((percent * 100).rounded()))%")
                    .font(.caption.bold())
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel("데이터 \(Int(percent * 100))퍼센트 사용")
        } else {
            Gauge(value: 0) {
                Image(systemName: "antenna.radiowaves.left.and.right")
            } currentValueLabel: {
                Text("DATA")
                    .font(.system(size: 9, weight: .bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
    }
}

private struct RectangularWidgetView: View {
    let entry: UsageWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("데이터", systemImage: "antenna.radiowaves.left.and.right")
                .font(.caption.weight(.semibold))
            if let remaining = entry.summary.remainingBytes, let percent = entry.summary.usagePercent {
                Text("\(DataAmountFormatter.remainingString(from: remaining)) 남음")
                    .font(.headline)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Text("\(Int((percent * 100).rounded()))% 사용")
                    .font(.caption2)
            } else {
                Text("\(DataAmountFormatter.string(from: entry.summary.usedBytes, compact: true)) 사용")
                    .font(.headline)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WidgetMetric: View {
    @Environment(\.dvTheme) private var theme

    let icon: String
    let title: String
    let value: String
    var tint: Color? = nil
    var surface: Color? = nil
    let renderingMode: WidgetRenderingMode

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint ?? theme.accentSkyForeground)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(metricBackground, in: RoundedRectangle(cornerRadius: 11))
    }

    private var metricBackground: Color {
        renderingMode == .accented ? .primary.opacity(0.12) : (surface ?? theme.subtle)
    }
}

private struct WidgetLogo: View {
    @Environment(\.dvTheme) private var theme

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            RoundedRectangle(cornerRadius: 1).frame(width: 3, height: 5)
            RoundedRectangle(cornerRadius: 1).frame(width: 3, height: 8)
            RoundedRectangle(cornerRadius: 1).frame(width: 3, height: 11)
        }
        .foregroundStyle(theme.accentMintStrong)
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}

private struct WidgetRefreshButton: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.dvTheme) private var theme
    let summary: WidgetSummary
    let isStale: Bool

    var body: some View {
        Button(intent: RefreshUsageIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 36, height: 36)
                .background(buttonBackground, in: Circle())
                .overlay(alignment: .topTrailing) {
                    if isStale {
                        Circle()
                            .fill(theme.warning)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(theme.elevated, lineWidth: 1.5))
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isStale ? theme.warning : theme.accentMintStrong)
        .widgetAccentable()
        .accessibilityIdentifier("data-usage-refresh")
        .accessibilityLabel(isStale ? "데이터 사용량 새로고침, 업데이트 필요" : "데이터 사용량 새로고침")
        .accessibilityValue(refreshAccessibilityValue)
        .accessibilityHint("앱을 열지 않고 최신 사용량을 측정합니다")
    }

    private var buttonBackground: Color {
        renderingMode == .accented ? .primary.opacity(0.14) : theme.subtle
    }

    private var refreshAccessibilityValue: String {
        #if DEBUG
        "generatedAt=\(summary.generatedAt.timeIntervalSince1970);usedBytes=\(summary.usedBytes);periodStart=\(summary.periodStart.timeIntervalSince1970)"
        #else
        guard summary.hasRefreshTimestamp else { return "아직 갱신되지 않음" }
        return "마지막 갱신 \(summary.generatedAt.formatted(date: .omitted, time: .complete))"
        #endif
    }
}

private struct WidgetUpdateStatus: View {
    @Environment(\.dvTheme) private var theme
    let entry: UsageWidgetEntry

    var body: some View {
        HStack(spacing: 3) {
            if entry.isStale {
                Image(systemName: "exclamationmark.arrow.circlepath")
                Text("갱신 필요")
            } else if entry.summary.measurementQuality == .partial {
                Image(systemName: "exclamationmark.circle")
                Text("일부 구간 누락 가능")
            } else if entry.summary.measurementQuality == .estimated {
                Text("추정 ·")
                Text(entry.summary.generatedAt, style: .time)
            } else if entry.summary.hasRefreshTimestamp {
                Text(entry.summary.generatedAt, style: .time)
                Text("기준")
            }
        }
        .font(.system(size: 9))
        .foregroundStyle(entry.isStale ? theme.warning : theme.textSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

#if DEBUG
struct DataViewUsageWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DataViewWidgetEntryView(
                entry: UsageWidgetEntry(
                    date: .now,
                    summary: .preview,
                    isStale: false,
                    appearance: WidgetAppearancePreferences(
                        appearanceMode: .light,
                        visualTheme: .softPastel
                    )
                )
            )
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Soft Pastel · Light · Small")
            DataViewWidgetEntryView(
                entry: UsageWidgetEntry(
                    date: .now,
                    summary: .preview,
                    isStale: false,
                    appearance: WidgetAppearancePreferences(
                        appearanceMode: .dark,
                        visualTheme: .softPastel
                    )
                )
            )
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Soft Pastel · Dark · Medium")
        }
    }
}
#endif
