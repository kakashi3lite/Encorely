// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AIModule",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "AIModule",
            targets: ["AIModule"]
        )
    ],
    dependencies: [
        .package(path: "../AudioAnalysisModule"),
        .package(path: "../MusicKitModule")
    ],
    targets: [
        .target(
            name: "AIModule",
            dependencies: [
                "AudioAnalysisModule",
                "MusicKitModule"
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "AIModuleTests",
            dependencies: ["AIModule"],
            path: "Tests"
        )
    ]
)