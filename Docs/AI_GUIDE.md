# Using AI Tools Effectively in Encorely

This guide helps AI coding tools answer accurately with minimal context.

## Start Here
- Read: `Docs/CODE_CONTEXT.md` and `Docs/ARCHITECTURE.md`
- Use area map: `Docs/AREAS.json` to find the right folders

## Minimal Context Pack
When asking questions, include only:
- The file path(s) you want to change
- A short excerpt (10–40 lines) around the relevant code
- Links to the sections in `CODE_CONTEXT.md` instead of pasting whole files

## Where to Add Code
- Prefer `Sources/App/Consolidated` for new app logic, views, services
- Shared types: `Sources/SharedTypes`
- Audio utilities: `Sources/AudioKitEncorely`
- Socket client: `Sources/MCPClient`

## Avoid
- Scanning `node_modules`, `build`, `DerivedData`, or binary artifacts
- Adding new files into legacy `Sources/AIMixtapes` or `Sources/AI-Mixtapes` paths

## Build & Run
- Open `AI-Mixtapes.xcodeproj`
- Resolve packages if needed (Xcode: Product > Resolve Package Versions)
- Select app scheme and run on iOS simulator

## Common Tasks
- Update dependency: edit `Package.swift` then resolve packages
- Add unit tests: in `Tests/` (see existing patterns)
- Follow lint/format rules: `.swiftlint.yml`, `.swiftformat`

## Troubleshooting
- SPM issues? Check `Package.swift`, then `Docs/DEV_NOTES.md`
- Schemes missing? Open project once in Xcode to refresh

