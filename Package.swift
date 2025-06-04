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
        .executable(name: "AI-Mixtapes", targets: ["App"]),
        .library(name: "SharedTypes", targets: ["SharedTypes"]),
        .library(name: "MCPClient", targets: ["MCPClient"])
    ],
    dependencies: [
        // Local Modules
        .package(path: "Modules/MusicKitModule"),
        .package(path: "Modules/AudioAnalysisModule"),
        .package(path: "Modules/VisualizationModule"),
        .package(path: "Modules/AIModule"),
        .package(path: "Modules/CoreDataModule"),
        .package(path: "Modules/UtilitiesModule"),
        
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
                .product(name: "MusicKitModule", package: "MusicKitModule"),
                .product(name: "AIModule", package: "AIModule"),
                .product(name: "AudioAnalysisModule", package: "AudioAnalysisModule"),
                .product(name: "CoreDataModule", package: "CoreDataModule"),
                .product(name: "UtilitiesModule", package: "UtilitiesModule"),
                .product(name: "VisualizationModule", package: "VisualizationModule"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "AudioKit", package: "AudioKit"),
                .product(name: "SoundpipeAudioKit", package: "SoundpipeAudioKit")
            ],
            path: "Sources/App",
            resources: [
                .copy("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("ActorDataRaceChecks")
            ]
        ),
        
        // MCP Client
        .target(
            name: "MCPClient",
            dependencies: [
                "SharedTypes",
                .product(name: "SocketIO", package: "socket.io-client-swift")
            ],
            path: "Sources/MCPClient",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("ActorDataRaceChecks")
            ]
        ),
        
        // Shared Types
        .target(
            name: "SharedTypes",
            dependencies: [],
            path: "Sources/SharedTypes",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableUpcomingFeature("ActorDataRaceChecks")
            ]
        ),
        
        // Test Targets
        .testTarget(
            name: "AIMixtapesTests",
            dependencies: [
                "App",
                .product(name: "MusicKitModule", package: "MusicKitModule"),
                .product(name: "AIModule", package: "AIModule"),
                .product(name: "AudioAnalysisModule", package: "AudioAnalysisModule"),
                .product(name: "CoreDataModule", package: "CoreDataModule"),
                .product(name: "UtilitiesModule", package: "UtilitiesModule")
            ],
            path: "Tests/AI-MixtapesTests",
            resources: [
                .copy("TestData")
            ]
        ),
        
        .testTarget(
            name: "UITests",
            dependencies: [
                "App"
            ],
            path: "Tests/UITests",
            resources: [
                .copy("TestUtils")
            ]
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
