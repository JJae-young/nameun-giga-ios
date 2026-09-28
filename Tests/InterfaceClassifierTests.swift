import XCTest
@testable import DataView

final class InterfaceClassifierTests: XCTestCase {
    func testKnownInterfaceFamilies() {
        XCTAssertEqual(InterfaceClassifier.classify("pdp_ip0"), .cellular)
        XCTAssertEqual(InterfaceClassifier.classify("pdp_ip1"), .cellular)
        XCTAssertEqual(InterfaceClassifier.classify("en0"), .wifi)
        XCTAssertEqual(InterfaceClassifier.classify("utun2"), .vpn)
        XCTAssertEqual(InterfaceClassifier.classify("lo0"), .loopback)
        XCTAssertEqual(InterfaceClassifier.classify("future0"), .unknown)
    }

    func testPublicCellularInterfaceTypeTakesPriorityOverUnknownName() {
        XCTAssertEqual(InterfaceClassifier.classify("future0", interfaceType: 0xFF), .cellular)
    }

    func testTunnelNameIsNeverDoubleCountedAsCellular() {
        XCTAssertEqual(InterfaceClassifier.classify("utun2", interfaceType: 0xFF), .vpn)
    }

    func testSharingInterfacesAreUnclassifiedAndExcludedFromCellularTotals() {
        XCTAssertEqual(InterfaceClassifier.classify("bridge100"), .unknown)
        XCTAssertEqual(InterfaceClassifier.classify("ap1"), .unknown)
    }
}
