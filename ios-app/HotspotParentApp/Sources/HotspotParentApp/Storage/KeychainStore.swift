import Foundation

#if canImport(Security)
import Security
#endif

public enum KeychainStore {
  public enum KeychainError: Error, CustomStringConvertible {
    case unavailable
    case unexpectedStatus(OSStatus)
    case decodingFailed

    public var description: String {
      switch self {
        case .unavailable: return "keychainUnavailable"
        case .unexpectedStatus(let s): return "keychainStatus(\(s))"
        case .decodingFailed: return "keychainDecodingFailed"
      }
    }
  }

  private static let service = "com.bazapps.hotspotparent"

  /// Store a codable value as a single generic password item.
  public static func setCodable<T: Codable>(_ value: T?, account: String) throws {
    #if !canImport(Security)
    throw KeychainError.unavailable
    #else
    let data: Data?
    if let value {
      data = try JSONEncoder().encode(value)
    } else {
      data = nil
    }

    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    if let data {
      // Upsert.
      let attrs: [String: Any] = [kSecValueData as String: data]
      let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
      if status == errSecItemNotFound {
        query[kSecValueData as String] = data
        // Accessibility: after first unlock, good for background App Intents.
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
      } else if status != errSecSuccess {
        throw KeychainError.unexpectedStatus(status)
      }
    } else {
      // Delete
      SecItemDelete(query as CFDictionary)
    }
    #endif
  }

  public static func getCodable<T: Codable>(_ type: T.Type, account: String) throws -> T? {
    #if !canImport(Security)
    throw KeychainError.unavailable
    #else
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
      return nil
    }
    guard status == errSecSuccess else {
      throw KeychainError.unexpectedStatus(status)
    }
    guard let data = item as? Data else {
      throw KeychainError.decodingFailed
    }
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw KeychainError.decodingFailed
    }
    #endif
  }
}
