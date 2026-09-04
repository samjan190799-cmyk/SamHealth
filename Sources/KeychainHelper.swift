import Foundation
import Security

// MARK: - Хелпер для безопасного и долговременного хранения в iOS Keychain
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    
    private let serviceName = "com.samvel.forma.security"
    
    private init() {}
    
    /// Сохранение булева флага в Keychain
    @discardableResult
    public func setBool(_ value: Bool, forKey key: String) -> Bool {
        let data = Data([value ? 1 : 0])
        return setData(data, forKey: key)
    }
    
    /// Чтение булева флага из Keychain
    public func getBool(forKey key: String) -> Bool {
        guard let data = getData(forKey: key), let firstByte = data.first else {
            return false
        }
        return firstByte == 1
    }
    
    /// Сохранение произвольных бинарных данных
    @discardableResult
    public func setData(_ data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        // Удаляем старую запись, если существовала
        SecItemDelete(query as CFDictionary)
        
        // Добавляем новую запись с флагом доступности после первой разблокировки
        var newAttributes = query
        newAttributes[kSecValueData as String] = data
        newAttributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        
        let status = SecItemAdd(newAttributes as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Получение данных по ключу
    public func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    /// Удаление ключа из Keychain
    @discardableResult
    public func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
