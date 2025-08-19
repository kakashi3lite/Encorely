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
        // named to avoid confusion with external AudioKit
        .library(name: "AudioKitEncorely", targets: ["AudioKitEncorely"]),
        .library(name: "AIMixtapes", targets: ["AIMixtapes"]),
        .library(name: "Domain", targets: ["Domain"]),
    .library(name: "SharedTypes", targets: ["SharedTypes"]),
    // New Noir Design System
    .library(name: "DesignSystem", targets: ["DesignSystem"])
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
        .target(
            name: "AIMixtapes",
            dependencies: ["Domain", "SharedTypes"],
            path: "Sources/AIMixtapes"
        ),
        .target(
            name: "Domain",
            dependencies: ["SharedTypes"],
            path: "Sources/Domain"
        ),
        .target(
            name: "SharedTypes",
            dependencies: [],
            path: "Sources/SharedTypes"
        ),
        .target(
            name: "DesignSystem",
            dependencies: [],
            path: "Packages/DesignSystem/Sources/DesignSystem",
            resources: [
                // Optional noise texture placeholder (user can replace with real 512x512 PNG named noise_512.png)
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AudioKitEncorelyTests",
            dependencies: ["AudioKitEncorely"],
            path: "Tests/AudioKitEncorelyTests"
        ),
        .testTarget(
            name: "AIMixtapesTests",
            dependencies: ["AIMixtapes"],
            path: "Tests/AIMixtapesTests"
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem"],
            path: "Packages/DesignSystem/Tests/DesignSystemTests"
        )
    ]
)
