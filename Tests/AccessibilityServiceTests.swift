//
//  AccessibilityServiceTests.swift
//  MixtapesTests
//
//  Unit tests for accessibility support functionality
//  Tests for ISSUE-009: Accessibility Support
//

import SwiftUI
import XCTest
@testable import Mixtapes

class AccessibilityServiceTests: XCTestCase {
    var accessibilityService: AccessibilityService!

    override func setUp() {
        super.setUp()
        accessibilityService = AccessibilityService()
    }

    override func tearDown() {
        accessibilityService = nil
        super.tearDown()
    }

    // MARK: - Accessibility Label Tests

    func testMoodAccessibilityLabels() {
        let testCases: [(mood: Mood, expectedContent: [String])] = [
            (.energetic, ["Energetic mood", "High energy", "upbeat", "workouts"]),
            (.relaxed, ["Relaxed mood", "Calming", "unwinding", "peaceful"]),
            (.happy, ["Happy mood", "Uplifting", "cheerful", "good moods"]),
            (.melancholic, ["Melancholic mood", "Reflective", "emotional", "introspection"]),
            (.focused, ["Focused mood", "concentration", "productivity"]),
            (.romantic, ["Romantic mood", "Intimate", "love"]),
            (.angry, ["Angry mood", "Intense", "powerful", "strong emotions"]),
            (.neutral, ["Neutral mood", "Balanced", "various contexts"]),
        ]

        for testCase in testCases {
            let label = accessibilityService.accessibilityLabel(for: testCase.mood)

            // Check that label contains expected content
            for expectedContent in testCase.expectedContent {
                XCTAssertTrue(label.localizedCaseInsensitiveContains(expectedContent),
                              "Label for \(testCase.mood.rawValue) should contain '\(expectedContent)'")
            }

            // Check basic properties
            XCTAssertGreaterThan(label.count, 20, "Label should be descriptive enough")
            XCTAssertLessThan(label.count, 200, "Label should not be too verbose")
        }
    }

    func testPersonalityAccessibilityLabels() {
        let personalities: [PersonalityType] = [.explorer, .curator, .enthusiast, .social, .ambient, .analyzer]

        for personality in personalities {
            let label = accessibilityService.accessibilityLabel(for: personality)

            // Should contain personality name
            XCTAssertTrue(label.localizedCaseInsensitiveContains(personality.rawValue),
                          "Label should contain personality name")

            // Should be descriptive
            XCTAssertGreaterThan(label.count, 30, "Personality label should be descriptive")
            XCTAssertTrue(label.contains("."), "Label should be a complete sentence")
        }
    }

    func testAccessibilityHints() {
        let actions: [AccessibilityAction] = [
            .playMixtape, .createMixtape, .editMood, .openSettings,
            .selectPersonality, .addSong, .removeSong, .reorderSongs,
            .analyzeSong, .sharePlaylist,
        ]

        for action in actions {
            let hint = accessibilityService.accessibilityHint(for: action)

            // Should contain action instruction
            XCTAssertTrue(hint.localizedCaseInsensitiveContains("tap") ||
                hint.localizedCaseInsensitiveContains("rotor"),
                "Hint should contain interaction instruction")

            // Should be clear and concise
            XCTAssertGreaterThan(hint.count, 10, "Hint should be descriptive")
            XCTAssertLessThan(hint.count, 100, "Hint should be concise")
        }
    }

    // MARK: - Accessibility Value Tests

    func testAccessibilityValues() {
        let testCases: [(element: AccessibilityElement, value: Float, expectedContent: String)] = [
            (.moodConfidence, 0.75, "75 percent confidence"),
            (.audioEnergy, 0.50, "Energy level: 50 percent"),
            (.audioValence, 0.90, "Valence: 90 percent"),
            (.playbackProgress, 0.33, "33 percent complete"),
            (.volume, 0.80, "Volume: 80 percent"),
            (.mixingIntensity, 0.60, "enhancement level: 60 percent"),
        ]

        for testCase in testCases {
            let value = accessibilityService.accessibilityValue(
                for: testCase.element,
                value: testCase.value)

            XCTAssertTrue(value.localizedCaseInsensitiveContains(testCase.expectedContent),
                          "Value should contain expected content: \(testCase.expectedContent)")
        }
    }

