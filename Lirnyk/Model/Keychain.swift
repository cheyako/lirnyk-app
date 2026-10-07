import Foundation
import Security

protocol SecretStoring {
    func read(account: String) -> String?
    /// Writes `value`; `nil` or empty deletes the item.
    @discardableResult
    func write(_ value: String?, account: String) -> Bool
}

struct Keychain: SecretStoring {
    let service: String

    func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Updates in place (adds if missing), so a failed write never loses the existing key.
    @discardableResult
    func write(_ value: String?, account: String) -> Bool {
        let query = baseQuery(account: account)
        guard let value, !value.isEmpty else {
            let status = SecItemDelete(query as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        guard status == errSecItemNotFound else { return status == errSecSuccess }
        var item = query
        item[kSecValueData as String] = data
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
