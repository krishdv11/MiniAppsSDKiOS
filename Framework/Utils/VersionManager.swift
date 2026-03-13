
import Foundation

/// Internal manager for handling mini app version storage
internal class VersionManager {
    
    static let shared = VersionManager()
    
    private let userDefaults = UserDefaults.standard
    private let versionKeyPrefix = "miniapp_version_"
    
    private init() {}
    
    /// Get stored version for a mini app
    func getStoredVersion(for appId: String) -> String? {
        let key = versionKeyPrefix + appId
        return userDefaults.string(forKey: key)
    }
    
    /// Store version for a mini app
    func storeVersion(_ version: String, for appId: String) {
        let key = versionKeyPrefix + appId
        userDefaults.set(version, forKey: key)
    }
    
    /// Check if version needs update
    func needsUpdate(storedVersion: String?, latestVersion: String) -> Bool {
        guard let stored = storedVersion else {
            return true // No stored version, needs download
        }
        return stored != latestVersion
    }
}
