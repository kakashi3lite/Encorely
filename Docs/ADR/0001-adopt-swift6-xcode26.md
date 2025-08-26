# ADR-0001: Adopt Swift 6 and Xcode 26

- Status: accepted
- Date: 2025-08-24
- Deciders: @kakashi3lite
- Tags: toolchain, swift, xcode

## Context
The project previously used mixed Swift tool versions. CI and local development needed a consistent, modern toolchain to support strict concurrency, new language features, and library updates (AudioKit, SPM ecosystem).

## Decision
- Set `.swift-version` to `6.0`.
- Bump `Package.swift` tools to `6.0` (root and `Sources/Domain`).
- Set `SWIFT_VERSION = 6.0` and keep `SWIFT_STRICT_CONCURRENCY = complete` in xcconfigs.
- Add `.xcode-version` with `26.0` for clarity.
- Align CI runners to Xcode 16.x (Swift 6) on GitHub Actions.

## Consequences
Positive:
- Unified compiler behavior and diagnostics.
- Access to modern Swift features and concurrency guarantees.
- Better package compatibility going forward.

Tradeoffs:
- Requires latest Xcode for local development.
- Some older APIs may need migration.

## Alternatives Considered
- Staying on Swift 5.9: would block strict concurrency and some dependencies.

## Links
- Docs/DEV_NOTES.md
- .github/workflows/swift6-ci.yml
