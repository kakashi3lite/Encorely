# Encorely

Encorely is a Swift Package–first codebase with two core modules:

- GlassUI: SwiftUI components with modern glassmorphism and accessibility fallbacks.
- AudioKitEncorely: Audio utility module with session management stubs and DSP helpers.

This foundation compiles and tests on macOS runners in CI, and is ready to be embedded into an iOS app target.

## Requirements
- macOS 13+ with Xcode 15+ (Swift 5.9)

## Build
```bash
swift build
```

## Test
```bash
swift test
```

## Modules
- GlassUI: Start with `GlassCard` for frosted UI blocks (Reduce Transparency supported).
- AudioKitEncorely: Includes `DSP.rms(_:)` and a cross-platform-safe `AudioSessionManager` API.

## Development Guidelines

### Code Quality

This project enforces strict code quality standards through automated tools:

- **SwiftFormat**: Ensures consistent code formatting
- **SwiftLint**: Enforces Swift style and conventions

A pre-commit hook is installed to automatically check code quality before each commit.

### Git Workflow

1. Ensure all code passes SwiftFormat and SwiftLint checks
2. Follow semantic commit messages:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation changes
   - `style:` for formatting changes
   - `refactor:` for code refactoring
   - `test:` for adding or modifying tests
   - `chore:` for maintenance tasks

### Setup Development Environment

```bash
# Install required tools
brew install swiftformat swiftlint

# Verify pre-commit hook is installed
ls -la .git/hooks/pre-commit
```

## Next Steps (suggested)
- Create an iOS app target that consumes these modules (Xcode project or XcodeGen).
- Implement full AVAudioSession routing and interruptions inside `AudioSessionManager` (iOS only).
- Grow the Glass UI Kit (Toolbar, ListRow, TactileButton) and add snapshot/UI tests.
- Add CI linting (swift-format/SwiftLint) and code coverage reporting.