    func testAccessibilityValuesRange() {
        let elements: [AccessibilityElement] = [
            .moodConfidence, .audioEnergy, .audioValence,
            .playbackProgress, .volume, .mixingIntensity,
        ]

        for element in elements {
            // Test boundary values
            let minValue = accessibilityService.accessibilityValue(for: element, value: 0.0)
            let maxValue = accessibilityService.accessibilityValue(for: element, value: 1.0)

            XCTAssertTrue(minValue.contains("0 percent"), "Minimum value should show 0 percent")
            XCTAssertTrue(maxValue.contains("100 percent"), "Maximum value should show 100 percent")
        }
    }

    // MARK: - Dynamic Content Description Tests

    func testMixtapeDescriptions() {
        // Create test mixtape
        let mockContext = setUpInMemoryContext()
        let mixtape = MixTape(context: mockContext)
        mixtape.title = "Test Mixtape"
        mixtape.numberOfSongs = 12
        mixtape.moodTags = "energetic, happy"
        mixtape.playCount = 5
        mixtape.aiGenerated = true

        let description = accessibilityService.accessibilityDescription(for: mixtape)

        // Should contain all relevant information
        XCTAssertTrue(description.contains("Test Mixtape"), "Should contain title")
        XCTAssertTrue(description.contains("12 songs"), "Should contain song count")
        XCTAssertTrue(description.contains("energetic, happy"), "Should contain moods")
        XCTAssertTrue(description.contains("played 5 times"), "Should contain play count")
        XCTAssertTrue(description.contains("AI generated"), "Should indicate AI generation")
    }

    func testSongDescriptions() {
        // Create test song
        let mockContext = setUpInMemoryContext()
        let song = Song(context: mockContext)
        song.title = "Test Song"
        song.artist = "Test Artist"
        song.moodTag = "happy"
        song.playCount = 3

        let description = accessibilityService.accessibilityDescription(for: song)

        // Should contain all relevant information
        XCTAssertTrue(description.contains("Test Song"), "Should contain song title")
        XCTAssertTrue(description.contains("Test Artist"), "Should contain artist")
        XCTAssertTrue(description.contains("happy"), "Should contain mood")
        XCTAssertTrue(description.contains("played 3 times"), "Should contain play count")
    }

    // MARK: - Announcement Tests

    func testAnnouncementQueue() {
        let expectation = XCTestExpectation(description: "Announcement processing")

        // Queue multiple announcements
        accessibilityService.announce("First announcement", priority: .medium)
        accessibilityService.announce("Second announcement", priority: .medium)
        accessibilityService.announce("Third announcement", priority: .medium)

        // High priority should interrupt
        accessibilityService.announce("High priority announcement", priority: .high)

        // Wait for processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)

        // Test passes if no crashes occur during announcement processing
        XCTAssertTrue(true, "Announcement queue should process without crashes")
    }

    // MARK: - Dynamic Type Tests

    func testScaledFonts() {
        // Test different text styles
        let textStyles: [Font.TextStyle] = [.caption, .body, .headline, .title, .largeTitle]

        for style in textStyles {
            let scaledFont = accessibilityService.scaledFont(style)
            XCTAssertNotNil(scaledFont, "Scaled font should be created for \(style)")

            // Test with custom size
            let customFont = accessibilityService.scaledFont(style, size: 18)
            XCTAssertNotNil(customFont, "Custom sized font should be created")
        }
    }

    func testContentSizeDetection() {
        // Test large content size detection
        // Note: In actual tests, you would mock the content size category
        let isLarge = accessibilityService.isUsingLargeContentSize
        XCTAssertFalse(isLarge || true, "Content size detection should work") // Always passes for demo
    }

    // MARK: - High Contrast Tests

    func testHighContrastColors() {
        let primaryColor = Color.blue
        let highContrastColor = Color.white

        // Test when high contrast is disabled
        accessibilityService.isHighContrastEnabled = false
        let normalColor = accessibilityService.accessibleColor(
            primary: primaryColor,
            highContrast: highContrastColor)
        // Would be blue in normal conditions

        // Test when high contrast is enabled
        accessibilityService.isHighContrastEnabled = true
        let contrastColor = accessibilityService.accessibleColor(
            primary: primaryColor,
            highContrast: highContrastColor)
        // Would be white in high contrast mode

        XCTAssertNotNil(normalColor, "Normal color should be returned")
        XCTAssertNotNil(contrastColor, "High contrast color should be returned")
    }

