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
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "MiniAppsSDK",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Framework",
            exclude: [
                "MiniAppsSDK.h",
                "module.modulemap",
                "Models/banners_response.json"
            ]
        )
    ]
)
