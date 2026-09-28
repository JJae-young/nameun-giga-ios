import SwiftUI

struct LogoMark: View {
    @Environment(\.dvTheme) private var theme

    var color: Color?
    var height: CGFloat = 28

    init(color: Color? = nil, height: CGFloat = 28) {
        self.color = color
        self.height = height
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: height * 0.16) {
            ForEach([0.42, 0.7, 1.0], id: \.self) { scale in
                RoundedRectangle(cornerRadius: height * 0.08)
                    .fill(color ?? theme.accentMintStrong)
                    .frame(width: height * 0.22, height: height * scale)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

struct UsageRing: View {
    @Environment(\.dvTheme) private var theme

    let progress: Double
    let primary: String
    let secondary: String
    var caption: String?
    var size: CGFloat = 220

    private var clampedProgress: Double { min(1, max(0, progress)) }
    private var lineWidth: CGFloat { min(13, max(8, size * 0.1)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        colors: ringColors,
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 5) {
                Text(primary)
                    .font(.system(size: size * 0.16, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(secondary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textSecondary)
                if let caption {
                    Text(caption)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accentMintStrong)
                        .monospacedDigit()
                }
            }
            .padding(size * 0.16)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("이번 달 데이터, \(secondary) \(primary), \(Int(clampedProgress * 100))퍼센트 사용")
    }

    private var ringColors: [Color] {
        switch theme.visualTheme {
        case .classicBlue:
            return [
                theme.accentSkyForeground,
                theme.accentMintForeground,
                theme.accentMintStrong
            ]
        case .softPastel:
            return [theme.accentMintForeground, theme.accentMintForeground]
        }
    }
}

struct MetricTile: View {
    @Environment(\.dvTheme) private var theme

    let icon: String
    let title: String
    let value: String
    var caption: String?
    var tint: Color?
    var surface: Color?

    init(
        icon: String,
        title: String,
        value: String,
        caption: String? = nil,
        tint: Color? = nil,
        surface: Color? = nil
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.caption = caption
        self.tint = tint
        self.surface = surface
    }

    var body: some View {
        let resolvedTint = tint ?? theme.accentSkyForeground

        VStack(alignment: .leading, spacing: DVSpacing.m) {
            HStack(spacing: DVSpacing.s) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(resolvedTint)
                    .frame(width: 30, height: 30)
                    .background(surface ?? resolvedTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .contentTransition(.numericText())
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .padding(DVSpacing.l)
        .dvCardStyle()
        .accessibilityElement(children: .combine)
    }
}

struct MeasurementStatusBadge: View {
    @Environment(\.dvTheme) private var theme

    let quality: MeasurementQuality

    private var label: String {
        switch quality {
        case .verified: "최근 측정 완료"
        case .partial: "일부 측정"
        case .estimated: "추정"
        case .unavailable: "기준 설정 중"
        }
    }

    private var icon: String {
        switch quality {
        case .verified: "checkmark.circle.fill"
        case .partial, .estimated: "exclamationmark.circle.fill"
        case .unavailable: "clock.fill"
        }
    }

    private var tint: Color {
        switch quality {
        case .verified: theme.success
        case .partial, .estimated: theme.warning
        case .unavailable: theme.textSecondary
        }
    }

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct SectionCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(DVSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dvCardStyle()
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.dvTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(theme.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                theme.accentMintStrong.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: DVRadius.button)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct DVCardStyle: ViewModifier {
    @Environment(\.dvTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast

    let radius: CGFloat
    let shadowed: Bool

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(theme.elevated)
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }
                .shadow(
                    color: shadowed ? theme.cardShadow : .clear,
                    radius: 12,
                    x: 0,
                    y: 8
                )
        }
    }

    private var borderColor: Color {
        if theme.isDark {
            return theme.borderSoft
        }
        if contrast == .increased {
            return theme.textSecondary.opacity(0.35)
        }
        return .clear
    }
}

extension View {
    func dvCardStyle(
        radius: CGFloat = DVRadius.card,
        shadowed: Bool = true
    ) -> some View {
        modifier(DVCardStyle(radius: radius, shadowed: shadowed))
    }
}
