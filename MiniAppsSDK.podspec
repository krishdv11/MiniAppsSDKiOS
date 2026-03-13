Pod::Spec.new do |s|
  s.name             = "MiniAppsSDK"
  s.version          = "1.0.0"
  s.summary          = "Native iOS SDK for Mini Apps discovery and launch."
  s.description      = "MiniAppsSDK provides banner rendering, download/version management, and mini app launch flow for native iOS apps."
  s.homepage         = "https://github.com/krishdv11/MiniAppsSDKiOS"
  s.license          = { :type => "MIT" }
  s.author           = { "MiniApps Team" => "dev@your-domain.com" }
  s.platform         = :ios, "13.0"
  s.swift_version    = "5.0"
  s.source           = { :git => "https://github.com/krishdv11/MiniAppsSDKiOS.git", :tag => s.version.to_s }

  s.vendored_frameworks = "Binary/MiniAppsSDK.xcframework"
  s.frameworks       = "UIKit", "WebKit"
end
