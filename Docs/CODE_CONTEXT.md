# Encorely Code Context

Purpose: Provide a compact map of the codebase to speed up AI-assisted development and reduce token usage. Prefer linking/pointing to these sections instead of pasting large files.

## Project Overview
- Name: Encorely (formerly AI‑Mixtapes)
- Platforms: iOS 15+, macOS 12+
- App Type: SwiftUI app with modular SPM targets + Xcode project `AI-Mixtapes.xcodeproj`
- Core Domains: Audio analysis/visualization, MusicKit integration, Core Data, AI-assisted features, Socket-based MCP client.

## Build & Run
- Open in Xcode: `AI-Mixtapes.xcodeproj`
- Primary executable target: `App` (defined in `Package.swift`)
- Dependencies resolved (AudioKit, SoundpipeAudioKit, etc). If needed: Product > Resolve Package Versions.
- Schemes: Select app scheme after opening the project; shared schemes may populate on first open.

## Key Entry Points
- App entry: `Sources/App/Consolidated/AIMixtapesApp.swift`
- Main UI composition: `Sources/App/Consolidated/ContentView.swift`, `MainTabView.swift`
- App services: `Sources/App/Consolidated/…` (e.g., AudioAnalysis, MoodEngine, DI, CoreData helpers)
- Sockets client: `Sources/MCPClient` (uses Socket.IO)
- Shared types: `Sources/SharedTypes`
- AudioKit utilities: `Sources/AudioKitEncorely`

## Module Map (SPM Targets)
- `App` (Executable): Depends on `SharedTypes`, `MCPClient`, AudioKit, SoundpipeAudioKit
- `SharedTypes` (Library): Shared models/DTOs
- `MCPClient` (Library): Socket.IO client glue and protocol models

External packages in `Package.swift`:
- `apple/swift-algorithms`, `apple/swift-collections`, `apple/swift-async-algorithms`
- `pointfreeco/swift-composable-architecture`
- `AudioKit/AudioKit`, `AudioKit/SoundpipeAudioKit`
- `socketio/socket.io-client-swift`

## Source Layout (Selected)
- `Sources/App/Consolidated/` — Unified app code: UI, Services, DI, CoreData helpers, ML config, audio processing
- `Sources/AudioKitEncorely/` — AudioKit helpers: DSP (e.g. RMS), session management
- `Sources/SharedTypes/` — Cross-module models and type aliases
- `Sources/MCPClient/` — Socket protocol, event handling, and integration with app layer
- `Sources/AI-Mixtapes/` and `Sources/AIMixtapes/` — Legacy paths retained during consolidation; prefer `Sources/App/Consolidated`
- `Sources/GlassUI/` — Reusable SwiftUI components (e.g., `GlassCard`)
- `Sources/Domain/` — Local SPM package (no tests configured)

## Configuration
- Xcode project: `AI-Mixtapes.xcodeproj`
- App entitlements: `AI-Mixtapes.entitlements`
- XCConfigs: `Base.xcconfig`, `Debug.xcconfig`, `Release.xcconfig`, plus `Config/*`
- Info plists: `Info.plist` (root), others under `Sources/App/Resources` as needed

## Data & Models
- Core Data: `AI_Mixtapes.xcdatamodeld` and `Mixtapes.xcdatamodeld`
- Models: Consolidated under `Sources/App/Consolidated/` and legacy models under `Sources/AIMixtapes/Models`

## Notable Services (Consolidated)
- Audio analysis pipeline: `AudioAnalysis*`, `FFT*`, `AudioProcessor`, `AudioBuffer*`
- AI integrations: `OpenAIIntegrationService.swift` (placeholder for LLM), ML configuration
- Persistence: `CoreData*` files (migration manager, error monitor, etc.)
- Navigation & UI scaffolding: Coordinator, various SwiftUI views under Consolidated

## Tests
- Central tests under `Tests/` (e.g., `Tests/AudioKitEncorelyTests`)
- Domain package tests removed from the local Domain SPM manifest (non-existent path issue fixed)

## Common Tasks
- Resolve packages: Xcode Product > Resolve Package Versions
- Clean build: Product > Clean Build Folder
- Update deps: edit `Package.swift` then resolve
- Run app: select scheme, target: iOS Simulator/iPhone

## Conventions & Notes
- Prefer `Sources/App/Consolidated` for new app code; legacy directories are being phased out.
- Keep new Swift packages small and focused; add `Package.swift` entries and update `App` target deps if needed.
- Follow existing SwiftFormat/SwiftLint configurations at repo root.

## Quick Links
- `Package.swift` — targets and dependencies
- `Sources/App/Consolidated/` — main app surface area
- `Sources/MCPClient/` — socket client integration
- `Sources/AudioKitEncorely/` — audio utilities

