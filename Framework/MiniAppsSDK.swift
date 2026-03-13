
import Foundation
import UIKit
import ZIPFoundation

/// Main SDK class for fetching and displaying Mini Apps banners
@objc public class MiniAppsSDK: NSObject {
    
    /// Shared singleton instance of MiniAppsSDK
    @objc public static let shared = MiniAppsSDK()
    
    private var baseURL: String = ""
    private var appId: String = ""
    private var cachedMiniApps: [MiniApp] = []
    private var downloadingAppIds: Set<String> = [] // Track apps currently being downloaded
    private let downloadQueue = DispatchQueue(label: "com.miniapps.download", attributes: .concurrent)
    private let apiClient = APIClient.shared
    private let versionManager = VersionManager.shared
    private let downloadManager = DownloadManager.shared
    private let storageManager = StorageManager.shared
    private let metricsReporter = MetricsReporter.shared
    private let permissionManager = PermissionManager.shared
    
    private override init() {
        super.init()
    }
    
    /// Initializes the SDK with base URL and app ID
    /// - Parameters:
    ///   - baseURL: The base URL (e.g., "https://csdpdev-api.d21.co.in")
    ///   - appId: The application identifier
    @objc public func initialize(baseURL: String, appId: String) {
        self.baseURL = baseURL
        self.appId = appId
        apiClient.setBaseURL(baseURL)
        metricsReporter.setBaseURL(baseURL)
        
        // Auto-detect app version from Info.plist
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            apiClient.setSuperAppVersion(appVersion)
            metricsReporter.setSuperAppVersion(appVersion)
            print("MiniAppsSDK: Auto-detected app version from Info.plist: \(appVersion)")
        } else {
            // If not found in Info.plist, check CFBundleVersion as fallback
            if let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                apiClient.setSuperAppVersion(buildVersion)
                metricsReporter.setSuperAppVersion(buildVersion)
                print("MiniAppsSDK: Using CFBundleVersion as app version: \(buildVersion)")
            } else {
                // Default fallback - but this will likely be rejected by API
                print("MiniAppsSDK: ⚠️ WARNING: Could not detect app version from Info.plist")
                print("MiniAppsSDK: ⚠️ Using default version: 1.0.0 (API may reject this)")
                print("MiniAppsSDK: ⚠️ Set CFBundleShortVersionString in Info.plist or call setSuperAppVersion() manually")
            }
        }
    }
    
    /// Set the super app version manually
    /// - Parameter version: The super app version (e.g., "2.0.0")
    /// Use this if you need to override the auto-detected version or if the API requires a higher version
    @objc public func setSuperAppVersion(_ version: String) {
        apiClient.setSuperAppVersion(version)
        metricsReporter.setSuperAppVersion(version)
        print("MiniAppsSDK: Super app version manually set to: \(version)")
    }
    
    /// Fetches mini apps banners and returns a configured view
    /// - Parameters:
    ///   - width: Desired width for the banners (not used in current implementation)
    ///   - height: Desired height for the banners (not used in current implementation)
    ///   - completion: Completion handler that returns a UIView or an Error
    @objc public func fetchMiniAppsWithView(
        width: Int,
        height: Int,
        completion: @escaping (UIView?, Error?) -> Void
    ) {
        fetchMiniApps { [weak self] result in
            switch result {
            case .success(let miniApps):
                DispatchQueue.main.async {
                    let view = MiniAppsBannerView()
                    view.configure(with: miniApps)
                    view.onBannerTapped = { [weak self] miniApp in
                        self?.launchMiniApp(miniApp)
                    }
                    completion(view, nil)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    /// Fetches mini apps list and automatically downloads each mini app
    /// - Parameter completion: Completion handler that returns a Result containing an array of MiniApp or an Error
    public func fetchMiniApps(completion: @escaping (Result<[MiniApp], Error>) -> Void) {
        guard !baseURL.isEmpty, !appId.isEmpty else {
            completion(.failure(NSError(domain: "MiniAppsSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "SDK not initialized. Please call initialize(baseURL:appId:) first."])))
            return
        }
        
        // If we have cached apps, return them immediately
        if !cachedMiniApps.isEmpty {
            completion(.success(cachedMiniApps))
            // Still refresh in background
            refreshMiniApps()
            return
        }
        
        // Fetch from API
        apiClient.fetchMiniApps(appId: appId) { [weak self] result in
            switch result {
            case .success(let miniApps):
                // Cache the mini apps
                self?.cachedMiniApps = miniApps
                completion(.success(miniApps))
                
                // Automatically download each mini app in background
                self?.downloadAllMiniApps(miniApps)
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Refresh mini apps list (internal use)
    private func refreshMiniApps() {
        apiClient.fetchMiniApps(appId: appId) { [weak self] result in
            if case .success(let miniApps) = result {
                self?.cachedMiniApps = miniApps
                self?.downloadAllMiniApps(miniApps)
            }
        }
    }
    
    /// Download all mini apps in background
    private func downloadAllMiniApps(_ miniApps: [MiniApp]) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.processMiniApps(miniApps)
        }
    }
    
    /// Process each mini app: check version and download if needed
    private func processMiniApps(_ miniApps: [MiniApp]) {
        for miniApp in miniApps {
            processMiniApp(miniApp)
        }
    }
    
    /// Process a single mini app - download if needed
    private func processMiniApp(_ miniApp: MiniApp) {
        let storedVersion = versionManager.getStoredVersion(for: miniApp.appId)
        let needsUpdate = versionManager.needsUpdate(
            storedVersion: storedVersion,
            latestVersion: miniApp.latestVersion
        )
        
        // Check if ZIP exists or needs update
        let zipExists = storageManager.zipExists(for: miniApp.appId)
        
        print("MiniAppsSDK: ──────────────────────────────────────────────")
        print("MiniAppsSDK: Processing: \(miniApp.appId)")
        print("MiniAppsSDK:   Name: \(miniApp.name)")
        print("MiniAppsSDK:   Stored Version: \(storedVersion ?? "none")")
        print("MiniAppsSDK:   Latest Version: \(miniApp.latestVersion)")
        print("MiniAppsSDK:   ZIP Exists: \(zipExists)")
        print("MiniAppsSDK:   Needs Update: \(needsUpdate)")
        
        if !zipExists || needsUpdate {
            // Check if this app is already being downloaded
            var shouldDownload = false
            downloadQueue.sync(flags: .barrier) {
                if !self.downloadingAppIds.contains(miniApp.appId) {
                    self.downloadingAppIds.insert(miniApp.appId)
                    shouldDownload = true
                }
            }
            
            guard shouldDownload else {
                print("MiniAppsSDK: ⚠️ Skipping \(miniApp.appId) - download already in progress")
                print("MiniAppsSDK: ──────────────────────────────────────────────")
                return
            }
            
            print("MiniAppsSDK: Starting download for \(miniApp.appId)...")
            
            // Get download token from API to get dynamic download URL
            apiClient.getDownloadToken(
                appId: miniApp.appId,
                currentVersion: storedVersion
            ) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let tokenData):
                    print("MiniAppsSDK: ✓ Download token received for \(miniApp.appId)")
                    print("MiniAppsSDK:   Download URL: \(tokenData.downloadUrl)")
                    print("MiniAppsSDK:   Checksum length: \(tokenData.checksum.count) characters")
                    
                    // Construct download URL - handle both full URL and relative path
                    var downloadURLString: String
                    if tokenData.downloadUrl.hasPrefix("http://") || tokenData.downloadUrl.hasPrefix("https://") {
                        // Already a full URL
                        downloadURLString = tokenData.downloadUrl
                    } else {
                        // Relative path, prepend base URL
                        downloadURLString = self.baseURL + tokenData.downloadUrl
                    }
                    
                    guard let downloadURL = URL(string: downloadURLString) else {
                        print("MiniAppsSDK: ✗✗✗ FAILED: \(miniApp.appId)")
                        print("MiniAppsSDK: ✗ Reason: Invalid download URL: \(downloadURLString)")
                        // Remove from downloading set
                        self.downloadQueue.async(flags: .barrier) {
                            self.downloadingAppIds.remove(miniApp.appId)
                        }
                        return
                    }
                    
                    print("MiniAppsSDK:   Final Download URL: \(downloadURLString)")
                    
                    // Download and extract - metrics are reported inside DownloadManager
                    self.downloadManager.downloadAndExtract(
                        appId: miniApp.appId,
                        downloadURL: downloadURL,
                        checksum: tokenData.checksum,
                        version: miniApp.latestVersion
                    ) { result in
                        // Remove from downloading set when done
                        self.downloadQueue.async(flags: .barrier) {
                            self.downloadingAppIds.remove(miniApp.appId)
                        }
                        
                        switch result {
                        case .success:
                            print("MiniAppsSDK: ✓✓✓ SUCCESS: \(miniApp.appId) downloaded and extracted successfully ✓✓✓")
                        case .failure(let error):
                            print("MiniAppsSDK: ✗✗✗ FAILED: \(miniApp.appId)")
                            print("MiniAppsSDK: ✗ Error Type: \(type(of: error))")
                            print("MiniAppsSDK: ✗ Error Description: \(error.localizedDescription)")
                            
                            // Detailed error information
                            if let nsError = error as? NSError {
                                print("MiniAppsSDK: ✗ Error Domain: \(nsError.domain)")
                                print("MiniAppsSDK: ✗ Error Code: \(nsError.code)")
                                if let userInfo = nsError.userInfo as? [String: Any], !userInfo.isEmpty {
                                    print("MiniAppsSDK: ✗ Error UserInfo:")
                                    for (key, value) in userInfo {
                                        print("MiniAppsSDK:     \(key): \(value)")
                                    }
                                }
                            }
                            
                            // Check for specific error types
                            if let archiveError = error as? Archive.ArchiveError {
                                print("MiniAppsSDK: ✗ Archive Error Details:")
                                print("MiniAppsSDK:     This is a ZIP extraction error")
                            }
                            
                            print("MiniAppsSDK: ──────────────────────────────────────────────")
                        }
                    }
                    
                case .failure(let error):
                    // Remove from downloading set on failure
                    self.downloadQueue.async(flags: .barrier) {
                        self.downloadingAppIds.remove(miniApp.appId)
                    }
                    
                    print("MiniAppsSDK: ✗✗✗ FAILED: \(miniApp.appId)")
                    print("MiniAppsSDK: ✗ Reason: Failed to get download token")
                    print("MiniAppsSDK: ✗ Error Type: \(type(of: error))")
                    print("MiniAppsSDK: ✗ Error Description: \(error.localizedDescription)")
                    
                    if let nsError = error as? NSError {
                        print("MiniAppsSDK: ✗ Error Domain: \(nsError.domain)")
                        print("MiniAppsSDK: ✗ Error Code: \(nsError.code)")
                        if let userInfo = nsError.userInfo as? [String: Any], !userInfo.isEmpty {
                            print("MiniAppsSDK: ✗ Error UserInfo: \(userInfo)")
                        }
                    }
                    print("MiniAppsSDK: ──────────────────────────────────────────────")
                }
            }
        } else {
            print("MiniAppsSDK: ✓ Skipping \(miniApp.appId) - already up to date")
            print("MiniAppsSDK: ──────────────────────────────────────────────")
        }
    }
    
    /// Launch a mini app
    private func launchMiniApp(_ miniApp: MiniApp) {
        // Request permissions before launching
        permissionManager.requestPermissions(miniApp.permissions) { [weak self] granted in
            guard let self = self else { return }
            
            if granted {
                DispatchQueue.main.async {
                    guard let topViewController = self.getTopViewController() else {
                        print("MiniAppsSDK: Could not find top view controller")
                        return
                    }
                    
                    let viewController = MiniAppViewController(
                        appId: miniApp.appId,
                        version: miniApp.latestVersion
                    )
                    
                    // Title is set to appId in MiniAppViewController.setupNavigationBar()
                    
                    // Set modal presentation style to full screen
                    viewController.modalPresentationStyle = .fullScreen
                    
                    let navController = UINavigationController(rootViewController: viewController)
                    navController.modalPresentationStyle = .fullScreen
                    topViewController.present(navController, animated: true)
                }
            } else {
                print("MiniAppsSDK: Permissions not granted for \(miniApp.appId)")
            }
        }
    }
    
    /// Get the top most view controller
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        
        if let navController = topViewController as? UINavigationController {
            return navController.topViewController ?? navController
        }
        
        return topViewController
    }
}
