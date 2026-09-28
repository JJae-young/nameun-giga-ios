import SwiftUI

// Starter implementation. Map this type to the project's existing theme protocol.
struct SoftPastelTheme {
    struct Palette {
        let canvas: Color
        let elevated: Color
        let subtle: Color
        let textPrimary: Color
        let textSecondary: Color
        let textTertiary: Color
        let borderSoft: Color
    }

    static let light = Palette(
        canvas: Color(hex: 0xF7F9FF),
        elevated: Color(hex: 0xFFFFFF),
        subtle: Color(hex: 0xEFF4FF),
        textPrimary: Color(hex: 0x20263A),
        textSecondary: Color(hex: 0x66708A),
        textTertiary: Color(hex: 0x68728B),
        borderSoft: Color(hex: 0xE4E9F5)
    )

    static let dark = Palette(
        canvas: Color(hex: 0x111525),
        elevated: Color(hex: 0x1B2133),
        subtle: Color(hex: 0x232A40),
        textPrimary: Color(hex: 0xF5F7FF),
        textSecondary: Color(hex: 0xB9C1D7),
        textTertiary: Color(hex: 0x8E98B2),
        borderSoft: Color(hex: 0x303951)
    )

    enum Accent {
        static let mint = Color(hex: 0x74D7C4)
        static let mintStrong = Color(hex: 0x176B5B)
        static let sky = Color(hex: 0xA8D8FF)
        static let lavender = Color(hex: 0xC3B5FA)
        static let pink = Color(hex: 0xF7C4D7)
        static let yellow = Color(hex: 0xFFE2A6)
    }

    enum Surface {
        static let mint = Color(hex: 0xEAF9F5)
        static let sky = Color(hex: 0xEDF7FF)
        static let lavender = Color(hex: 0xF2EFFF)
        static let pink = Color(hex: 0xFFF1F6)
    }

    enum Semantic {
        static let success = Color(hex: 0x2F7D64)
        static let warning = Color(hex: 0x8A5B00)
        static let danger = Color(hex: 0xA43A58)
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 18
        static let large: CGFloat = 24
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct SoftPastelBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            SoftPastelTheme.light.canvas

            if !reduceTransparency {
                RadialGradient(
                    colors: [Color(hex: 0xDDF8F1).opacity(0.80), .clear],
                    center: .topLeading,
                    startRadius: 16,
                    endRadius: 260
                )
                RadialGradient(
                    colors: [Color(hex: 0xE9E4FF).opacity(0.70), .clear],
                    center: .bottomTrailing,
                    startRadius: 24,
                    endRadius: 300
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct DataUsageGauge: View {
    let used: Double
    let allowance: Double

    private var fraction: Double {
        guard allowance > 0, used.isFinite, allowance.isFinite else { return 0 }
        return min(max(used / allowance, 0), 1)
    }

    var body: some View {
        Gauge(value: fraction) {
            Text("이번 달 데이터")
        } currentValueLabel: {
            Text(fraction, format: .percent.precision(.fractionLength(0)))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(SoftPastelTheme.Accent.mint)
        .accessibilityValue(
            Text("\(fraction, format: .percent.precision(.fractionLength(0))) 사용")
        )
    }
}
