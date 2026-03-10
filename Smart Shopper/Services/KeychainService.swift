//
//  KeychainService.swift
//  Smart Shopper
//
//  Thin wrapper around Security framework for storing OAuth tokens
//  and other secrets.  Used by InstacartService (Phase 2) and the
//  Google Tasks OAuth flow (Phase 3).
//

import Foundation
import Security

final class KeychainService {

    static let shared = KeychainService()
    private let service = Bundle.main.bundleIdentifier ?? "com.smartcart.app"

    private init() {}

    // MARK: - Save

    /// Stores `value` string under `key`.  Overwrites any existing entry.
    func save(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete existing item first to avoid duplicate-item errors.
        try? delete(key: key)

        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecValueData:        data,
            kSecAttrAccessible:   kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    // MARK: - Read

    /// Returns the string stored under `key`, or `nil` if not found.
    func read(key: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.readFailed(status) }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }
        return string
    }

    // MARK: - Delete

    func delete(key: String) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - KeychainError
extension KeychainService {
    enum KeychainError: LocalizedError {
        case encodingFailed
        case decodingFailed
        case saveFailed(OSStatus)
        case readFailed(OSStatus)
        case deleteFailed(OSStatus)

        var errorDescription: String? {
            switch self {
            case .encodingFailed:      return "Failed to encode value for Keychain."
            case .decodingFailed:      return "Failed to decode Keychain data."
            case .saveFailed(let s):   return "Keychain save error: \(s)"
            case .readFailed(let s):   return "Keychain read error: \(s)"
            case .deleteFailed(let s): return "Keychain delete error: \(s)"
            }
        }
    }
}

// MARK: - Token keys (centralised to avoid magic strings)
extension KeychainService {
    enum TokenKey {
        static let instacartAccessToken  = "instacart.access_token"
        static let instacartRefreshToken = "instacart.refresh_token"
        static let googleAccessToken     = "google.access_token"
        static let googleRefreshToken    = "google.refresh_token"
    }
}
