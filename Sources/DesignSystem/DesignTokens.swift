import SwiftUI
import UIKit

/// Resolved colors for one visual theme and one color scheme.
///
/// Views read this value through `EnvironmentValues.dvTheme`, so a theme
/// change updates the hierarchy without recreating navigation or app data.
struct DVThemePalette {
    let visualTheme: DataViewVisualTheme
    let colorScheme: ColorScheme

    let canvas: Color
    let elevated: Color
    let subtle: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let borderSoft: Color
    let accentMint: Color
    let accentMintStrong: Color
    let accentSky: Color
    let accentLavender: Color
    let accentPink: Color
    let accentYellow: Color
    let success: Color
    let warning: Color
    let danger: Color
    let track: Color

    var isDark: Bool { colorScheme == .dark }

    /// Contrast-safe variants for icons, charts, and gauges.
    ///
    /// The base accent colors intentionally stay pastel so they can continue
    /// to define soft surfaces. Foreground marks use these variants to retain
    /// at least 3:1 contrast against the theme's canvas and card surfaces.
    var accentMintForeground: Color {
        isDark ? accentMint : accentMintStrong
    }

    var accentSkyForeground: Color {
        guard !isDark else { return accentSky }
        switch visualTheme {
        case .classicBlue:
            return Color(hex: 0x1478A8)
        case .softPastel:
            return Color(hex: 0x2F6F9F)
        }
    }

    var accentLavenderForeground: Color {
        guard !isDark else { return accentLavender }
        switch visualTheme {
        case .classicBlue:
            return Color(hex: 0x167C4A)
        case .softPastel:
            return Color(hex: 0x6653A6)
        }
    }

    var accentPinkForeground: Color {
        guard !isDark else { return accentPink }
        switch visualTheme {
        case .classicBlue:
            return Color(hex: 0xE5484D)
        case .softPastel:
            return Color(hex: 0xA43A58)
        }
    }

    var accentYellowForeground: Color {
        isDark ? accentYellow : Color(hex: 0x8A5B00)
    }

    /// Foreground for a control filled with `accentMintStrong`.
    var onAccent: Color {
        switch visualTheme {
        case .classicBlue:
            return .white
        case .softPastel:
            return isDark ? Color(hex: 0x111525) : .white
        }
    }

    /// Foreground for destructive/error surfaces filled with `danger`.
    var onDanger: Color {
        switch visualTheme {
        case .classicBlue:
            return Color(hex: 0x11151C)
        case .softPastel:
            return isDark ? Color(hex: 0x111525) : .white
        }
    }

    var tintMint: Color {
        switch visualTheme {
        case .classicBlue:
            return accentMint.opacity(isDark ? 0.20 : 0.10)
        case .softPastel:
            return isDark ? accentMint.opacity(0.14) : Color(hex: 0xEAF9F5)
        }
    }

    var tintSky: Color {
        switch visualTheme {
        case .classicBlue:
            return accentSky.opacity(isDark ? 0.20 : 0.10)
        case .softPastel:
            return isDark ? accentSky.opacity(0.14) : Color(hex: 0xEDF7FF)
        }
    }

    var tintLavender: Color {
        switch visualTheme {
        case .classicBlue:
            return accentLavender.opacity(isDark ? 0.20 : 0.10)
        case .softPastel:
            return isDark ? accentLavender.opacity(0.14) : Color(hex: 0xF2EFFF)
        }
    }

    var tintPink: Color {
        switch visualTheme {
        case .classicBlue:
            return accentPink.opacity(isDark ? 0.20 : 0.10)
        case .softPastel:
            return isDark ? accentPink.opacity(0.14) : Color(hex: 0xFFF1F6)
        }
    }

    var cardShadow: Color {
        isDark ? .clear : Color(hex: 0x36415C, alpha: 0.08)
    }

    static func resolve(
        visualTheme: DataViewVisualTheme,
        colorScheme: ColorScheme
    ) -> DVThemePalette {
        switch visualTheme {
        case .classicBlue:
            return classicBlue(colorScheme: colorScheme)
        case .softPastel:
            return softPastel(colorScheme: colorScheme)
        }
    }

    static func resolve(
        visualTheme: DataViewVisualTheme,
        appearanceMode: DataViewAppearanceMode,
        systemColorScheme: ColorScheme
    ) -> DVThemePalette {
        let resolvedScheme: ColorScheme
        switch appearanceMode {
        case .system:
            resolvedScheme = systemColorScheme
        case .light:
            resolvedScheme = .light
        case .dark:
            resolvedScheme = .dark
        }
        return resolve(visualTheme: visualTheme, colorScheme: resolvedScheme)
    }

    private static func classicBlue(colorScheme: ColorScheme) -> DVThemePalette {
        let isDark = colorScheme == .dark
        return DVThemePalette(
            visualTheme: .classicBlue,
            colorScheme: colorScheme,
            canvas: Color(hex: isDark ? 0x08111D : 0xF4F8FC),
            elevated: Color(hex: isDark ? 0x101B28 : 0xFFFFFF),
            subtle: Color(hex: isDark ? 0x172433 : 0xEEF4FA),
            textPrimary: Color(hex: isDark ? 0xFFFFFF : 0x000000),
            textSecondary: Color(hex: isDark ? 0xEBEBF5 : 0x3C3C43, alpha: 0.60),
            textTertiary: Color(hex: isDark ? 0xAAB4C2 : 0x5F6875),
            borderSoft: Color(hex: isDark ? 0x344150 : 0xDCE4EC),
            accentMint: Color(hex: 0x2F80ED),
            accentMintStrong: Color(hex: 0x1769E0),
            accentSky: Color(hex: 0x45B8F5),
            accentLavender: Color(hex: 0x35C982),
            accentPink: Color(hex: 0xE5484D),
            accentYellow: Color(hex: 0xF5A524),
            success: Color(hex: isDark ? 0x35C982 : 0x167C4A),
            warning: Color(hex: isDark ? 0xF5A524 : 0x8A5B00),
            danger: Color(hex: 0xE5484D),
            track: Color(hex: isDark ? 0x344150 : 0xDCE4EC)
        )
    }

