import Foundation
import Security

enum WidgetSummaryStore {
    static let appGroup = "group.com.edward.DataView"
    static let summaryKey = "widgetSummary"

    private static let keychainService = "com.edward.DataView.widget-summary"
    private static let keychainAccount = "latest"
    private static let keychainGroupInfoKey = "DataViewSharedKeychainGroup"

    static func save(_ summary: WidgetSummary) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(summary)
        } catch {
            throw MeasurementError.storageFailed
        }

        // App Group is the primary store for App Store/TestFlight builds.
        UserDefaults(suiteName: appGroup)?.set(data, forKey: summaryKey)

        // Personal Team debug builds cannot provision App Groups, so only
        // development builds keep a shared Keychain fallback.
        #if DEBUG
        try saveToKeychain(data)
        #endif
    }

    static func load() -> WidgetSummary? {
        if let data = UserDefaults(suiteName: appGroup)?.data(forKey: summaryKey),
           let summary = try? JSONDecoder().decode(WidgetSummary.self, from: data) {
            return summary
        }

        #if DEBUG
        guard let data = loadFromKeychain() else { return nil }
        return try? JSONDecoder().decode(WidgetSummary.self, from: data)
        #else
        return nil
        #endif
    }

    private static var keychainAccessGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: keychainGroupInfoKey) as? String
    }

    private static func baseKeychainQuery() -> [CFString: Any]? {
        guard let keychainAccessGroup, !keychainAccessGroup.isEmpty else { return nil }
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecAttrAccessGroup: keychainAccessGroup
        ]
    }

    private static func saveToKeychain(_ data: Data) throws {
        guard let query = baseKeychainQuery() else {
            throw MeasurementError.storageFailed
        }

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw MeasurementError.storageFailed
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecDuplicateItem,
           SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecSuccess {
            return
        }
        guard addStatus == errSecSuccess else {
            throw MeasurementError.storageFailed
        }
    }

    private static func loadFromKeychain() -> Data? {
        guard var query = baseKeychainQuery() else { return nil }
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }
}
