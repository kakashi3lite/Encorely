@testable import App
import Speech
import XCTest

class VoiceCommandTests: XCTestCase {
    var processor: VoiceCommandProcessor!
    var receivedCommands: [VoiceCommand] = []

    override func setUp() {
        super.setUp()
        processor = VoiceCommandProcessor()
        setupCommandListener()
    }

    override func tearDown() {
        receivedCommands = []
        processor = nil
        super.tearDown()
    }

    // MARK: - Test Command Processing

    func testMoodDetection() {
        // Test explicit mood commands
        processTestCommand(
            "play something energetic",
            segments: [
                createSegment(text: "play", confidence: 0.9),
                createSegment(text: "something", confidence: 0.9),
                createSegment(text: "energetic", confidence: 0.85),
            ]
        )

        XCTAssertEqual(receivedCommands.count, 1)
        if case let .setMood(mood) = receivedCommands.first {
            XCTAssertEqual(mood, .energetic)
        } else {
            XCTFail("Expected setMood command")
        }

        // Clear received commands
        receivedCommands = []

        // Test implicit mood through activity
        processTestCommand(
            "i need music for studying",
            segments: [
                createSegment(text: "i need", confidence: 0.9),
                createSegment(text: "music", confidence: 0.9),
                createSegment(text: "for studying", confidence: 0.85),
            ]
        )

        XCTAssertEqual(receivedCommands.count, 1)
        if case let .setMood(mood) = receivedCommands.first {
            XCTAssertEqual(mood, .focused)
        } else {
            XCTFail("Expected setMood command")
        }
    }

    func testLowConfidenceRejection() {
        processTestCommand(
            "play something energetic",
            segments: [
                createSegment(text: "play", confidence: 0.9),
                createSegment(text: "something", confidence: 0.9),
                createSegment(text: "energetic", confidence: 0.5), // Low confidence
            ]
        )

        XCTAssertTrue(receivedCommands.isEmpty)
    }

    func testComplexCommands() {
        processTestCommand(
            "i need energetic music for my workout",
            segments: [
                createSegment(text: "i need", confidence: 0.9),
                createSegment(text: "energetic", confidence: 0.85),
                createSegment(text: "music", confidence: 0.9),
                createSegment(text: "for my workout", confidence: 0.85),
            ]
        )

        XCTAssertEqual(receivedCommands.count, 1)
        if case let .setMood(mood) = receivedCommands.first {
            XCTAssertEqual(mood, .energetic)
        }
    }

    func testNoTriggerWordIgnored() {
        processTestCommand(
            "this is energetic music",
            segments: [
                createSegment(text: "this is", confidence: 0.9),
                createSegment(text: "energetic", confidence: 0.85),
                createSegment(text: "music", confidence: 0.9),
            ]
        )

        XCTAssertTrue(receivedCommands.isEmpty)
    }

    // MARK: - Helper Methods

    private func setupCommandListener() {
        processor.commandStream.sink { [weak self] command in
            self?.receivedCommands.append(command)
        }.store(in: &subscriptions)
    }

    private func processTestCommand(_ transcript: String, segments: [VoiceSegment]) {
        processor.processCommand(transcript: transcript, segments: segments)
    }

    private func createSegment(text: String, confidence: Float) -> VoiceSegment {
        VoiceSegment(
            text: text,
            confidence: confidence,
            timestamp: 0.0,
            duration: 1.0
        )
    }

    private var subscriptions = Set<AnyCancellable>()
}
