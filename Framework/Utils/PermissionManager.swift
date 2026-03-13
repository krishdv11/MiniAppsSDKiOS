
import Foundation
import CoreLocation
import UIKit

/// Internal manager for handling mini app permissions
internal class PermissionManager: NSObject {
    
    static let shared = PermissionManager()
    
    private var locationManager: CLLocationManager?
    private var permissionCompletion: ((Bool) -> Void)?
    
    private override init() {
        super.init()
    }
    
    /// Request permissions for a mini app
    /// - Parameters:
    ///   - permissions: Array of permission strings (e.g., ["location", "storage"])
    ///   - completion: Completion handler with granted status
    /// 
    /// Note: Currently only "location" permission is handled.
    /// "storage" permission is ignored as WKWebView provides localStorage/IndexedDB automatically
    /// and mini apps are stored in Documents folder which doesn't require special permissions.
    func requestPermissions(_ permissions: [String]?, completion: @escaping (Bool) -> Void) {
        guard let permissions = permissions, !permissions.isEmpty else {
            // No permissions required
            completion(true)
            return
        }
        
        // Filter out "storage" - it doesn't require iOS permission
        // WKWebView provides localStorage/IndexedDB automatically
        // Mini apps are stored in Documents folder (no permission needed)
        let permissionsNeedingRequest = permissions.filter { $0 != "storage" }
        
        guard !permissionsNeedingRequest.isEmpty else {
            // Only "storage" permission, which doesn't need request
            completion(true)
            return
        }
        
        // Check if location permission is required
        if permissionsNeedingRequest.contains("location") {
            requestLocationPermission { [weak self] locationGranted in
                if locationGranted {
                    // All permissions granted (currently only location is implemented)
                    completion(true)
                } else {
                    completion(false)
                }
            }
        } else {
            // Other permissions not yet implemented, but allow access for now
            // You can add more permission types here in the future if needed
            completion(true)
        }
    }
    
    /// Request location permission
    private func requestLocationPermission(completion: @escaping (Bool) -> Void) {
        self.permissionCompletion = completion
        
        let status = CLLocationManager.authorizationStatus()
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // Already authorized
            completion(true)
            
        case .notDetermined:
            // Request permission
            locationManager = CLLocationManager()
            locationManager?.delegate = self
            locationManager?.requestWhenInUseAuthorization()
            
        case .denied, .restricted:
            // Permission denied - show alert
            DispatchQueue.main.async {
                self.showLocationPermissionAlert()
                completion(false)
            }
            
        @unknown default:
            completion(false)
        }
    }
    
    /// Show alert when location permission is denied
    private func showLocationPermissionAlert() {
        guard let topViewController = getTopViewController() else { return }
        
        let alert = UIAlertController(
            title: "Location Permission Required",
            message: "This mini app requires location access. Please enable it in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        topViewController.present(alert, animated: true)
    }
    
    /// Get top view controller for presenting alerts
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

// MARK: - CLLocationManagerDelegate
extension PermissionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            permissionCompletion?(true)
            
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.showLocationPermissionAlert()
            }
            permissionCompletion?(false)
            
        case .notDetermined:
            break
            
        @unknown default:
            permissionCompletion?(false)
        }
        
        // Clean up
        permissionCompletion = nil
        locationManager = nil
    }
}