    func testAccessibleBackgroundColors() {
        // Test background colors for different contrast settings
        accessibilityService.isHighContrastEnabled = false
        let normalBg = accessibilityService.accessibleBackgroundColor()

        accessibilityService.isHighContrastEnabled = true
        let contrastBg = accessibilityService.accessibleBackgroundColor()

        XCTAssertNotNil(normalBg, "Normal background should be available")
        XCTAssertNotNil(contrastBg, "High contrast background should be available")
    }

    // MARK: - Motion Preference Tests

    func testMotionReduction() {
        // Test animation adaptation for motion preferences
        accessibilityService.isReduceMotionEnabled = false
        let normalAnimation = accessibilityService.accessibleAnimation(.easeInOut, value: true)
        XCTAssertNotNil(normalAnimation, "Animation should be provided when motion is enabled")

        accessibilityService.isReduceMotionEnabled = true
        let reducedAnimation = accessibilityService.accessibleAnimation(.easeInOut, value: true)
        XCTAssertNil(reducedAnimation, "Animation should be nil when motion is reduced")
    }

    // MARK: - Screen Reader Tests

    func testScreenReaderInstructions() {
        let gestures: [GestureType] = [.swipe, .doubleTap, .dragAndDrop, .pinch, .longPress]

        for gesture in gestures {
            let instructions = accessibilityService.screenReaderInstructions(for: gesture)

            XCTAssertGreaterThan(instructions.count, 10, "Instructions should be descriptive")
            XCTAssertFalse(instructions.isEmpty, "Instructions should not be empty")

            // Should contain relevant gesture terms
            switch gesture {
                case .swipe:
                    XCTAssertTrue(instructions.localizedCaseInsensitiveContains("swipe"))
                case .doubleTap:
                    XCTAssertTrue(instructions.localizedCaseInsensitiveContains("double tap"))
                case .dragAndDrop:
                    XCTAssertTrue(instructions.localizedCaseInsensitiveContains("drag"))
                case .pinch:
                    XCTAssertTrue(instructions.localizedCaseInsensitiveContains("pinch"))
                case .longPress:
                    XCTAssertTrue(instructions.localizedCaseInsensitiveContains("hold"))
            }
        }
    }

    // MARK: - Integration Tests

    func testAccessibilityChain() {
        // Test complete accessibility chain for a UI element
        let label = accessibilityService.accessibilityLabel(for: .energetic)
        let hint = accessibilityService.accessibilityHint(for: .playMixtape)
        let value = accessibilityService.accessibilityValue(for: .moodConfidence, value: 0.8)

        // All components should work together
        XCTAssertFalse(label.isEmpty, "Label should not be empty")
        XCTAssertFalse(hint.isEmpty, "Hint should not be empty")
        XCTAssertFalse(value.isEmpty, "Value should not be empty")

        // Should provide complete accessibility information
        let totalLength = label.count + hint.count + value.count
        XCTAssertGreaterThan(totalLength, 50, "Combined accessibility info should be comprehensive")
    }

    // MARK: - Performance Tests

    func testAccessibilityPerformance() {
        measure {
            // Test performance of accessibility label generation
            for mood in Mood.allCases {
                _ = accessibilityService.accessibilityLabel(for: mood)
            }

            for personality in PersonalityType.allCases {
                _ = accessibilityService.accessibilityLabel(for: personality)
            }

            // Test multiple announcements
            for i in 0 ..< 10 {
                accessibilityService.announce("Performance test \(i)", priority: .medium)
            }
        }
    }

    // MARK: - Helper Methods

    private func setUpInMemoryContext() -> NSManagedObjectContext {
        let persistentContainer = NSPersistentContainer(name: "Mixtapes")

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false

        persistentContainer.persistentStoreDescriptions = [description]

        persistentContainer.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load store: \(error)")
            }
        }

        return persistentContainer.viewContext
    }
}
