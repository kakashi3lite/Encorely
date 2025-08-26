# Change Catalog

Map common changes to likely file paths for focused context:

- UI screen updates → `Sources/App/Consolidated/*View.swift`
- Navigation/tab changes → `MainTabView.swift`, `Coordinator.swift`
- Audio behavior → `Sources/App/Consolidated/Audio*`, `AudioKitEncorely/*`
- Socket events → `Sources/MCPClient/MCPClient.swift`
- Shared models → `Sources/SharedTypes/*`
- Core Data → `CoreData*` in Consolidated, `.xcdatamodeld` files at root
- Reusable UI components → `Sources/GlassUI/*`
- Build settings → `Base.xcconfig`, `Debug.xcconfig`, `Release.xcconfig`
- SPM deps/targets → `Package.swift`, `Package.resolved`
