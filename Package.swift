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
        .package(url: "https://github.com/nalexn/ViewInspector", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "AIMixtapes",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Collections", package: "swift-collections")
            ],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "AIMixtapesTests",
            dependencies: [
                "AIMixtapes",
                "ViewInspector"
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
