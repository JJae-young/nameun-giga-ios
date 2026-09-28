import Foundation
import Security

struct WidgetAppearancePreferencesStore {
    static let appGroup = "group.com.edward.DataView"
    static let preferencesKey = "widgetAppearancePreferences.v1"

    fileprivate static let keychainService = "com.edward.DataView.widget-appearance-preferences"
    fileprivate static let keychainAccount = "current-v1"
    private static let keychainGroupInfoKey = "DataViewSharedKeychainGroup"

    private let defaults: UserDefaults?
    private let keychain: any WidgetAppearancePreferencesKeychainStoring

    init() {
        self.defaults = UserDefaults(suiteName: Self.appGroup)
        self.keychain = SystemWidgetAppearancePreferencesKeychain(
            accessGroup: Bundle.main.object(
                forInfoDictionaryKey: Self.keychainGroupInfoKey
            ) as? String
        )
    }

    init(
        defaults: UserDefaults?,
        keychain: any WidgetAppearancePreferencesKeychainStoring
    ) {
        self.defaults = defaults
        self.keychain = keychain
    }

    func save(_ preferences: WidgetAppearancePreferences) throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(preferences)
        } catch {
            throw MeasurementError.storageFailed
        }

        // App Groups are the primary sharing mechanism for distributed builds.
        defaults?.set(data, forKey: Self.preferencesKey)

        // Personal Team provisioning doesn't support App Groups. Only debug
        // builds keep an independent shared Keychain copy for device testing.
        #if DEBUG
        try keychain.save(data)
        #endif
    }

    func load() -> WidgetAppearancePreferences {
        if let data = defaults?.data(forKey: Self.preferencesKey),
           let preferences = Self.decode(data) {
            return preferences
        }

        #if DEBUG
        if let data = keychain.load(),
           let preferences = Self.decode(data) {
            return preferences
        }
        #endif

        return .defaultValue
    }

    private static func decode(_ data: Data) -> WidgetAppearancePreferences? {
        try? JSONDecoder().decode(WidgetAppearancePreferences.self, from: data)
    }
}

protocol WidgetAppearancePreferencesKeychainStoring {
    func save(_ data: Data) throws
    func load() -> Data?
}

private struct SystemWidgetAppearancePreferencesKeychain: WidgetAppearancePreferencesKeychainStoring {
    let accessGroup: String?

    func save(_ data: Data) throws {
        guard let query = baseQuery else {
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

    func load() -> Data? {
        guard var query = baseQuery else { return nil }
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    private var baseQuery: [CFString: Any]? {
        guard let accessGroup, !accessGroup.isEmpty else { return nil }
        return [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: WidgetAppearancePreferencesStore.keychainService,
            kSecAttrAccount: WidgetAppearancePreferencesStore.keychainAccount,
            kSecAttrAccessGroup: accessGroup
        ]
    }
}
