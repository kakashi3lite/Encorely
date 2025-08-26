# Playbook: Add a New Screen

1) Create the view
- Location: `Sources/App/Consolidated/`
- Add a SwiftUI view with a focused responsibility.

2) Wire navigation
- Update `MainTabView` or the `Coordinator` to present the new view.

3) Add any services/state
- Place service under `Consolidated/Services/` and expose via DI.

4) Tests
- Add unit tests (logic) and snapshot/UI tests as needed.

5) Docs
- Update `Docs/CODE_CONTEXT.md` if you introduce new directories.
