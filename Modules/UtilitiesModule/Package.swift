// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "UtilitiesModule",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "UtilitiesModule",
            targets: ["UtilitiesModule"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "UtilitiesModule",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "UtilitiesModuleTests",
            dependencies: ["UtilitiesModule"],
            path: "Tests"
        )
    ]
)
