// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VisualizationModule",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "VisualizationModule",
            targets: ["VisualizationModule"]
        ),
    ],
    dependencies: [
        .package(path: "../AudioAnalysisModule"),
        .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.0"),
    ],
    targets: [
        .target(
            name: "VisualizationModule",
            dependencies: [
                "AudioAnalysisModule",
                .product(name: "AudioKit", package: "AudioKit"),
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "VisualizationModuleTests",
            dependencies: ["VisualizationModule"],
            path: "Tests"
        ),
    ]
)
