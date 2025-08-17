// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "MusicKitModule",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
    ],
    products: [
        .library(
            name: "MusicKitModule",
            targets: ["MusicKitModule"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.0"),
    ],
    targets: [
        .target(
            name: "MusicKitModule",
            dependencies: [
                .product(name: "AudioKit", package: "AudioKit"),
            ]
        ),
        .testTarget(
            name: "MusicKitModuleTests",
            dependencies: ["MusicKitModule"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
