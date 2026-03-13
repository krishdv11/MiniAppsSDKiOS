# MiniAppsSDK + Sample App

This repository contains two fully separated deliverables:

- `Framework/` - SDK source code (packaged as the `MiniAppsSDK` Swift Package)
- `SampleApp/` - standalone iOS sample app that consumes the SDK via package dependency

The sample app does not include SDK source files directly. It links `MiniAppsSDK` as an external package dependency, which follows standard iOS integration practices.

## Structure

- `Package.swift` - package manifest for `MiniAppsSDK`
- `Framework/` - SDK implementation
- `MiniAppsSDK.podspec` - CocoaPods spec for native iOS integration
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

#### Option A: Swift Package Manager (SPM) - local package

1. Open your app in Xcode.
2. Go to **File > Add Packages...**
3. Click **Add Local...**
4. Select this repository folder.
5. Add product `MiniAppsSDK` to your app target.

#### Option B: Swift Package Manager (SPM) - Git package

1. In your app project, go to **File > Add Packages...**
2. Use your repository URL:
   - `git@github.com:<your-org>/<your-sdk-repo>.git`
3. Choose branch/tag.
4. Add product `MiniAppsSDK` to your app target.

#### Option C: CocoaPods

1. Update/create `Podfile`:

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

3. Open `.xcworkspace` and build.

### 3) App-side Setup

```swift
import MiniAppsSDK
import UIKit

MiniAppsSDK.shared.initialize(
    baseURL: "https://api.your-domain.com",
    appId: "your-super-app-id"
)
```

Optional:

```swift
MiniAppsSDK.shared.setSuperAppVersion("2.0.0")
```

### 4) Render Banner View and Launch Mini Apps

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
