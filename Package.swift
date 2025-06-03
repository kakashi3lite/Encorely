// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AI-Mixtapes",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "AI-Mixtapes",
            targets: ["App"]
        ),
        .library(
            name: "SharedTypes",
            targets: ["SharedTypes"]
        )
    ],
    dependencies: [
        // Local Modules
        .package(path: "Modules/MusicKitModule"),
        .package(path: "Modules/AudioAnalysisModule"),
        
        // External Dependencies
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.5.0"),
        .package(url: "https://github.com/AudioKit/AudioKit", from: "5.6.0"),
        .package(url: "https://github.com/AudioKit/SoundpipeAudioKit", from: "5.6.0"),
        .package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.0.1")
    ],
    targets: [
        .target(
            name: "SharedTypes",
            dependencies: []
        ),
        .executableTarget(
            name: "App",
            dependencies: [
                "SharedTypes",
                // Local Modules
                .product(name: "MusicKitModule", package: "MusicKitModule"),
                .product(name: "AudioAnalysisModule", package: "AudioAnalysisModule"),
                .product(name: "VisualizationModule", package: "VisualizationModule"),
                
                // External Dependencies
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "AudioKit", package: "AudioKit"),
                .product(name: "SoundpipeAudioKit", package: "SoundpipeAudioKit"),
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ],
            path: "Sources/App",
            resources: [
                .process("Resources/Assets.xcassets"),
                .process("Resources/LaunchScreen.storyboard"),
                .process("Resources/AI_Mixtapes.xcdatamodeld"),
                .process("Resources/Intents.intentdefinition"),
                .process("Resources/MLModels"),
                .process("Resources/Audio")
            ]
        ),
        
        // Test Targets
        .testTarget(
            name: "AppTests",
            dependencies: [
                "App",
                .product(name: "MusicKitModule", package: "MusicKitModule"),
                .product(name: "AIModule", package: "AIModule"),
                .product(name: "AudioAnalysisModule", package: "AudioAnalysisModule"),
                .product(name: "CoreDataModule", package: "CoreDataModule"),
                .product(name: "UtilitiesModule", package: "UtilitiesModule")
            ],
            path: "Tests/AppTests"
        ),
        
        .testTarget(
            name: "AIModuleTests",
            dependencies: [
                .product(name: "AIModule", package: "AIModule"),
                .product(name: "UtilitiesModule", package: "UtilitiesModule")
            ],
            path: "Tests/AIModuleTests"
        ),
        
        .testTarget(
            name: "AudioAnalysisModuleTests",
            dependencies: [
                .product(name: "AudioAnalysisModule", package: "AudioAnalysisModule"),
                .product(name: "UtilitiesModule", package: "UtilitiesModule"),
                .product(name: "AudioKit", package: "AudioKit")
            ],
            path: "Tests/AudioAnalysisModuleTests"
        ),
        
        .testTarget(
            name: "IntegrationTests",
            dependencies: [
                "App",
                .product(name: "MusicKitModule", package: "MusicKitModule"),
                .product(name: "AIModule", package: "AIModule"),
                .product(name: "AudioAnalysisModule", package: "AudioAnalysisModule"),
                .product(name: "CoreDataModule", package: "CoreDataModule")
            ],
            path: "Tests/IntegrationTests",
            resources: [
                .process("TestData")
            ]
        )
    ]
)

// MARK: - Swift Settings

extension SwiftSetting {
    static let enableStrictConcurrency = SwiftSetting.enableExperimentalFeature("StrictConcurrency")
    static let enableActorDataRaceChecks = SwiftSetting.enableExperimentalFeature("ActorDataRaceChecks")
}

// MARK: - Platform-specific configurations

#if os(iOS)
package.targets.append(
    .target(
        name: "WatchKitExtension",
        dependencies: [
            .product(name: "UtilitiesModule", package: "UtilitiesModule"),
            .product(name: "AIModule", package: "AIModule")
        ],
        path: "Sources/WatchKitExtension"
    )
)
#endif

    // MCP packages
    .target(
        name: "MCPClient",
        dependencies: [
            .product(name: "SocketIO", package: "socket.io-client-swift")
        ]
    ),
    .target(
        name: "MCPServer",
        dependencies: [
            .product(name: "Express", package: "express"),
            .product(name: "SocketIO", package: "socket.io")
        ]
    )
)

let package = Package(
    name: "AI-Mixtapes",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "MCPClient", targets: ["MCPClient"]),
        .library(name: "MCPServer", targets: ["MCPServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/socketio/socket.io-client-swift.git", from: "16.0.0"),
        .package(url: "https://github.com/expressjs/express.git", from: "4.18.2"),
        .package(url: "https://github.com/socketio/socket.io.git", from: "4.7.1")
    ],
    targets: allTargets
)

// MARK: - Build Configuration

extension Target {
    static func appTarget() -> Target {
        return .executableTarget(
            name: "App",
            dependencies: [
                .target(name: "MCPClient"),
                // All module dependencies listed above
            ],
            path: "Sources/App",
            swiftSettings: [
                .enableStrictConcurrency,
                .enableActorDataRaceChecks,
                .define("AI_MIXTAPES_PRODUCTION", .when(configuration: .release)),
                .define("AI_MIXTAPES_DEBUG", .when(configuration: .debug))
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreML"),
                .linkedFramework("Vision"),
                .linkedFramework("SoundAnalysis"),
                .linkedFramework("MusicKit"),
                .linkedFramework("Intents"),
                .linkedFramework("IntentsUI"),
                .linkedFramework("CoreData"),
                .linkedFramework("Combine"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("UIKit")
            ]
        )
    }
}

// MARK: - Module Descriptions

/*
Module Dependencies Overview:

1. MusicKitModule
   - Handles Apple Music integration
   - Music playback controls
   - Playlist management
   - Dependencies: MusicKit, AVFoundation

2. AIModule
   - Core AI services (MoodEngine, PersonalityEngine)
   - ML model management
   - Recommendation algorithms
   - Dependencies: CoreML, Vision, SoundAnalysis

3. AudioAnalysisModule
   - Real-time audio processing
   - FFT analysis and visualization
   - Audio feature extraction
   - Dependencies: AudioKit, AVFoundation

4. CoreDataModule
   - Data persistence layer
   - Core Data stack management
   - Entity relationships
   - Dependencies: CoreData

5. NetworkingModule
   - API communication
   - Network request handling
   - Error management
   - Dependencies: Foundation, Combine

6. UIComponentsModule
   - Reusable SwiftUI components
   - Custom UI elements
   - Design system components
   - Dependencies: SwiftUI

7. UtilitiesModule
   - Shared utilities and extensions
   - Common helper functions
   - Constants and configurations
   - Dependencies: Foundation

8. SiriKitModule
   - Voice command handling
   - Intent definitions and handling
   - Siri integration
   - Dependencies: Intents, IntentsUI

9. VisualizationModule
   - Audio visualization components
   - Real-time graphics rendering
   - Data visualization utilities
   - Dependencies: SwiftUI, CoreGraphics
*/
