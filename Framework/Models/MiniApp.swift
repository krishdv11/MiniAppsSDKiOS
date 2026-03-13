
import Foundation

/// Represents a Mini App from the API
public struct MiniApp: Codable {
    public let appId: String
    public let name: String
    public let category: String
    public let iconUrl: String
    public let displayOrder: Int
    public let partnerId: String?
    public let latestVersion: String
    public let rolloutPercent: Int?
    public let bridgeVersion: String?
    public let permissions: [String]?
    public let riskLevel: String?
    
    enum CodingKeys: String, CodingKey {
        case appId
        case name
        case category
        case iconUrl
        case displayOrder
        case partnerId
        case latestVersion
        case rolloutPercent
        case bridgeVersion
        case permissions
        case riskLevel
    }
}

/// API response wrapper for mini apps list
internal struct MiniAppsResponse: Codable {
    let success: Bool
    let message: String
    let data: [MiniApp]
}

/// Download token request body
internal struct DownloadTokenRequest: Codable {
    let currentVersion: String?
    let deviceInfo: DeviceInfo
    
    struct DeviceInfo: Codable {
        let os: String
        let superAppVersion: String
    }
}

/// Download token response
internal struct DownloadTokenResponse: Codable {
    let success: Bool
    let message: String?
    let data: DownloadTokenData?  // Made optional to handle null responses
    
    struct DownloadTokenData: Codable {
        let downloadUrl: String
        let checksum: String
        let artifactId: String
        let expiresIn: Int
    }
}

/// Metrics event request
internal struct MetricsEventRequest: Codable {
    let appId: String
    let version: String
    let eventType: String
    let deviceId: String
    let os: String
    let superAppVersion: String
    let message: String?
    let metadata: String?
}

/// Metrics response
internal struct MetricsResponse: Codable {
    let success: Bool
    let message: String?
}
