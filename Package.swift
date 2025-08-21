// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Encorely",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "GlassUI", targets: ["GlassUI"]),
        .library(name: "AudioKitEncorely", targets: ["AudioKitEncorely"]) // named to avoid confusion with external AudioKit
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "GlassUI",
            dependencies: [],
            path: "Sources/GlassUI"
        ),
        .target(
            name: "AudioKitEncorely",
            dependencies: [],
            path: "Sources/AudioKitEncorely"
        ),
        .testTarget(
            name: "AudioKitEncorelyTests",
            dependencies: ["AudioKitEncorely"],
            path: "Tests/AudioKitEncorelyTests"
        ),
        .testTarget(
            name: "GlassUITests",
            dependencies: ["GlassUI"],
            path: "Tests/GlassUITests"
        )
    ]
)
