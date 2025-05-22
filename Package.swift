// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "AIMixtapes",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "AIMixtapes",
            targets: ["AIMixtapes"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.9.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.2.0"),
        .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.11.1")
    ],
    targets: [
        .target(
            name: "AIMixtapes",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "AudioKit", package: "AudioKit")
            ],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "AIMixtapesTests",
            dependencies: [
                "AIMixtapes",
                "ViewInspector",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            resources: [
                .copy("TestResources")
            ]),
        .testTarget(
            name: "AIMixtapesUITests",
            dependencies: [
                "AIMixtapes",
                "ViewInspector"
            ])
    ],
    swiftLanguageVersions: [.v5]
)
