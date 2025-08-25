# Encorely

[![Swift 6 CI](https://github.com/kakashi3lite/Encorely/actions/workflows/swift6-ci.yml/badge.svg)](https://github.com/kakashi3lite/Encorely/actions/workflows/swift6-ci.yml)
[![Tests](https://github.com/kakashi3lite/Encorely/actions/workflows/tests.yml/badge.svg)](https://github.com/kakashi3lite/Encorely/actions/workflows/tests.yml)
[![CodeQL](https://github.com/kakashi3lite/Encorely/actions/workflows/codeql.yml/badge.svg)](https://github.com/kakashi3lite/Encorely/actions/workflows/codeql.yml)
[![Docs](https://github.com/kakashi3lite/Encorely/actions/workflows/documentation.yml/badge.svg)](https://kakashi3lite.github.io/Encorely/)

Create adaptive, AI-assisted mixtapes. Encorely fuses real‑time audio insights, mood and context, and a modular SwiftUI architecture.

- Swift 6 • Xcode 26 • iOS 15+ • macOS 12+
- AudioKit + Swift Composable Architecture + Socket.IO

## Overview
Encorely (formerly AI‑Mixtapes) is a modular SwiftUI app that analyzes audio signals, infers mood and user context, and generates dynamic playlists and visuals. The codebase is organized for clarity and speed, with consolidated app code and small, focused packages.

Quick links:
- Docs/CODE_CONTEXT.md — codebase map and pointers
- Docs/ARCHITECTURE.md — layered overview and runtime flow
- Docs/DEV_NOTES.md — setup, run, lint, troubleshooting
- Docs/AI_GUIDE.md — how to work with AI tools efficiently

## Features
- Mood‑aware playlist generation and adaptive UI
- Audio analysis (RMS/FFT) and visualization
- Modular services: Core Data, MusicKit, socket‑based integrations
- Reusable SwiftUI components (Glass UI) and design primitives

## Requirements
- Xcode 26 (Swift 6 toolchain)
- iOS 15.0+ (primary), macOS 12.0+ (support)

## Getting Started
1) Clone
```
git clone https://github.com/kakashi3lite/Encorely.git
cd Encorely
```

2) Open in Xcode
```
open AI-Mixtapes.xcodeproj
```

3) Select the app scheme and Run (⌘R)

SPM packages are aligned to Swift 6; if needed, choose Product > Resolve Package Versions.

## Architecture at a Glance
High‑level layers and notable modules. See Docs/ARCHITECTURE.md for details.

- Presentation (SwiftUI)
  - `Sources/App/Consolidated` — views, DI, services, models, resources
  - `Sources/GlassUI` — reusable SwiftUI components (e.g., GlassCard)
- Domain/Services
  - `Sources/AudioKitEncorely` — DSP utilities (RMS/FFT), session helpers
  - `Sources/MCPClient` — Socket.IO client and protocol models
  - `Sources/SharedTypes` — cross‑module models and types
- Data/Persistence
  - Core Data models: `AI_Mixtapes.xcdatamodeld`, `Mixtapes.xcdatamodeld`

SPM targets (defined in Package.swift):
- App (executable) — depends on SharedTypes, MCPClient, AudioKit, SoundpipeAudioKit
- SharedTypes (library)
- MCPClient (library)

External dependencies: AudioKit, SoundpipeAudioKit, Swift Collections/Algorithms/Async Algorithms, Composable Architecture, Socket.IO.

## Directory Structure (select)
- AI-Mixtapes.xcodeproj — Xcode project
- Package.swift — SwiftPM manifest (tools 6.0)
- Sources/
  - App/Consolidated — main app code (preferred location for new code)
  - AudioKitEncorely — audio utilities (DSP/session)
  - MCPClient — Socket.IO client
  - SharedTypes — shared data types
  - GlassUI — reusable SwiftUI components
  - Domain — local SPM package (no tests configured)
- Tests/ — unit tests (e.g., AudioKitEncorelyTests)
- Docs/ — high-signal developer docs and AI helpers

## Build Targets & Schemes
- Executable: App
- Libraries: SharedTypes, MCPClient
- Deployment: iOS 15+, macOS 12+

Build settings are centralized in `Base.xcconfig`, `Debug.xcconfig`, and `Release.xcconfig` with Swift 6 and strict concurrency enabled.

## CI
Optimized GitHub Actions with Swift 6, caching, and path filters:
- `.github/workflows/swift6-ci.yml` — primary Swift 6 CI (SwiftPM build/test + Xcode package resolution)
- `tests.yml` and `swift.yml` — SwiftPM builds/tests (kept as auxiliary flows)
- `documentation.yml` — DocC build (triggered only on relevant paths)
- `ci.yml` — legacy, full‑stack pipeline (throttled via `paths-ignore`)

## Contributing
We welcome improvements and new features.

1) Create a branch: `git checkout -b feature/your-feature`
2) Add code under `Sources/App/Consolidated` where possible
3) Keep changes focused; follow `.swiftformat` and `.swiftlint.yml`
4) Commit and open a Pull Request

See Docs/DEV_NOTES.md and Docs/CODE_CONTEXT.md for guidance.

## Troubleshooting
- Schemes not visible in CLI? Open the project once in Xcode to refresh shared schemes
- SPM issues? Product > Resolve Package Versions, or see Docs/DEV_NOTES.md
- Build settings mismatch? Confirm Xcode 26 and Swift 6 are selected

## License
Copyright © 2025 kakashi3lite
