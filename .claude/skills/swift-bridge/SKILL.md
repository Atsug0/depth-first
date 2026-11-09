---
name: swift-bridge
description: iOS and Swift work — UIKit controllers and views, the Pigeon bridge to Flutter, fastlane, CocoaPods, localisation. Use whenever the request touches a .swift file, the native↔Flutter boundary, an Xcode project or scheme, or iOS availability, even if iOS is never named.
---

# iOS

## Boundary
- Native↔Flutter traffic is **Pigeon-generated** (`Cashbee/Flutter/Pigeon/Api.swift`).
  Change the schema in `consumer-app-flutter` and regenerate on both sides.
- Never hand-write a `FlutterMethodChannel`.
- Engine lifecycle stays in `Cashbee/Flutter/` — do not instantiate engines elsewhere.

## Constraints
- Deployment target is **iOS 13.0**. Anything newer needs an `@available` guard.
- Swift 5.0, UIKit. Open `Cashbee.xcworkspace`, never the `.xcodeproj`.
- `project.pbxproj` is resolved by hand — state that a file needs adding in Xcode
  rather than editing the file.

## Copy and tests
- User-facing strings belong in `fr.lproj` / `en.lproj`, never inline.
- Tests: `bundle exec fastlane test`. UI tests: `bundle exec fastlane uitest`.
