# FAQ

Q: Where do I put new app code?
A: `Sources/App/Consolidated`. Avoid legacy folders unless specifically refactoring.

Q: What Swift/Xcode versions are required?
A: Swift 6 and Xcode 26 locally, Xcode 16 runners for CI.

Q: How do I resolve packages?
A: Xcode Product > Resolve Package Versions. CI caches SwiftPM and Xcode SourcePackages.

Q: Where are the entry points?
A: `AIMixtapesApp.swift` and `ContentView.swift` under `Sources/App/Consolidated`.

Q: Where are the audio utilities?
A: `Sources/AudioKitEncorely`.

Q: How do I set branch protection?
A: Use the `Protect Branches` workflow or `scripts/protect-branches.sh` with a PAT.
