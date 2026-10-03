import Foundation
import Security

/// Secure storage for API keys using the iOS Keychain.
/// No API keys are ever stored in plain text or hardcoded in the app.
@MainActor
final class SecureKeyStore: ObservableObject {

    private let service = "com.astraai.app"
    private let logger = AppLogger.shared

    // MARK: - API Key Storage

    func saveAPIKey(_ key: String, for providerId: String) {
        let account = "apikey_\(providerId)"
        save(key: key, account: account)
    }

    func loadAPIKey(for providerId: String) -> String? {
        let account = "apikey_\(providerId)"
        return load(account: account)
    }

    func deleteAPIKey(for providerId: String) {
        let account = "apikey_\(providerId)"
        delete(account: account)
    }

    // MARK: - Generic API Key Storage (for custom APIs)

    func saveCustomAPIKey(_ key: String, identifier: String) {
        let account = "custom_\(identifier)"
        save(key: key, account: account)
    }

    func loadCustomAPIKey(identifier: String) -> String? {
        let account = "custom_\(identifier)"
        return load(account: account)
    }

    func deleteCustomAPIKey(identifier: String) {
        let account = "custom_\(identifier)"
        delete(account: account)
    }

    // MARK: - Keychain Operations

    private func save(key: String, account: String) {
        let data = Data(key.utf8)

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            logger.error("Keychain save failed: \(status)")
        }
    }

    private func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
