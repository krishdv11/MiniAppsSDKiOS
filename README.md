# MiniAppsSDK + Sample App

This repository contains two fully separated deliverables:

- `Framework/` - SDK source code (packaged as the `MiniAppsSDK` Swift Package)
- `SampleApp/` - standalone iOS sample app that consumes the SDK via package dependency

The sample app does not include SDK source files directly. It links `MiniAppsSDK` as an external package dependency, which follows standard iOS integration practices.

## Structure

- `Package.swift` - package manifest for `MiniAppsSDK`
- `Framework/` - SDK implementation
- `SampleApp/project.yml` - XcodeGen spec for sample app
- `SampleApp/MiniAppsSampleApp.xcodeproj` - generated Xcode project
- `SampleApp/Sources/App/` - sample app code
- `docs/INTEGRATION_GUIDE.md` - end-to-end iOS integration guide
- `docs/FLOWS.md` - flow charts for all key SDK flows

## Run the Sample App

1. Open `SampleApp/MiniAppsSampleApp.xcodeproj` in Xcode.
2. Select your signing team if prompted.
3. Run on simulator or device.
4. In app UI, enter:
   - `Base URL`
   - `App ID`
5. Tap **Initialize + Fetch Banners**.

## Regenerate Project (if needed)

If you edit `SampleApp/project.yml`, regenerate the project:

```bash
cd SampleApp
xcodegen generate --spec project.yml
```

## Documentation

- End-to-end integration: `docs/INTEGRATION_GUIDE.md`
- Flow charts: `docs/FLOWS.md`
