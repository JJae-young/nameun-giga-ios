import SwiftUI
import UIKit
import XCTest
@testable import DataView

final class WidgetAppearancePreferencesStoreTests: XCTestCase {
    func testPreferencesRoundTripPreservesIndependentSelections() throws {
        let preferences = WidgetAppearancePreferences(
            appearanceMode: .dark,
            visualTheme: .softPastel
        )

        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(WidgetAppearancePreferences.self, from: data)

        XCTAssertEqual(decoded, preferences)
    }

    func testUnknownAndMalformedFieldsRecoverIndependently() throws {
        let data = try XCTUnwrap(
            """
            {
              "schemaVersion": "invalid",
              "appearanceMode": "futureAppearance",
              "visualTheme": "futureTheme"
            }
            """.data(using: .utf8)
        )

        let decoded = try JSONDecoder().decode(WidgetAppearancePreferences.self, from: data)

        XCTAssertEqual(decoded, .defaultValue)
    }

    func testMissingFieldUsesDefaultWithoutDiscardingKnownField() throws {
        let data = try XCTUnwrap(
            """
            {
              "appearanceMode": "dark"
            }
            """.data(using: .utf8)
        )

        let decoded = try JSONDecoder().decode(WidgetAppearancePreferences.self, from: data)

        XCTAssertEqual(decoded.appearanceMode, .dark)
        XCTAssertEqual(decoded.visualTheme, .classicBlue)
        XCTAssertEqual(decoded.schemaVersion, WidgetAppearancePreferences.currentSchemaVersion)
    }

    func testSaveWritesAppGroupAndKeychainCopies() throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        let preferences = WidgetAppearancePreferences(
            appearanceMode: .light,
            visualTheme: .softPastel
        )

        try fixture.store.save(preferences)

