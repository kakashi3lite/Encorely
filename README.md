# Encorely

Encorely is an iOS SwiftUI app with a Swift Package–first architecture. It is an app, not a background service.

- GlassUI: SwiftUI components with modern glassmorphism and accessibility fallbacks.
- AudioKitEncorely: Audio utilities with session management stubs and DSP helpers.
- App target: SwiftUI entry (EncorelyApp) and a starter ContentView using GlassCard.

## Requirements
- macOS 13+ with Xcode 15+ (Swift 5.9)
- XcodeGen (to generate the Xcode project)

## Quick Start (App)
- Generate the Xcode project with XcodeGen, open, and run the "Encorely" scheme on Simulator or device.

## Package: Build & Test (Modules)
- Build with `swift build` and test with `swift test`.

## Next Steps
- Expand the Glass UI Kit (Toolbar, ListRow, TactileButton) and add snapshot/UI tests.
- Implement full AVAudioSession routing and interruptions inside `AudioSessionManager` (iOS only).
- Add CI linting (swift-format/SwiftLint) and code coverage reporting.
