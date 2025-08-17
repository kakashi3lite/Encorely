// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "AudioAnalysisModule",
    platforms: [
        .iOS(.v15),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "AudioAnalysisModule",
            targets: ["AudioAnalysisModule"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.0"),
    ],
    targets: [
        .target(
            name: "AudioAnalysisModule",
            dependencies: [
                "AudioKit",
            ],
            linkerSettings: [
                .linkedFramework("Accelerate"),
            ]
        ),
        .testTarget(
            name: "AudioAnalysisModuleTests",
            dependencies: ["AudioAnalysisModule"]
        ),
    ]
)