        let appGroupData = try XCTUnwrap(
            fixture.defaults.data(forKey: WidgetAppearancePreferencesStore.preferencesKey)
        )
        XCTAssertEqual(
            try JSONDecoder().decode(WidgetAppearancePreferences.self, from: appGroupData),
            preferences
        )
        XCTAssertEqual(
            try fixture.keychain.decodedPreferences(),
            preferences
        )
    }

    func testLoadPrefersValidAppGroupValue() throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        let appGroupValue = WidgetAppearancePreferences(
            appearanceMode: .dark,
            visualTheme: .classicBlue
        )
        let keychainValue = WidgetAppearancePreferences(
            appearanceMode: .light,
            visualTheme: .softPastel
        )
        fixture.defaults.set(
            try JSONEncoder().encode(appGroupValue),
            forKey: WidgetAppearancePreferencesStore.preferencesKey
        )
        fixture.keychain.data = try JSONEncoder().encode(keychainValue)

        XCTAssertEqual(fixture.store.load(), appGroupValue)
    }

    func testCorruptAppGroupValueFallsBackToKeychain() throws {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        let keychainValue = WidgetAppearancePreferences(
            appearanceMode: .dark,
            visualTheme: .softPastel
        )
        fixture.defaults.set(
            Data("not-json".utf8),
            forKey: WidgetAppearancePreferencesStore.preferencesKey
        )
        fixture.keychain.data = try JSONEncoder().encode(keychainValue)

        XCTAssertEqual(fixture.store.load(), keychainValue)
    }

    func testCorruptCopiesReturnSafeDefault() {
        let fixture = makeFixture()
        defer { fixture.cleanup() }
        fixture.defaults.set(
            Data("not-json".utf8),
            forKey: WidgetAppearancePreferencesStore.preferencesKey
        )
        fixture.keychain.data = Data([0xFF, 0x00, 0x01])

        XCTAssertEqual(fixture.store.load(), .defaultValue)
    }

    func testForegroundAccentTintsMeetNonTextContrastMinimum() throws {
        for visualTheme in DataViewVisualTheme.allCases {
            for colorScheme in [ColorScheme.light, .dark] {
                let palette = DVThemePalette.resolve(
                    visualTheme: visualTheme,
                    colorScheme: colorScheme
                )
                let foregrounds = [
                    ("mint", palette.accentMintForeground),
                    ("sky", palette.accentSkyForeground),
                    ("lavender", palette.accentLavenderForeground),
                    ("pink", palette.accentPinkForeground),
                    ("yellow", palette.accentYellowForeground)
                ]
                let coreSurfaces = [
                    ("canvas", palette.canvas),
                    ("elevated", palette.elevated),
                    ("subtle", palette.subtle)
                ]

                for (foregroundName, foreground) in foregrounds {
                    for (surfaceName, surface) in coreSurfaces {
                        let ratio = try contrastRatio(
                            foreground,
                            surface,
                            over: palette.elevated,
                            colorScheme: colorScheme
                        )
                        XCTAssertGreaterThanOrEqual(
                            ratio,
                            3,
                            "\(visualTheme.rawValue) \(colorScheme) \(foregroundName) on \(surfaceName) was \(ratio):1"
                        )
                    }
                }

                if colorScheme == .light {
                    let tintedPairs = [
                        ("mint", palette.accentMintForeground, palette.tintMint),
                        ("sky", palette.accentSkyForeground, palette.tintSky),
                        ("lavender", palette.accentLavenderForeground, palette.tintLavender),
                        ("pink", palette.accentPinkForeground, palette.tintPink)
                    ]
                    for (name, foreground, surface) in tintedPairs {
                        let ratio = try contrastRatio(
                            foreground,
                            surface,
                            over: palette.elevated,
                            colorScheme: colorScheme
                        )
                        XCTAssertGreaterThanOrEqual(
                            ratio,
                            3,
                            "\(visualTheme.rawValue) \(name) foreground on tinted surface was \(ratio):1"
                        )
                    }
                }
            }
        }
    }

    private func makeFixture() -> Fixture {
        let suiteName = "WidgetAppearancePreferencesStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let keychain = InMemoryWidgetAppearancePreferencesKeychain()
        let store = WidgetAppearancePreferencesStore(
            defaults: defaults,
            keychain: keychain
        )
        return Fixture(
            suiteName: suiteName,
            defaults: defaults,
            keychain: keychain,
            store: store
        )
    }

    private func contrastRatio(
        _ first: Color,
        _ second: Color,
        colorScheme: ColorScheme
    ) throws -> CGFloat {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let traits = UITraitCollection(userInterfaceStyle: style)
        let firstLuminance = try relativeLuminance(first, traits: traits)
        let secondLuminance = try relativeLuminance(second, traits: traits)
        return (max(firstLuminance, secondLuminance) + 0.05)
            / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private func contrastRatio(
        _ foreground: Color,
        _ overlay: Color,
        over base: Color,
        colorScheme: ColorScheme
    ) throws -> CGFloat {
        let style: UIUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        let traits = UITraitCollection(userInterfaceStyle: style)
        let foregroundComponents = try resolvedComponents(foreground, traits: traits)
        let overlayComponents = try resolvedComponents(overlay, traits: traits)
        let baseComponents = try resolvedComponents(base, traits: traits)
        let backgroundComponents = composited(overlayComponents, over: baseComponents)
        let visibleForeground = composited(foregroundComponents, over: backgroundComponents)
        let foregroundLuminance = relativeLuminance(visibleForeground)
        let backgroundLuminance = relativeLuminance(backgroundComponents)
        return (max(foregroundLuminance, backgroundLuminance) + 0.05)
            / (min(foregroundLuminance, backgroundLuminance) + 0.05)
    }

    private func relativeLuminance(
        _ color: Color,
        traits: UITraitCollection
    ) throws -> CGFloat {
        relativeLuminance(try resolvedComponents(color, traits: traits))
    }

    private typealias RGBA = (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)

    private func resolvedComponents(
        _ color: Color,
        traits: UITraitCollection
    ) throws -> RGBA {
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            throw XCTSkip("Unable to resolve a theme color in the test color space")
        }
        return (red, green, blue, alpha)
    }

    private func composited(_ foreground: RGBA, over background: RGBA) -> RGBA {
        let alpha = foreground.alpha + background.alpha * (1 - foreground.alpha)
        guard alpha > 0 else { return (0, 0, 0, 0) }
        return (
            (foreground.red * foreground.alpha
                + background.red * background.alpha * (1 - foreground.alpha)) / alpha,
            (foreground.green * foreground.alpha
                + background.green * background.alpha * (1 - foreground.alpha)) / alpha,
            (foreground.blue * foreground.alpha
                + background.blue * background.alpha * (1 - foreground.alpha)) / alpha,
            alpha
        )
    }

    private func relativeLuminance(_ color: RGBA) -> CGFloat {
        func linearized(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearized(color.red)
            + 0.7152 * linearized(color.green)
            + 0.0722 * linearized(color.blue)
    }
}

private struct Fixture {
    let suiteName: String
    let defaults: UserDefaults
    let keychain: InMemoryWidgetAppearancePreferencesKeychain
    let store: WidgetAppearancePreferencesStore

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class InMemoryWidgetAppearancePreferencesKeychain:
    WidgetAppearancePreferencesKeychainStoring {
    var data: Data?

    func save(_ data: Data) throws {
        self.data = data
    }

    func load() -> Data? {
        data
    }

    func decodedPreferences() throws -> WidgetAppearancePreferences {
        let data = try XCTUnwrap(data)
        return try JSONDecoder().decode(WidgetAppearancePreferences.self, from: data)
    }
}
