// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Domain",
            type: .dynamic,
            targets: ["Domain"]),
    ],
    targets: [
        .target(
            name: "Domain",
            dependencies: []),
    ]
)
