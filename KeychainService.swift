// KeychainService.swift
// Secure API key storage using macOS Keychain

import Security
import Foundation

struct KeychainService {
    static let account = "anthropic_api_key"
    static let service = "com.tecwisard.goalkeeper"

    static func save(_ key: String) {
        let data = Data(key.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    static var hasKey: Bool { load() != nil }
    
    static var selectedModel: String {
        get { UserDefaults.standard.string(forKey: "selectedModel") ?? "claude-haiku-4-5" }
        set { UserDefaults.standard.set(newValue, forKey: "selectedModel") }
    }
}
