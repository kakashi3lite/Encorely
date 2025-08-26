// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AI-Mixtapes",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(name: "AI-Mixtapes", targets: ["App"]),
        .library(name: "SharedTypes", targets: ["SharedTypes"]),
        .library(name: "MCPClient", targets: ["MCPClient"])
    ],
    dependencies: [
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
        // Main App Target
        .executableTarget(
            name: "App",
            dependencies: [
                "SharedTypes",
                "MCPClient",
                .product(name: "AudioKit", package: "AudioKit"),
                .product(name: "SoundpipeAudioKit", package: "SoundpipeAudioKit"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Sources/App",
            exclude: [
                "utils/install-hooks.sh",
                "utils/pre-commit-hook.sh"
            ],
            sources: ["Consolidated"],
            resources: [
                .process("Resources")
            ]
        ),
        
        // Shared Types
        .target(
            name: "SharedTypes",
            dependencies: [],
            path: "Sources/SharedTypes"
        ),
        
        // MCP Client
        .target(
            name: "MCPClient",
            dependencies: [
                "SharedTypes",
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ],
            path: "Sources/MCPClient"
        ),
        
        // Test Targets
        .testTarget(
            name: "AIMixtapesTests",
            dependencies: ["App"],
            path: "Tests/AIMixtapesTests",
            resources: [.copy("TestResources")]
        )
    ]
)

#if os(iOS)
package.targets.append(
    .target(
        name: "WatchKitExtension",
        dependencies: [
            "SharedTypes",
            .product(name: "UtilitiesModule", package: "UtilitiesModule"),
            .product(name: "AIModule", package: "AIModule")
        ],
        path: "Sources/WatchKitExtension",
        swiftSettings: [
            .enableUpcomingFeature("StrictConcurrency"),
            .enableUpcomingFeature("ActorDataRaceChecks")
        ]
    )
)
#endif

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
