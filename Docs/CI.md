# Continuous Integration

Primary workflows (see .github/workflows):

- swift6-ci.yml
  - Job spm-build: caches `.build` and `~/.swiftpm`, builds/tests via SwiftPM.
  - Job xcode-resolve: caches Xcode `DerivedData/SourcePackages`, resolves packages for `AI-Mixtapes.xcodeproj`.
  - paths-ignore and concurrency enabled.

- tests.yml / swift.yml
  - Auxiliary SwiftPM build/test flows.

- documentation.yml
  - Builds DocC for target `App` and publishes to GitHub Pages (host path `Encorely`).

- codeql.yml, secret-scan.yml, dependency-review.yml
  - Security scans and dependency policy on PRs/push.

Tips:
- Add new required checks in branch protection if you rely on them for gating merges.
- Keep `Package.resolved` updated to maximize cache hits.
