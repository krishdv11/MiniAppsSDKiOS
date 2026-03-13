# MiniAppsSDK + Sample App

This repository contains two fully separated deliverables:

- `Binary/MiniAppsSDK.xcframework` - prebuilt SDK binary for external integration
- `SampleApp/` - standalone iOS sample app that consumes the SDK via package dependency

Consumers integrate the SDK as a compiled binary (SPM/CocoaPods). SDK source files are not included in client app targets.

## Structure

- `Package.swift` - SPM binary package manifest for `MiniAppsSDK`
- `Binary/` - XCFramework distribution artifact
- `MiniAppsSDK.podspec` - CocoaPods spec for native iOS integration
- `Framework/` - SDK source (internal implementation)
- `Scripts/build_xcframework.sh` - regenerate binary artifact from source
- `SampleApp/project.yml` - XcodeGen spec for sample app
- `SampleApp/MiniAppsSampleApp.xcodeproj` - generated Xcode project
- `SampleApp/Sources/App/` - sample app code
- `docs/FLOWS.md` - flow charts for all key SDK flows

## Run the Sample App

1. Open `SampleApp/MiniAppsSampleApp.xcodeproj` in Xcode.
2. Select your signing team if prompted.
3. Run on simulator or device.
4. In app UI, enter:
   - `Base URL`
   - `App ID`
5. Tap **Initialize + Fetch Banners**.

## End-to-End Integration Guide (iOS)

### 1) Architecture and Separation

- SDK module: `MiniAppsSDK` (`Package.swift`)
- Host app: your native iOS application target
- Verification app: `SampleApp/`

Do not copy SDK source files into your app target. Consume it as a dependency via SPM or CocoaPods.

### 2) Add SDK to Your Native iOS App

#### Option A: Swift Package Manager (SPM) - Git package (recommended)

1. In your app project, go to **File > Add Packages...**
2. Use your repository URL:
   - `https://github.com/krishdv11/MiniAppsSDKiOS.git`
3. Choose dependency rule:
   - During development: `Branch` -> `main`
   - For release (recommended): `Up to Next Major` from a tag (for example `1.0.0`)
4. Add product `MiniAppsSDK` to your app target.

#### Option B: Swift Package Manager (SPM) - local package (internal only)

Use local package integration only for internal SDK development/verification.

If your app uses `Package.swift`, add it similar to Firebase-style package usage:

```swift
.package(url: "https://github.com/krishdv11/MiniAppsSDKiOS.git", from: "1.0.0")
```

#### Option C: CocoaPods

1. Update/create `Podfile`:

Use branch while you are iterating:

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourAppTarget' do
  pod 'MiniAppsSDK', :git => 'https://github.com/krishdv11/MiniAppsSDKiOS.git', :branch => 'main'
end
```

For versioned releases (Firebase-like pinning), use a tag:

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourAppTarget' do
  pod 'MiniAppsSDK', :git => 'https://github.com/krishdv11/MiniAppsSDKiOS.git', :tag => '1.0.0'
end
```

2. Install pods:

```bash
pod repo update
pod install
```

3. Open `.xcworkspace` and build.

Note: `:tag => '1.0.0'` works only after that git tag exists in this repository.

### 3) App-side Setup

```swift
import MiniAppsSDK
import UIKit

MiniAppsManager.shared.initialize(
    baseURL: "https://api.your-domain.com",
    appId: "your-super-app-id"
)
```

Optional:

```swift
MiniAppsManager.shared.setSuperAppVersion("2.0.0")
```

### 4) Render Banner View and Launch Mini Apps

```swift
MiniAppsManager.shared.fetchMiniAppsWithView(width: 360, height: 220) { view, error in
    if let error = error {
        print("MiniApps fetch failed: \(error.localizedDescription)")
        return
    }
    guard let bannerView = view else { return }

    // Attach bannerView to your layout/container
}
```

### 5) Validation Checklist

1. App builds without linker/import errors.
2. SDK initializes with valid `baseURL` and `appId`.
3. Banner view appears after fetch.
4. Tapping banner opens full-screen mini app.
5. Closing mini app returns to host app.
6. Relaunch app loads cached mini apps quickly.

### 6) Troubleshooting

- `SDK not initialized`: call `initialize(baseURL:appId:)` before fetch.
- No banners: verify backend response and network/ATS settings.
- Mini app launch fails: ensure downloaded bundle includes `index.html`.
- CLI build issues: use full Xcode toolchain (`DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"`).

## Documentation

- Flow charts: `docs/FLOWS.md`
