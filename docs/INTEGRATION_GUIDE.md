# MiniAppsSDK End-to-End Integration Guide (iOS)

This guide walks through complete integration of `MiniAppsSDK` in a native iOS app, from dependency setup to runtime validation.

## 1) Architecture and Separation

Use this repo with strict separation:

- SDK module: `MiniAppsSDK` (Swift Package defined by `Package.swift`)
- Host app: your native iOS application target
- Verification app: `SampleApp/` (already integrated)

Do not copy SDK source files into your app target. Always consume the SDK as a dependency.

## 2) Add SDK to Your Native iOS App

### Option A: Swift Package Manager (SPM) - local package (development)

1. Open your app in Xcode.
2. Go to **File > Add Packages...**
3. Click **Add Local...**
4. Select the folder containing this repo.
5. Add product `MiniAppsSDK` to your app target.

### Option B: Swift Package Manager (SPM) - Git package (recommended for teams/CI)

1. Push this repo to GitHub (already done).
2. In your app project, go to **File > Add Packages...**
3. Enter repo URL:
   - `git@github.com:<your-org>/<your-sdk-repo>.git`
4. Choose branch/tag.
5. Add `MiniAppsSDK` product to your app target.

### Option C: CocoaPods

1. In your app repository, update/create `Podfile`:

```ruby
platform :ios, '13.0'
use_frameworks!

target 'YourAppTarget' do
  pod 'MiniAppsSDK', :git => 'git@github.com:<your-org>/<your-sdk-repo>.git', :tag => '1.0.0'
end
```

2. Install pods:

```bash
pod repo update
pod install
```

3. Open your generated `.xcworkspace` and build.

## 3) App-side Setup

Import SDK and initialize once (for example in your first screen or app startup flow):

```swift
import MiniAppsSDK
import UIKit

MiniAppsSDK.shared.initialize(
    baseURL: "https://api.your-domain.com",
    appId: "your-super-app-id"
)
```

Optional version override (if backend requires explicit value):

```swift
MiniAppsSDK.shared.setSuperAppVersion("2.0.0")
```

## 4) Render Banner View and Launch Mini Apps

```swift
MiniAppsSDK.shared.fetchMiniAppsWithView(width: 360, height: 220) { view, error in
    if let error = error {
        print("MiniApps fetch failed: \(error.localizedDescription)")
        return
    }
    guard let bannerView = view else { return }

    // Attach bannerView to your layout/container
}
```

Behavior:

- SDK fetches mini app list
- SDK downloads/updates mini app bundles in background
- User taps banner
- SDK requests permissions (if declared)
- SDK opens mini app web content in full-screen `WKWebView`

## 5) End-to-End Validation Checklist

1. App launches without linker/import errors.
2. SDK initializes with valid `baseURL` and `appId`.
3. Banner view appears after fetch.
4. Tapping banner opens full-screen mini app.
5. Closing mini app returns to host app.
6. Relaunch app: cached apps load quickly.
7. Version update scenario: backend returns new version and SDK re-downloads.
8. Error scenario: invalid `baseURL` shows graceful failure.

## 6) Troubleshooting

- **`SDK not initialized`**
  - Ensure `initialize(baseURL:appId:)` runs before fetch.

- **No banners shown**
  - Verify backend returns `success=true` and data list is non-empty.
  - Confirm network and ATS constraints if using non-HTTPS endpoints.

- **Mini app not launching**
  - Check downloaded mini app contains `index.html`.
  - Confirm permissions are granted when requested.

- **Build errors with command line tools**
  - Use full Xcode toolchain for CI/local command-line builds:
  - `DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild ...`

## 7) Sample App Test Path

Use `SampleApp/MiniAppsSampleApp.xcodeproj` for quick validation:

1. Run app.
2. Enter `baseURL` and `appId`.
3. Tap **Initialize + Fetch Banners**.
4. Verify banners render and launch flow works.
