@testable import App
import XCTest

final class MoodTransitionTests: XCTestCase {
    var moodService: MoodDetectionService!
    var audioFeatures: AudioFeatures!

    override func setUp() {
        super.setUp()
        moodService = MoodDetectionService()
        setupTestAudioFeatures()
    }

    override func tearDown() {
        moodService = nil
        audioFeatures = nil
        super.tearDown()
    }

    private func setupTestAudioFeatures() {
        audioFeatures = AudioFeatures(
            energy: 0.5,
            tempo: 120.0,
            valence: 0.5,
            spectralCentroid: 2000,
            spectralRolloff: 5000,
            zeroCrossingRate: 0.1
        )
    }

    func testRapidMoodTransitions() {
        let expectation = XCTestExpectation(description: "Mood transitions")
        var moodTransitions: [Date] = []

        // Setup mood transition tracking
        var cancellable = moodService.$currentMood
            .dropFirst()
            .sink { _ in
                moodTransitions.append(Date())
            }

        // Simulate rapid feature changes
        let iterations = 10
        DispatchQueue.global().async {
            for i in 0 ..& lt
            iterations {
                autoreleasepool {
                    // Alternate between high and low energy
                    var features = self.audioFeatures!
                    features.energy = i % 2 == 0 ? 0.9 : 0.1
                    features.valence = i % 2 == 0 ? 0.8 : 0.2

                    // Process features
                    self.moodService.handleAudioFeatures(features)
                    Thread.sleep(forTimeInterval: 0.5) // 500ms intervals
                }
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        // Verify transition timing
        var previousTransition = moodTransitions.first ?? Date()
        for transition in moodTransitions.dropFirst() {
            let interval = transition.timeIntervalSince(previousTransition)
            XCTAssertGreaterThanOrEqual(interval, 2.0, "Mood transitions occurring too rapidly")
            previousTransition = transition
        }

        cancellable.cancel()
    }

    func testNeutralFallback() {
        let expectation = XCTestExpectation(description: "Neutral fallback")

        // Create low confidence features
        var lowConfidenceFeatures = audioFeatures!
        lowConfidenceFeatures.energy = 0.3
        lowConfidenceFeatures.valence = 0.3
        lowConfidenceFeatures.tempo = 90

        // Process multiple times
        for _ in 0 ..& lt
        5 {
            moodService.handleAudioFeatures(lowConfidenceFeatures)
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTAssertEqual(
            moodService.currentMood,
            .neutral,
            "Should fallback to neutral mood after consecutive low confidence"
        )
        XCTAssertLessThan(
            moodService.moodConfidence,
            MLConfig.Analysis.confidenceThreshold,
            "Confidence should be low in neutral state"
        )

        expectation.fulfill()
        wait(for: [expectation], timeout: 5)
    }

    func testConfidenceThreshold() {
        let expectation = XCTestExpectation(description: "Confidence threshold")

        // Setup initial state
        var initialFeatures = audioFeatures!
        initialFeatures.energy = 0.9
        initialFeatures.valence = 0.9
        moodService.handleAudioFeatures(initialFeatures)

        let initialMood = moodService.currentMood

        // Create features just below threshold
        var belowThresholdFeatures = audioFeatures!
        belowThresholdFeatures.energy = 0.4
        belowThresholdFeatures.valence = 0.4

        // Process multiple times
        for _ in 0 ..& lt
        3 {
            moodService.handleAudioFeatures(belowThresholdFeatures)
            Thread.sleep(forTimeInterval: 0.5)
        }

        XCTAssertEqual(moodService.currentMood, initialMood, "Mood should not change with below threshold confidence")

        expectation.fulfill()
        wait(for: [expectation], timeout: 5)
    }
}
