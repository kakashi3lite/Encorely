# Encorely Dev Notes (Quick Reference)

- Toolchain: Swift 6 / Xcode 26
- Open: `AI-Mixtapes.xcodeproj`
- Targets:
  - Executable: `App`
  - Libraries: `SharedTypes`, `MCPClient`
- Packages: Resolved (AudioKit, SoundpipeAudioKit, etc.). If stale: Product > Resolve Package Versions.
- Run: Select app scheme > iOS Simulator
- Lint/Format: Respect `.swiftlint.yml` and `.swiftformat` at repo root.
- Config:
  - Entitlements: `AI-Mixtapes.entitlements`
  - XCConfig: `Base.xcconfig`, `Debug.xcconfig`, `Release.xcconfig`, `Config/*`
- Data: `AI_Mixtapes.xcdatamodeld`, `Mixtapes.xcdatamodeld`
- Core Services: under `Sources/App/Consolidated/`
- Sockets: `Sources/MCPClient`
- Audio Utils: `Sources/AudioKitEncorely`

Common tasks:
- Clean build: Product > Clean Build Folder
- Clear SPM cache (rare): File > Packages > Reset Package Caches
- Update a package: edit `Package.swift` then resolve
 - Install pre-commit hooks: `bash scripts/install-githooks.sh`

Troubleshooting:
- Schemes not listed: open in Xcode once to refresh shared schemes
- SPM error referencing `DomainTests`: fixed by removing missing test target path in `Sources/Domain/Package.swift`

See also: `Docs/CODE_CONTEXT.md`, `Docs/ARCHITECTURE.md`.
