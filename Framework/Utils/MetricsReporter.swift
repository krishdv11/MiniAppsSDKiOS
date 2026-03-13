
import Foundation
import UIKit

/// Internal manager for reporting metrics events
internal class MetricsReporter {
    
    static let shared = MetricsReporter()
    
    private var baseURL: String = ""
    private var superAppVersion: String = "1.0.0"  // Default version
    private let deviceId: String
    
    private init() {
        // Generate or retrieve device ID
        if let storedDeviceId = UserDefaults.standard.string(forKey: "miniapp_device_id") {
            deviceId = storedDeviceId
        } else {
            deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            UserDefaults.standard.set(deviceId, forKey: "miniapp_device_id")
        }
    }
    
    func setBaseURL(_ url: String) {
        baseURL = url
    }
    
    func setSuperAppVersion(_ version: String) {
        superAppVersion = version
    }
    
    /// Report a metrics event
    func reportEvent(
        appId: String,
        version: String,
        eventType: String,
        message: String?,
        metadata: String?
    ) {
        guard !baseURL.isEmpty else {
            print("MiniAppsSDK: ⚠️ Metrics: Base URL not set, skipping metrics event")
            return
        }
        
        let request = MetricsEventRequest(
            appId: appId,
            version: version,
            eventType: eventType,
            deviceId: deviceId,
            os: "ios",
            superAppVersion: superAppVersion,
            message: message,
            metadata: metadata
        )
        
        guard let url = URL(string: "\(baseURL)/miniapp/v1/metrics/events") else {
            print("MiniAppsSDK: ✗ Metrics: Invalid URL: \(baseURL)/miniapp/v1/metrics/events")
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30.0
        
        let requestStartTime = Date()
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            print("MiniAppsSDK: ✗ Metrics: Failed to encode metrics event: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: urlRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            let requestDuration = Date().timeIntervalSince(requestStartTime)
            
            // Handle network error
            if let error = error {
                print("MiniAppsSDK: ✗ Metrics API: Network error")
                print("MiniAppsSDK:   ├─ Event Type: \(eventType)")
                print("MiniAppsSDK:   ├─ App ID: \(appId)")
                print("MiniAppsSDK:   ├─ Error: \(error.localizedDescription)")
                print("MiniAppsSDK:   └─ Duration: \(String(format: "%.2f", requestDuration))s")
                return
            }
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                print("MiniAppsSDK: ✗ Metrics API: Invalid response type")
                print("MiniAppsSDK:   ├─ Event Type: \(eventType)")
                print("MiniAppsSDK:   └─ App ID: \(appId)")
                return
            }
            
            // Check status code
            guard (200...299).contains(httpResponse.statusCode) else {
                print("MiniAppsSDK: ✗ Metrics API: HTTP error")
                print("MiniAppsSDK:   ├─ Event Type: \(eventType)")
                print("MiniAppsSDK:   ├─ App ID: \(appId)")
                print("MiniAppsSDK:   ├─ Status Code: \(httpResponse.statusCode)")
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("MiniAppsSDK:   ├─ Response: \(responseString)")
                }
                print("MiniAppsSDK:   └─ Duration: \(String(format: "%.2f", requestDuration))s")
                return
            }
            
            // Parse response body
            guard let data = data else {
                print("MiniAppsSDK: ⚠️ Metrics API: No response data")
                print("MiniAppsSDK:   ├─ Event Type: \(eventType)")
                print("MiniAppsSDK:   └─ App ID: \(appId)")
                return
            }
            
            // Try to decode response
            do {
                let metricsResponse = try JSONDecoder().decode(MetricsResponse.self, from: data)
                if metricsResponse.success {
                    print("MiniAppsSDK: ✓ Metrics API: Event reported successfully")
                    print("MiniAppsSDK:   ├─ Event Type: \(eventType)")
                    print("MiniAppsSDK:   ├─ App ID: \(appId)")
                    print("MiniAppsSDK:   ├─ Status Code: \(httpResponse.statusCode)")
                    if let message = metricsResponse.message {
                        print("MiniAppsSDK:   ├─ Server Message: \(message)")
                    }
                    print("MiniAppsSDK:   └─ Duration: \(String(format: "%.2f", requestDuration))s")
                } else {
                    print("MiniAppsSDK: ✗ Metrics API: Server returned failure")
                    print("MiniAppsSDK:   ├─ Event Type: \(eventType)")
                    print("MiniAppsSDK:   ├─ App ID: \(appId)")
                    print("MiniAppsSDK:   ├─ Status Code: \(httpResponse.statusCode)")
                    if let message = metricsResponse.message {
                        print("MiniAppsSDK:   ├─ Server Message: \(message)")
                    }
                    print("MiniAppsSDK:   └─ Duration: \(String(format: "%.2f", requestDuration))s")
                }
            } catch {
                // If decoding fails, log raw response
                if let responseString = String(data: data, encoding: .utf8) {
                    print("MiniAppsSDK: ⚠️ Metrics API: Response decode failed")
                    print("MiniAppsSDK:   ├─ Event Type: \(eventType)")
                    print("MiniAppsSDK:   ├─ App ID: \(appId)")
                    print("MiniAppsSDK:   ├─ Status Code: \(httpResponse.statusCode)")
                    print("MiniAppsSDK:   ├─ Raw Response: \(responseString)")
                    print("MiniAppsSDK:   └─ Duration: \(String(format: "%.2f", requestDuration))s")
                } else {
                    print("MiniAppsSDK: ⚠️ Metrics API: Response decode failed (invalid UTF-8)")
                    print("MiniAppsSDK:   ├─ Event Type: \(eventType)")
                    print("MiniAppsSDK:   └─ App ID: \(appId)")
                }
                // Still consider it a success if HTTP status is 200-299
                if (200...299).contains(httpResponse.statusCode) {
                    print("MiniAppsSDK: ✓ Metrics API: HTTP success (assuming success despite decode failure)")
                    print("MiniAppsSDK:   └─ Duration: \(String(format: "%.2f", requestDuration))s")
                }
            }
        }.resume()
    }
}
