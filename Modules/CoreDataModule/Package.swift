// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CoreDataModule",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "CoreDataModule",
            targets: ["CoreDataModule"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CoreDataModule",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "CoreDataModuleTests",
            dependencies: ["CoreDataModule"],
            path: "Tests"
        ),
    ]
)
