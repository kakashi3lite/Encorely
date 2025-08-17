# Encorely

Premium SwiftUI music app that blends frosted glass UI with studio‑grade audio and on‑device AI to build mood‑aware mixtapes.

## What’s inside
- GlassUI Kit: GlassCard (with Reduce‑Transparency fallback) and friends.
- EncoreAudioKit: AVAudioSession SessionManager, low‑latency defaults, route/interrupt handling.
- Hybrid personality engine: Big Five (OCEAN) profile mapped to UI personas for scoring.
- Privacy manifest and background audio enabled.

## Quick start
- Open in Xcode 15+ and run the App target on iOS 16+.
- Background audio is enabled; microphone, Music library, Siri, and speech usage strings are included.

## Structure (SPM‑first)
- Sources/Kits/GlassUI – reusable glass components
- Sources/Kits/EncoreAudioKit – audio session utilities
- Sources/App/Consolidated – app code (views, engines, services)
- Sources/SharedTypes – shared models/enums
- Tests/AIMixtapesTests – unit tests (incl. Big Five mapping)

## Personality model
- BigFiveProfile drives recommendation weights; mapped to PersonalityType buckets for UI behavior.
- See docs/HYBRID_PERSONALITY_MODEL.md for details.

## Branding
- App name: Encorely
- Package name: Encorely

## Privacy & permissions
- PrivacyInfo.xcprivacy lists audio access; analytics are opt‑in by design (no trackers included).
- Background audio is enabled in Info.plist (UIBackgroundModes: audio).
