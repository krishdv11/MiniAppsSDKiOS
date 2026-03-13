
import Foundation

/// Internal API client for fetching mini apps data
/// This class is not exposed to SDK users and is only used internally
internal class APIClient {
    
    internal static let shared = APIClient()
    
    private var baseURL: String = ""
    private var superAppVersion: String = "1.0.0"  // Default version
    
    private init() {}
    
    internal func setBaseURL(_ url: String) {
        baseURL = url
    }
    
    /// Set the super app version to send in API requests
    /// This should match your app's version (e.g., from Info.plist CFBundleShortVersionString)
    internal func setSuperAppVersion(_ version: String) {
        superAppVersion = version
        print("MiniAppsSDK: Super app version set to: \(version)")
    }
    
    /// Get the current super app version
    internal func getSuperAppVersion() -> String {
        return superAppVersion
    }
    
    /// Fetch list of mini apps
    /// POST /miniapp/v1/runtime/list
    internal func fetchMiniApps(appId: String, completion: @escaping (Result<[MiniApp], Error>) -> Void) {
        guard !baseURL.isEmpty else {
            completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Base URL not set"])))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/miniapp/v1/runtime/list") else {
            completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let response = try JSONDecoder().decode(MiniAppsResponse.self, from: data)
                if response.success {
                    // Sort by displayOrder ASC
                    let sortedApps = response.data.sorted { $0.displayOrder < $1.displayOrder }
                    completion(.success(sortedApps))
                } else {
                    completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: response.message])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    /// Get download token for a mini app
    /// POST /miniapp/v1/runtime/{appId}/download-token
    internal func getDownloadToken(
        appId: String,
        currentVersion: String?,
        completion: @escaping (Result<DownloadTokenResponse.DownloadTokenData, Error>) -> Void
    ) {
        guard !baseURL.isEmpty else {
            completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Base URL not set"])))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/miniapp/v1/runtime/\(appId)/download-token") else {
            completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let requestBody = DownloadTokenRequest(
            currentVersion: currentVersion,
            deviceInfo: DownloadTokenRequest.DeviceInfo(
                os: "ios",
                superAppVersion: superAppVersion
            )
        )
        
        print("MiniAppsSDK: Requesting download token for \(appId) with superAppVersion: \(superAppVersion)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("MiniAppsSDK: Raw API response for \(appId): \(responseString)")
            }
            
            do {
                let response = try JSONDecoder().decode(DownloadTokenResponse.self, from: data)
                
                if response.success {
                    // Check if data is null
                    guard let tokenData = response.data else {
                        let errorMsg = response.message ?? "Download token data is null"
                        print("MiniAppsSDK: ✗ API returned success but data is null for \(appId)")
                        print("MiniAppsSDK: ✗ API message: \(errorMsg)")
                        completion(.failure(NSError(
                            domain: "APIClient",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Download token data is null. API message: \(errorMsg)"]
                        )))
                        return
                    }
                    completion(.success(tokenData))
                } else {
                    let errorMsg = response.message ?? "Failed to get download token"
                    print("MiniAppsSDK: ✗ API returned success=false for \(appId)")
                    print("MiniAppsSDK: ✗ API message: \(errorMsg)")
                    completion(.failure(NSError(
                        domain: "APIClient",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: errorMsg]
                    )))
                }
            } catch {
                // Enhanced error logging for decoding failures
                print("MiniAppsSDK: ✗ JSON Decoding failed for \(appId)")
                print("MiniAppsSDK: ✗ Decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("MiniAppsSDK: ✗ Response body: \(responseString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
}
