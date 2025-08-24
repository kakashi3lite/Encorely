# Encorely Architecture Overview

This document captures the high-level architecture to guide development and assist tooling. For APIs and code, see the directories referenced here instead of expanding full files in prompts.

## Layers
- Presentation (SwiftUI)
  - Location: `Sources/App/Consolidated/*.swift`, `Sources/GlassUI`
  - Concerns: Views, navigation (Coordinator), small view models

- Domain / Services
  - Location: `Sources/App/Consolidated/Services/*`, `Sources/AudioKitEncorely/*`, `Sources/MCPClient/*`, `Sources/SharedTypes`
  - Concerns: Audio analysis, ML config, MusicKit glue, networking (Socket.IO), persistence helpers

- Data / Persistence
  - Location: `Sources/App/Consolidated/CoreData*`, `AI_Mixtapes.xcdatamodeld`, `Mixtapes.xcdatamodeld`
  - Concerns: Core Data stack, migrations, error monitoring

## Runtime Flow (Typical)
1. App boot in `AIMixtapesApp` sets up services (DI container) and initial scene.
2. Views subscribe to services/state via SwiftUI/Combine.
3. Audio features via AudioKit pipeline (RMS/FFT) in `AudioKitEncorely` feed UI/logic.
4. Socket-based interactions handled in `MCPClient`.
5. Persistence handled through Core Data utilities.

## Packages and Targets
- Executable target `App`: App composition, depends on `SharedTypes`, `MCPClient`, AudioKit packages.
- Libraries: `SharedTypes`, `MCPClient`.

External packages:
- Audio: AudioKit, SoundpipeAudioKit
- Foundation: apple/swift-collections, algorithms, async-algorithms
- Architecture: Composable Architecture (Point-Free)
- Networking: socket.io-client-swift

## Key Files
- `Sources/App/Consolidated/AIMixtapesApp.swift` — App entry
- `Sources/App/Consolidated/ContentView.swift` — Root content
- `Sources/App/Consolidated/Audio*` — Audio pipeline components
- `Sources/App/Consolidated/DI/*` — Dependency container and protocols
- `Sources/MCPClient/*` — Socket client & models
- `Sources/AudioKitEncorely/*` — DSP and session helpers

## Configuration
- Xcode project: `AI-Mixtapes.xcodeproj`
- XCConfigs: `Base.xcconfig`, `Debug.xcconfig`, `Release.xcconfig`, `Config/*`
- Entitlements: `AI-Mixtapes.entitlements`

## Testing
- Unit tests in `Tests/*` (e.g., `Tests/AudioKitEncorelyTests`)
- Note: Local `Sources/Domain` SPM tests removed from manifest to fix invalid path

## Evolution
- Consolidation in progress: prefer adding new features under `Sources/App/Consolidated`
- Legacy dirs (`Sources/AIMixtapes`, `Sources/AI-Mixtapes`) retained for history; avoid adding new code there

