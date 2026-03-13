// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MiniAppsSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "MiniAppsSDK",
            targets: ["MiniAppsSDK"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "MiniAppsSDK",
            path: "Binary/MiniAppsSDK.xcframework"
        )
    ]
)
