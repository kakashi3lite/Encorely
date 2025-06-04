import XCTest
import CoreML
import Vision
@testable import App

class AITests: XCTestCase {
    var colorTransitionManager: ColorTransitionManager!
    var moodEngine: MoodEngine!
    var personalityEngine: PersonalityEngine!
    var aiLogger: AILogger!
    
    override func setUp() {
        super.setUp()
        colorTransitionManager = ColorTransitionManager()
        moodEngine = MoodEngine()
        personalityEngine = PersonalityEngine()
        aiLogger = AILogger.shared
    }
    
    override func tearDown() {
        colorTransitionManager = nil
        moodEngine = nil
        personalityEngine = nil
        aiLogger.resetMetrics()
        super.tearDown()
    }
    
    // MARK: - Model Loading Tests
    
    func testModelLoading() {
        // Test emotion classifier loading
        XCTAssertNoThrow(try MLConfig.loadModel(.emotionClassifier) as MLModel)
        
        // Test audio features model loading
        XCTAssertNoThrow(try MLConfig.loadModel(.audioFeatures) as MLModel)
        
        // Test personality predictor loading
        XCTAssertNoThrow(try MLConfig.loadModel(.personalityPredictor) as MLModel)
    }
    
    // MARK: - Mood Detection Tests
    
    func testMoodDetection() async {
        // Given
        let audioURL = Bundle.main.url(forResource: "happy_song", withExtension: "mp3")!
        
        // When
        let mood = try? await moodEngine.detectMood(from: audioURL)
        
        // Then
        XCTAssertNotNil(mood)
        if let detectedMood = mood {
            XCTAssertGreaterThanOrEqual(detectedMood.confidence, MLConfig.Thresholds.minimumEmotionConfidence)
        }
    }
    
