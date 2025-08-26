# Module: App (Executable)

Purpose: Primary SwiftUI app composition (views, services, DI, models, resources).

Key entry points:
- Sources/App/Consolidated/AIMixtapesApp.swift — app entry
- Sources/App/Consolidated/ContentView.swift — root UI
- Sources/App/Consolidated/DI/* — dependency injection helpers
- Sources/App/Consolidated/Services/* — app-wide services (audio, core data, mood, etc.)

Common tasks:
- Add a new screen: add view under `Consolidated/`, wire via Coordinator/MainTabView.
- Add a service: create in `Services/`, expose via DIContainer.
- UI components: prefer reusable pieces in GlassUI for cross-feature sharing.

Testing:
- Tests reside under `Tests/` (see existing patterns, e.g., AudioKitEncorelyTests).