    private static func softPastel(colorScheme: ColorScheme) -> DVThemePalette {
        let isDark = colorScheme == .dark
        return DVThemePalette(
            visualTheme: .softPastel,
            colorScheme: colorScheme,
            canvas: Color(hex: isDark ? 0x111525 : 0xF7F9FF),
            elevated: Color(hex: isDark ? 0x1B2133 : 0xFFFFFF),
            subtle: Color(hex: isDark ? 0x232A40 : 0xEFF4FF),
            textPrimary: Color(hex: isDark ? 0xF5F7FF : 0x20263A),
            textSecondary: Color(hex: isDark ? 0xB9C1D7 : 0x66708A),
            textTertiary: Color(hex: isDark ? 0x8E98B2 : 0x68728B),
            borderSoft: Color(hex: isDark ? 0x303951 : 0xE4E9F5),
            accentMint: Color(hex: isDark ? 0x62C9B6 : 0x74D7C4),
            accentMintStrong: Color(hex: isDark ? 0x88E3D1 : 0x176B5B),
            accentSky: Color(hex: isDark ? 0x74BDF3 : 0xA8D8FF),
            accentLavender: Color(hex: isDark ? 0xA895F0 : 0xC3B5FA),
            accentPink: Color(hex: isDark ? 0xEAAAC3 : 0xF7C4D7),
            accentYellow: Color(hex: isDark ? 0xE9C875 : 0xFFE2A6),
            success: Color(hex: isDark ? 0x7BD8B7 : 0x2F7D64),
            warning: Color(hex: isDark ? 0xFFD47A : 0x8A5B00),
            danger: Color(hex: isDark ? 0xFF9AB5 : 0xA43A58),
            track: Color(hex: isDark ? 0x303951 : 0xE7ECF6)
        )
    }
}

private struct DVThemePaletteKey: EnvironmentKey {
    static var defaultValue: DVThemePalette {
        DVThemePalette.resolve(visualTheme: .classicBlue, colorScheme: .light)
    }
}

extension EnvironmentValues {
    var dvTheme: DVThemePalette {
        get { self[DVThemePaletteKey.self] }
        set { self[DVThemePaletteKey.self] = newValue }
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

    // Compatibility aliases for views that have not migrated to the palette
    // environment yet. New design-system code uses `EnvironmentValues.dvTheme`.
    static let dvBrandBlue = Color(hex: 0x2F80ED)
    static let dvBrandBlueStrong = Color(hex: 0x1769E0)
    static let dvBrandCyan = Color(hex: 0x45B8F5)
    static let dvWarning = Color(hex: 0xF5A524)
    static let dvDanger = Color(hex: 0xE5484D)

    static let dvBackground = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 8 / 255, green: 17 / 255, blue: 29 / 255, alpha: 1)
                : UIColor(red: 244 / 255, green: 248 / 255, blue: 252 / 255, alpha: 1)
        }
    )
    static let dvSurface = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 16 / 255, green: 27 / 255, blue: 40 / 255, alpha: 1)
                : .white
        }
    )
    static let dvSurfaceSecondary = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 23 / 255, green: 36 / 255, blue: 51 / 255, alpha: 1)
                : UIColor(red: 238 / 255, green: 244 / 255, blue: 250 / 255, alpha: 1)
        }
    )
    static let dvTrack = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 52 / 255, green: 65 / 255, blue: 80 / 255, alpha: 1)
                : UIColor(red: 220 / 255, green: 228 / 255, blue: 236 / 255, alpha: 1)
        }
    )
}

enum DVSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

enum DVRadius {
    static let small: CGFloat = 12
    static let card: CGFloat = 18
    static let large: CGFloat = 24
    static let button: CGFloat = 12
    static let pill: CGFloat = 999
}

struct DataViewThemeBackground: View {
    @Environment(\.dvTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            theme.canvas

            if !reduceTransparency {
                switch theme.visualTheme {
                case .classicBlue:
                    EmptyView()
                case .softPastel:
                    softPastelMesh
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var softPastelMesh: some View {
        ZStack {
            RadialGradient(
                colors: leadingMeshColors,
                center: .topLeading,
                startRadius: 16,
                endRadius: 260
            )
            RadialGradient(
                colors: trailingMeshColors,
                center: .bottomTrailing,
                startRadius: 24,
                endRadius: 300
            )
        }
    }

    private var leadingMeshColors: [Color] {
        if theme.isDark {
            return [theme.accentMint.opacity(0.14), .clear]
        }
        return [Color(hex: 0xDDF8F1).opacity(0.80), .clear]
    }

    private var trailingMeshColors: [Color] {
        if theme.isDark {
            return [theme.accentLavender.opacity(0.12), .clear]
        }
        return [Color(hex: 0xE9E4FF).opacity(0.70), .clear]
    }
}
