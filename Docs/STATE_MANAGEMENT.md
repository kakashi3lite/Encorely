# State Management

Encorely favors simple SwiftUI state with DI for services. Composable Architecture (TCA) is available via dependencies but is optional.

- For simple views: `@State`, `@StateObject`, `@EnvironmentObject`.
- For cross-cutting services: inject via DI container in Consolidated/DI.
- For complex flows: consider TCA (Reducers/Store) in isolated features.
- Keep side effects in services; keep views declarative and testable.