    func testMoodDetectionWithInvalidAudio() async {
        // Given
        let invalidURL = URL(fileURLWithPath: "nonexistent.mp3")
        
        // When/Then
        do {
            _ = try await moodEngine.detectMood(from: invalidURL)
            XCTFail("Should throw error for invalid audio")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }
    
    // MARK: - Personality Engine Tests
    
    func testPersonalityPrediction() {
        // Given
        let listeningHistory = MockData.createListeningHistory()
        
        // When
        let personality = personalityEngine.predictPersonality(from: listeningHistory)
        
        // Then
        XCTAssertNotNil(personality)
        XCTAssertGreaterThanOrEqual(personality.confidence, MLConfig.Thresholds.minimumPersonalityMatchConfidence)
    }
    
    // MARK: - Performance Tests
    
    func testInferencePerformance() async {
        // Given
        let audioURL = Bundle.main.url(forResource: "test_audio", withExtension: "mp3")!
        measure {
            // When/Then
            let expectation = expectation(description: "Mood detection")
            Task {
                let startTime = Date()
                _ = try? await moodEngine.detectMood(from: audioURL)
                let duration = Date().timeIntervalSince(startTime)
                
                XCTAssertLessThanOrEqual(duration, MLConfig.Thresholds.maximumInferenceTime)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testMemoryUsage() {
        // Given
        let startMemory = reportMemoryUsage()
        
        // When
        for _ in 0..<100 {
            _ = personalityEngine.predictPersonality(from: MockData.createListeningHistory())
        }
        
        // Then
        let endMemory = reportMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        XCTAssertLessThanOrEqual(memoryIncrease, 150 * 1024 * 1024) // 150MB limit
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecovery() async {
        // Given
        var attempts = 0
        let maxAttempts = MLConfig.ErrorRecovery.maxRetryAttempts
        
        // When
        do {
            try await withRetries {
                attempts += 1
                if attempts < maxAttempts {
                    throw AppError.inferenceError
                }
            }
            // Then
            XCTAssertEqual(attempts, maxAttempts)
        } catch {
            XCTFail("Should recover after retries")
        }
    }
    
    // MARK: - Metrics Logging Tests
    
    func testMetricsLogging() {
        // Given
        aiLogger.resetMetrics()
        
        // When
        aiLogger.logInference(model: "EmotionClassifier", duration: 0.05, success: true)
        aiLogger.logUserFeedback(feature: "moodDetection", isPositive: true)
        
        // Then
        let report = aiLogger.getModelPerformanceReport()
        XCTAssertNotNil(report["inferenceMetrics"])
        XCTAssertNotNil(report["userFeedback"])
    }
    
    // MARK: - Recommendation Engine Tests
    
    func testMixtapeGeneration() async throws {
        // Given
        let recommendationEngine = RecommendationEngine(
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        // When
        let mixtape = try await recommendationEngine.generateMixtape(length: 5)
        
        // Then
        XCTAssertNotNil(mixtape)
        XCTAssertEqual(mixtape.songs?.count, 5)
        XCTAssertTrue(mixtape.isAIGenerated)
        XCTAssertNotNil(mixtape.mood)
    }
    
    func testRecommendationGeneration() async throws {
        // Given
        let recommendationEngine = RecommendationEngine(
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        // When
        let recommendations = try await recommendationEngine.getRecommendations(limit: 5)
        
        // Then
        XCTAssertEqual(recommendations.count, 5)
        for song in recommendations {
            XCTAssertNotNil(song.mood)
            XCTAssertGreaterThan(song.energy, 0)
            XCTAssertNotNil(song.genre)
        }
    }
    
    // MARK: - Personality Engine Tests
    
    func testPersonalityAnalysis() {
        // Given
        let listeningHistory: [String: Any] = [
            "genres": ["rock": 0.6, "jazz": 0.3, "classical": 0.1],
            "timeOfDay": ["morning": 0.3, "afternoon": 0.4, "evening": 0.3],
            "tempo": ["slow": 0.2, "medium": 0.5, "fast": 0.3]
        ]
        
        // When
        let prediction = personalityEngine.predictPersonality(from: listeningHistory)
        
        // Then
        XCTAssertNotNil(prediction.personality)
        XCTAssertGreaterThanOrEqual(prediction.confidence, MLConfig.Thresholds.minimumPersonalityMatchConfidence)
    }
    
    func testPersonalityTraits() {
        // Given
        let listeningHistory: [String: Any] = [
            "genres": ["rock": 0.8, "jazz": 0.1, "classical": 0.1],
            "timeOfDay": ["morning": 0.2, "afternoon": 0.6, "evening": 0.2],
            "tempo": ["slow": 0.1, "medium": 0.3, "fast": 0.6]
        ]
        
        // When
        let prediction = personalityEngine.predictPersonality(from: listeningHistory)
        
        // Then
        XCTAssertFalse(personalityEngine.traits.isEmpty)
        XCTAssertEqual(personalityEngine.traits.count, 3) // Each personality has 3 traits
        XCTAssertGreaterThanOrEqual(personalityEngine.traits.first?.strength ?? 0, 0.7)
    }
    
    // MARK: - Integration Tests
    
    func testMoodPersonalityIntegration() async throws {
        // Given
        let recommendationEngine = RecommendationEngine(
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        // When - Change mood
        moodEngine.setMood(.energetic, confidence: 0.9)
        
        // Generate recommendations
        let recommendations = try await recommendationEngine.getRecommendations(limit: 5)
        
        // Then
        XCTAssertFalse(recommendations.isEmpty)
        XCTAssertEqual(recommendations.first?.mood, .energetic)
    }
    
    func testAudioMoodDetection() async throws {
        // Given
        let audioURL = Bundle.main.url(forResource: "test_audio", withExtension: "mp3")!
        let buffer = try await loadAudioBuffer(from: audioURL)
        
        // When
        let features = fftProcessor.extractFeatures(from: Array(buffer))
        let indicators = features.moodIndicators()
        
        // Then
        XCTAssertGreaterThan(indicators.energy, 0)
        XCTAssertGreaterThan(indicators.brightness, 0)
        XCTAssertGreaterThan(indicators.complexity, 0)
        XCTAssertGreaterThan(indicators.density, 0)
    }
    
    func testRealtimeProcessing() async {
        // Given
        let expectation = expectation(description: "Real-time processing")
        let moodDetectionService = MoodDetectionService()
        var moodUpdates: [MoodPrediction] = []
        
        // When
        moodDetectionService.moodPublisher
            .sink { prediction in
                moodUpdates.append(prediction)
                if moodUpdates.count >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        try? moodDetectionService.startMoodDetection()
        
        // Then
        await fulfillment(of: [expectation], timeout: 5)
        XCTAssertGreaterThanOrEqual(moodUpdates.count, 3)
        XCTAssertGreaterThan(moodUpdates.first?.confidence ?? 0, 0.5)
    }
    
    // MARK: - Performance Tests
    
    func testAudioProcessingPerformance() {
        measure {
            let samples = (0..<2048).map { _ in Float.random(in: -1...1) }
            let features = fftProcessor.extractFeatures(from: samples)
            XCTAssertNotNil(features)
        }
    }
    
    func testRecommendationPerformance() async {
        let recommendationEngine = RecommendationEngine(
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        measure {
            let expectation = expectation(description: "Recommendations")
            
            Task {
                let recommendations = try? await recommendationEngine.getRecommendations(limit: 10)
                XCTAssertNotNil(recommendations)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5)
        }
    }
    
    // MARK: - Mood Color Transition Tests
    
    func testMoodColorTransitions() {
        // Test mood transitions
        let expectation = XCTestExpectation(description: "Mood transition")
        
        // Initial state
        XCTAssertEqual(colorTransitionManager.currentMoodColor, .happy)
        
        // Transition to new mood
        colorTransitionManager.transition(to: .energetic) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(colorTransitionManager.currentMoodColor, .energetic)
    }
    
    func testPersonalityColorUpdates() {
        // Test personality updates
        XCTAssertEqual(colorTransitionManager.currentPersonalityColor, .enthusiast)
        
        colorTransitionManager.updatePersonality(.curator)
        XCTAssertEqual(colorTransitionManager.currentPersonalityColor, .curator)
    }
    
    func testColorAssetAvailability() {
        // Test mood colors
        for mood in Asset.MoodColor.allCases {
            XCTAssertNotNil(mood.color, "Mood color \(mood.rawValue) should exist")
            XCTAssertNotNil(mood.uiColor, "UIColor for mood \(mood.rawValue) should exist")
        }
        
        // Test personality colors
        for personality in Asset.PersonalityColor.allCases {
            XCTAssertNotNil(personality.color, "Personality color \(personality.rawValue) should exist")
            XCTAssertNotNil(personality.uiColor, "UIColor for personality \(personality.rawValue) should exist")
        }
    }
    
    func testMoodEngineIntegration() {
        let moodExpectation = XCTestExpectation(description: "Mood detection")
        
        // Test mood detection
        moodEngine.detectMood(from: "energetic upbeat music") { result in
            switch result {
            case .success(let mood):
                XCTAssertEqual(mood, .energetic)
            case .failure(let error):
                XCTFail("Mood detection failed: \(error)")
            }
            moodExpectation.fulfill()
        }
        
        wait(for: [moodExpectation], timeout: 2.0)
    }
    
    func testPerformance() {
        measure {
            // Test color transition performance
            for mood in Asset.MoodColor.allCases {
                colorTransitionManager.transition(to: mood)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func reportMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
    
    private func loadAudioBuffer(from url: URL) async throws -> [Float] {
        // Implementation would load actual audio data
        // This is a placeholder that returns random samples
        return (0..<2048).map { _ in Float.random(in: -1...1) }
    }
}

// MARK: - Mock Data

private enum MockData {
    static func createListeningHistory() -> [String: Any] {
        [
            "genres": ["rock": 0.4, "jazz": 0.3, "classical": 0.3],
            "timeOfDay": ["morning": 0.2, "afternoon": 0.5, "evening": 0.3],
            "tempo": ["slow": 0.3, "medium": 0.4, "fast": 0.3],
            "totalListeningTime": 3600
        ]
    }
}

// MARK: - Performance Benchmarks

extension AITests {
    func testAudioProcessingBenchmark() {
        let sampleCounts = [1024, 2048, 4096, 8192]
        
        for count in sampleCounts {
            measure(metrics: [
                XCTCPUMetric(),
                XCTMemoryMetric(),
                XCTStorageMetric(),
                XCTClockMetric()
            ]) {
                let samples = (0..<count).map { _ in Float.random(in: -1...1) }
                let features = fftProcessor.extractFeatures(from: samples)
                XCTAssertNotNil(features)
            }
        }
    }
    
    func testMoodDetectionBenchmark() async {
        measure(metrics: [
            XCTCPUMetric(),
            XCTMemoryMetric(),
            XCTClockMetric()
        ]) {
            let expectation = expectation(description: "Mood detection")
            
            Task {
                let audioURL = Bundle.main.url(forResource: "happy_song", withExtension: "mp3")!
                _ = try? await moodEngine.detectMood(from: audioURL)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testPersonalityPredictionBenchmark() {
        measure(metrics: [
            XCTCPUMetric(),
            XCTMemoryMetric(),
            XCTClockMetric()
        ]) {
            for _ in 0..<10 {
                let history = MockData.createListeningHistory()
                let prediction = personalityEngine.predictPersonality(from: history)
                XCTAssertNotNil(prediction)
            }
        }
    }
    
    func testColorTransitionBenchmark() {
        measure(metrics: [
            XCTCPUMetric(),
            XCTMemoryMetric(),
            XCTClockMetric()
        ]) {
            let expectation = expectation(description: "Color transitions")
            var transitionCount = 0
            
            for mood in Asset.MoodColor.allCases {
                colorTransitionManager.transition(to: mood) {
                    transitionCount += 1
                    if transitionCount == Asset.MoodColor.allCases.count {
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testRecommendationEngineBenchmark() async {
        measure(metrics: [
            XCTCPUMetric(),
            XCTMemoryMetric(),
            XCTClockMetric()
        ]) {
            let recommendationEngine = RecommendationEngine(
                moodEngine: moodEngine,
                personalityEngine: personalityEngine
            )
            
            let expectation = expectation(description: "Recommendations")
            
            Task {
                let startMemory = reportMemoryUsage()
                let recommendations = try? await recommendationEngine.getRecommendations(limit: 20)
                let endMemory = reportMemoryUsage()
                
                XCTAssertNotNil(recommendations)
                XCTAssertLessThanOrEqual(endMemory - startMemory, 200 * 1024 * 1024) // 200MB limit
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Performance Validation Tests
    
    func testMoodDetectionPerformance() {
        measure(metrics: [
            XCTCPUMetric(),
            XCTMemoryMetric(),
            XCTClockMetric()
        ]) {
            let expectation = expectation(description: "Mood detection performance test")
            let testFeatures = AudioFeatures(
                energy: 0.8,
                tempo: 120,
                valence: 0.7,
                spectralCentroid: 2000,
                spectralRolloff: 4000,
                zeroCrossingRate: 0.3
            )
            
            for _ in 0..<100 {
                let start = CACurrentMediaTime()
                let prediction = moodEngine.predictMood(from: testFeatures)
                let duration = CACurrentMediaTime() - start
                
                // Verify latency requirement (<40ms)
                XCTAssertLessThanOrEqual(duration, 0.04, "Inference latency exceeds 40ms requirement")
                
                // Verify prediction confidence
                XCTAssertGreaterThanOrEqual(prediction.confidence, MLConfig.Analysis.confidenceThreshold)
            }
            
            expectation.fulfill()
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testModelSize() {
        guard let modelUrl = MLConfig.ModelAsset.emotionClassifierOptimized.url else {
            XCTFail("Optimized model not found")
            return
        }
        
        do {
            let fileSize = try FileManager.default.attributesOfItem(atPath: modelUrl.path)[.size] as? Int64 ?? 0
            let sizeInMB = Double(fileSize) / (1024 * 1024)
            
            // Verify size requirement (<5MB)
            XCTAssertLessThanOrEqual(sizeInMB, 5.0, "Model size exceeds 5MB requirement")
        } catch {
            XCTFail("Failed to get model file size: \(error)")
        }
    }
    
    func testAccuracyComparison() async {
        let testCases = [
            ("happy_song.mp3", .happy),
            ("sad_song.mp3", .melancholic),
            ("energetic_song.mp3", .energetic)
        ]
        
        var originalCorrect = 0
        var optimizedCorrect = 0
        let totalCases = testCases.count
        
        for (song, expectedMood) in testCases {
            guard let audioURL = Bundle.main.url(forResource: song, withExtension: nil) else { continue }
            
            // Test original model
            if let prediction = try? await moodEngine.detectMood(from: audioURL, useOptimized: false),
               prediction.mood == expectedMood {
                originalCorrect += 1
            }
            
            // Test optimized model
            if let prediction = try? await moodEngine.detectMood(from: audioURL, useOptimized: true),
               prediction.mood == expectedMood {
                optimizedCorrect += 1
            }
        }
        
        let originalAccuracy = Double(originalCorrect) / Double(totalCases)
        let optimizedAccuracy = Double(optimizedCorrect) / Double(totalCases)
        
        // Verify accuracy loss requirement (<2%)
        XCTAssertLessThanOrEqual(originalAccuracy - optimizedAccuracy, 0.02, 
                                "Accuracy drop exceeds 2% requirement")
    }
}