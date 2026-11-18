import Foundation
import Security

/// Small values that must survive deleting and reinstalling the app: scan credits someone paid for,
/// whether the free scan was used, and the random per-install id the scan service uses for daily limits.
/// Kept in the Keychain on this device only (not synced, not in backups to other phones).
enum KeychainValue {
    private static let service = "com.christophergates.roomprint.scans"

    static func string(_ key: String) -> String? {
        var query = base(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func int(_ key: String) -> Int? {
        string(key).flatMap { Int($0) }
    }

    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query = base(key)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            _ = SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func set(_ value: Int, for key: String) {
        set(String(value), for: key)
    }

    private static func base(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }
}
