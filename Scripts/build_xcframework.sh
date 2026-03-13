#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRAMEWORK_PROJECT_DIR="$ROOT_DIR/SDKFramework"
FRAMEWORK_PROJECT_PATH="$FRAMEWORK_PROJECT_DIR/MiniAppsSDKFramework.xcodeproj"
SCHEME="MiniAppsSDK"
BUILD_DIR="$ROOT_DIR/.build-artifacts"
ARCHIVE_IOS="$BUILD_DIR/MiniAppsSDK-iOS.xcarchive"
ARCHIVE_SIM="$BUILD_DIR/MiniAppsSDK-iOSSimulator.xcarchive"
OUTPUT_DIR="$ROOT_DIR/Binary"
OUTPUT_XCFRAMEWORK="$OUTPUT_DIR/MiniAppsSDK.xcframework"

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

pushd "$FRAMEWORK_PROJECT_DIR" >/dev/null
xcodegen generate --spec project.yml
popd >/dev/null

DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild archive \
  -project "$FRAMEWORK_PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_IOS" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild archive \
  -project "$FRAMEWORK_PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "generic/platform=iOS Simulator" \
  -archivePath "$ARCHIVE_SIM" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES

rm -rf "$OUTPUT_XCFRAMEWORK"

DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -create-xcframework \
  -framework "$ARCHIVE_IOS/Products/Library/Frameworks/MiniAppsSDK.framework" \
  -framework "$ARCHIVE_SIM/Products/Library/Frameworks/MiniAppsSDK.framework" \
  -output "$OUTPUT_XCFRAMEWORK"

# Private interfaces can leak implementation-only dependencies and are not
# required for consumers. Keep only public interfaces in the artifact.
find "$OUTPUT_XCFRAMEWORK" -name "*.private.swiftinterface" -delete

echo "Created XCFramework at: $OUTPUT_XCFRAMEWORK"
