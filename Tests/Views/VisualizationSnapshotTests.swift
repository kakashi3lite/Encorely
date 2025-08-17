@testable import App
import SnapshotTesting
import SwiftUI
import XCTest

final class VisualizationSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Configure snapshot testing for CI environment if needed
        #if os(macOS)
            isRecording = false
        #endif
    }

    func testAnimatedVisualizationViewAllMoods() {
        let moods: [Mood] = [.calm, .energetic, .happy, .melancholic]
        let audioData = Array(repeating: Float(0.5), count: 40)

        for mood in moods {
            let view = AnimatedVisualizationView(
                audioData: audioData,
                mood: mood,
                sensitivity: 1.0
            )
            .frame(width: 390, height: 300) // iPhone 12 Pro width

            let hostingController = NSHostingController(rootView: view)
            assertSnapshot(
                matching: hostingController,
                as: .image(size: CGSize(width: 390, height: 300)),
                named: "AnimatedVisualization_\(mood)"
            )
        }
    }

    func testAnimatedVisualizationViewAudioLevels() {
        let audioLevels: [(String, [Float])] = [
            ("silent", Array(repeating: Float(0.0), count: 40)),
            ("medium", Array(repeating: Float(0.5), count: 40)),
            ("loud", Array(repeating: Float(1.0), count: 40)),
            ("dynamic", (0 ..< 40).map { Float(sin(Double($0) * .pi / 20)) }),
        ]

        for (name, levels) in audioLevels {
            let view = AnimatedVisualizationView(
                audioData: levels,
                mood: .energetic,
                sensitivity: 1.0
            )
            .frame(width: 390, height: 300)

            let hostingController = NSHostingController(rootView: view)
            assertSnapshot(
                matching: hostingController,
                as: .image(size: CGSize(width: 390, height: 300)),
                named: "AnimatedVisualization_AudioLevel_\(name)"
            )
        }
    }

    func testAnimatedVisualizationViewSensitivityLevels() {
        let sensitivities: [(String, Double)] = [
            ("low", 0.1),
            ("normal", 1.0),
            ("high", 2.0),
        ]

        let audioData = (0 ..< 40).map { Float(sin(Double($0) * .pi / 20)) }

        for (name, sensitivity) in sensitivities {
            let view = AnimatedVisualizationView(
                audioData: audioData,
                mood: .energetic,
                sensitivity: sensitivity
            )
            .frame(width: 390, height: 300)

            let hostingController = NSHostingController(rootView: view)
            assertSnapshot(
                matching: hostingController,
                as: .image(size: CGSize(width: 390, height: 300)),
                named: "AnimatedVisualization_Sensitivity_\(name)"
            )
        }
    }

    func testAnimatedVisualizationViewDarkMode() {
        let view = AnimatedVisualizationView(
            audioData: Array(repeating: Float(0.5), count: 40),
            mood: .energetic,
            sensitivity: 1.0
        )
        .frame(width: 390, height: 300)
        .preferredColorScheme(.dark)

        let hostingController = NSHostingController(rootView: view)
        assertSnapshot(
            matching: hostingController,
            as: .image(size: CGSize(width: 390, height: 300)),
            named: "AnimatedVisualization_DarkMode"
        )
    }

    func testAnimatedVisualizationViewSizeVariants() {
        let sizes: [(String, CGSize)] = [
            ("compact", CGSize(width: 320, height: 200)), // Small phone
            ("regular", CGSize(width: 390, height: 300)), // Regular phone
            ("large", CGSize(width: 428, height: 340)), // Large phone
            ("iPad", CGSize(width: 744, height: 500)), // iPad
        ]

        let audioData = Array(repeating: Float(0.5), count: 40)

        for (name, size) in sizes {
            let view = AnimatedVisualizationView(
                audioData: audioData,
                mood: .energetic,
                sensitivity: 1.0
            )
            .frame(width: size.width, height: size.height)

            let hostingController = NSHostingController(rootView: view)
            assertSnapshot(
                matching: hostingController,
                as: .image(size: size),
                named: "AnimatedVisualization_Size_\(name)"
            )
        }
    }

    func testAnimatedVisualizationViewAccessibility() {
        let view = AnimatedVisualizationView(
            audioData: Array(repeating: Float(0.5), count: 40),
            mood: .energetic,
            sensitivity: 1.0
        )
        .frame(width: 390, height: 300)
        .environment(\.accessibilityEnabled, true)

        let hostingController = NSHostingController(rootView: view)
        assertSnapshot(
            matching: hostingController,
            as: .image(size: CGSize(width: 390, height: 300)),
            named: "AnimatedVisualization_Accessibility"
        )
    }
}
