# Contributing to Encorely

Thanks for your interest in contributing! This project follows a Swift Package–first architecture with an iOS app target.

## Getting Started
- Xcode 15+ on macOS 13+.
- Swift toolchain 5.9+.
- XcodeGen for project generation (`brew install xcodegen`).

## Build & Run
- Swift Package (modules): `swift build && swift test`
- iOS App:
  1. `xcodegen generate`
  2. Open `Encorely.xcodeproj`
  3. Run the "Encorely" scheme on Simulator or device.

## Branching
- main: stable
- feature/*: new features
- fix/*: bug fixes

## Commit Messages
- Conventional summary lines like:
  - feat(ui): add TactileButton
  - fix(audio): handle route change interruptions
  - docs: add architecture overview
  - ci: add simulator build job

## Pull Requests
- Keep PRs focused and under ~400 LOC when possible.
- Include tests when changing logic.
- Update docs if behavior or public APIs change.

## Code Style
- Swift 5.9.
- Prefer SwiftUI idioms for UI; provide accessibility labels and fallbacks.
- Keep audio APIs platform-aware; isolate iOS-only code.

## Tests
- Run `swift test` and ensure all pass.
- For UI and performance tests, include steps or artifacts when possible.

## Security
- Never commit secrets; use Keychain or environment-provided credentials.
- See SECURITY.md for reporting guidelines.
