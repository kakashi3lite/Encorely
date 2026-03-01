// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Encorely",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Encorely", targets: ["Encorely"])
    ],
    dependencies: [
        .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.0"),
        .package(url: "https://github.com/AudioKit/SoundpipeAudioKit", from: "5.6.0"),
    ],
    targets: [
        .target(
            name: "Encorely",
            dependencies: [
                .product(name: "AudioKit", package: "AudioKit"),
                .product(name: "SoundpipeAudioKit", package: "SoundpipeAudioKit"),
            ],
            path: "Encorely",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "EncorelyTests",
            dependencies: ["Encorely"],
            path: "EncorelyTests"
        ),
    ]
)
