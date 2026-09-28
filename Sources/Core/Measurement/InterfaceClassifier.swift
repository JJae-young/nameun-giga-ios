import Foundation

enum InterfaceClassifier {
    /// `IFT_CELLULAR` from Darwin's public `<net/if_types.h>`.
    private static let cellularInterfaceType: UInt8 = 0xFF

    static func classify(
        _ name: String,
        interfaceType: UInt8? = nil
    ) -> InterfaceClassification {
        let normalized = name.lowercased()
        if normalized.hasPrefix("lo") { return .loopback }
        if normalized.hasPrefix("utun") || normalized.hasPrefix("ipsec") { return .vpn }
        if interfaceType == cellularInterfaceType { return .cellular }
        // Compatibility fallback for OS/device combinations that expose a
        // cellular interface without the public IFT_CELLULAR type marker.
        if normalized.hasPrefix("pdp_ip") { return .cellular }
        if normalized.hasPrefix("en") || normalized.hasPrefix("awdl") || normalized.hasPrefix("llw") { return .wifi }
        return .unknown
    }
}
