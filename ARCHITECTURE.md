# Encorely Architecture

Encorely is structured as a Swift Package–first iOS app with clear separation between UI (GlassUI), audio (AudioKitEncorely), and the app shell. This document explains the current layout, build, and evolution plan.

## Goals
- Ship a modern SwiftUI app that feels fast and accessible.
- Provide a reusable Glass UI kit and an audio kit suitable for low-latency capture/monitor.
- Keep modules platform-aware and testable with SPM.

## Repository Layout
- App/
  - SwiftUI app target: `EncorelyApp`, `ContentView`, Resources (Assets, Info.plist).
- Sources/
  - GlassUI/: Reusable SwiftUI components (e.g., `GlassCard`) with accessibility fallbacks.
  - AudioKitEncorely/: Audio utilities and DSP helpers (e.g., `DSP.rms(_)`, session stubs).
- Tests/
  - AudioKitEncorelyTests/: Unit tests for DSP and audio helpers.
- project.yml
  - XcodeGen configuration that defines the iOS application target depending on SPM products.
- Package.swift
  - Swift Package manifest that builds both modules and unit tests.

## Build Targets
- Swift Package products
  - GlassUI (library)
  - AudioKitEncorely (library)
- iOS Application (via XcodeGen): "Encorely"
  - Depends on both SPM libraries.
  - SwiftUI lifecycle.

## App Shell
- `EncorelyApp` uses `WindowGroup` with a root `ContentView` that composes GlassUI components.
- Assets and Info.plist live under App/Resources.

## Glass UI Kit (GlassUI)
- Components are implemented in pure SwiftUI.
- Design principles: use Materials when available, add subtle borders/shadows, and provide solid-color fallbacks for Reduce Transparency.
- Example: `GlassCard` provides a frosted panel with accessibility-aware fallback.

## Audio Kit (AudioKitEncorely)
- Cross-platform-safe utilities and DSP helpers.
- `DSP.rms(_:)` and basic session APIs prepared for iOS AVAudioSession wiring.
- iOS runtime wiring (category/mode/options, route/interrupt handling) is scoped to the app and iOS-specific module code.

## Testing Strategy
- Unit tests under `Tests/` with SPM.
- Recommended next tests: UI snapshots for GlassUI, audio route/interrupt tests on iOS, and DSP edge cases.

## CI/CD (overview)
- Build and test SPM modules on macOS runners.
- Build iOS app target using an Xcode build step (Simulator destination).

## Roadmap
- Expand GlassUI: Toolbar, ListRow, TactileButton, FloatingSheet, and accessibility tests.
- Expand AudioKitEncorely: AVAudioSession manager, AVAudioEngine graphs (record/play/monitor), and publishers for live meters.
- Feature slices: Now Playing, Recorder with live RMS meter, Visualizers.
- Add Privacy manifest, TipKit/AppIntents/WidgetKit scaffolds, and performance tests.

## Performance & Accessibility
- Target 60 FPS for common UI flows; provide Reduce-Transparency and High-Contrast fallbacks.
- Audio graph should be stable with low-latency configurations on iOS; handle route changes gracefully.
