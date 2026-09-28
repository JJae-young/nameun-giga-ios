import XCTest
@testable import DataView

final class DataAmountFormatterTests: XCTestCase {
    func testRemainingAmountsAlwaysShowTwoDecimalPlaces() {
        let locale = Locale(identifier: "ko_KR")
        for (bytes, expected): (Int64, String) in [
            (53_950_000_000, "53.95 GB"),
            (52_700_000_000, "52.70 GB"),
            (22_850_000_000, "22.85 GB"),
            (21_400_000_000, "21.40 GB"),
            (160 * DataBytes.gigabyte, "160.00 GB"),
            (DataBytes.gigabyte, "1.00 GB"),
            (999 * DataBytes.megabyte, "999.00 MB"),
            (DataBytes.terabyte, "1.00 TB"),
            (0, "0.00 MB"),
            (-1, "0.00 MB")
        ] {
            XCTAssertEqual(DataAmountFormatter.remainingString(from: bytes, locale: locale), expected)
        }
    }

    func testRemainingAmountsRoundAtTheThirdDecimalPlace() {
        let locale = Locale(identifier: "ko_KR")
        XCTAssertEqual(DataAmountFormatter.remainingString(from: 52_704_999_999, locale: locale), "52.70 GB")
        XCTAssertEqual(DataAmountFormatter.remainingString(from: 52_705_000_000, locale: locale), "52.71 GB")
        XCTAssertEqual(DataAmountFormatter.remainingString(from: 52_709_999_999, locale: locale), "52.71 GB")
        XCTAssertEqual(DataAmountFormatter.remainingString(from: 999_995_000_000, locale: locale), "1,000.00 GB")
    }

    func testRemainingAmountsRespectLocaleAndPreserveEditablePrecision() {
        let bytes: Int64 = 52_705_123_456
        for (identifier, expected) in [("ko_KR", "52.71 GB"), ("de_DE", "52,71 GB")] {
            let locale = Locale(identifier: identifier)
            XCTAssertEqual(DataAmountFormatter.remainingString(from: bytes, locale: locale), expected)
            let input = DataAmountFormatter.gigabyteInput(from: bytes, locale: locale)
            XCTAssertEqual(DataAmountFormatter.gigabytes(from: input, locale: locale), bytes)
        }
    }

    func testThousandsSeparatorsAreNotReadAsDecimalPoints() {
        XCTAssertEqual(DataAmountFormatter.gigabytes(from: "1,000", locale: Locale(identifier: "ko_KR")), 1_000 * DataBytes.gigabyte)
        XCTAssertEqual(DataAmountFormatter.gigabytes(from: "1.000,25", locale: Locale(identifier: "de_DE")), 1_000_250_000_000)
        XCTAssertEqual(DataAmountFormatter.gigabytes(from: "63,68", locale: Locale(identifier: "de_DE")), 63_680_000_000)
        XCTAssertNil(DataAmountFormatter.gigabytes(from: "63,68", locale: Locale(identifier: "ko_KR")))
    }

    func testEditableAmountsRoundTripWithoutLosingPrecision() {
        for locale in [Locale(identifier: "ko_KR"), Locale(identifier: "de_DE"), Locale(identifier: "fr_FR")] {
            for bytes: Int64 in [1, 63_680_000_000, 1_000_123_456_789, 10_000 * DataBytes.gigabyte] {
                let input = DataAmountFormatter.gigabyteInput(from: bytes, locale: locale)
                XCTAssertEqual(DataAmountFormatter.gigabytes(from: input, locale: locale), bytes)
            }
        }
    }

    func testZeroIsAllowedOnlyForUsage() {
        XCTAssertNil(DataAmountFormatter.gigabytes(from: "0"))
        XCTAssertEqual(DataAmountFormatter.gigabytes(from: "0", allowingZero: true), 0)
    }

    func testInvalidOrAmbiguousInputIsRejected() {
        for input in ["", "-1", "NaN", "inf", "1e3", "10,00", "1,000,00", "10000.1", "1.2345678901", "1 GB", "1.2.3"] {
            XCTAssertNil(DataAmountFormatter.gigabytes(from: input, locale: Locale(identifier: "en_US")), input)
        }
    }
}
