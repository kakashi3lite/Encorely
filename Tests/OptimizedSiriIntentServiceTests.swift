//
//  OptimizedSiriIntentServiceTests.swift
//  MixtapesTests
//
//  Unit tests for SiriKit intent optimization and performance
//  Tests for ISSUE-010: SiriKit Intent Extension Optimization
//

import Combine
import CoreData
import Intents
import XCTest
@testable import Mixtapes

class OptimizedSiriIntentServiceTests: XCTestCase {
    var siriService: OptimizedSiriIntentService!
    var mockContext: NSManagedObjectContext!
    var mockMoodEngine: MockMoodEngine!
    var mockPersonalityEngine: MockPersonalityEngine!

    override func setUp() {
        super.setUp()

        // Set up Core Data stack for testing
        mockContext = setUpInMemoryContext()

        // Set up mock engines
        mockMoodEngine = MockMoodEngine()
        mockPersonalityEngine = MockPersonalityEngine()

        // Initialize service
        siriService = OptimizedSiriIntentService(
            moodEngine: mockMoodEngine,
            personalityEngine: mockPersonalityEngine,
            context: mockContext)

        // Create test data
        createTestMixtapes()
    }

    override func tearDown() {
        siriService = nil
        mockContext = nil
        mockMoodEngine = nil
        mockPersonalityEngine = nil
        super.tearDown()
    }

    // MARK: - Performance Tests

    func testPlayIntentPerformance() {
        let intent = createMockPlayIntent(phrase: "play energetic music")

        let expectation = XCTestExpectation(description: "Play intent performance")
        let startTime = CFAbsoluteTimeGetCurrent()

        siriService.handlePlayMediaIntent(intent) { response in
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

            // Response should be received within 500ms for optimal user experience
            XCTAssertLessThan(elapsedTime, 0.5, "Play intent should respond within 500ms")
            XCTAssertEqual(response.code, .success, "Play intent should succeed")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSearchIntentPerformance() {
        let intent = createMockSearchIntent(phrase: "find relaxing music")

        let expectation = XCTestExpectation(description: "Search intent performance")
        let startTime = CFAbsoluteTimeGetCurrent()

        siriService.handleSearchMediaIntent(intent) { response in
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

            // Search should be even faster due to caching
            XCTAssertLessThan(elapsedTime, 0.3, "Search intent should respond within 300ms")
            XCTAssertEqual(response.code, .success, "Search intent should succeed")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testAddIntentPerformance() {
        let intent = createMockAddIntent(playlistName: "New Test Playlist")

        let expectation = XCTestExpectation(description: "Add intent performance")
        let startTime = CFAbsoluteTimeGetCurrent()

        siriService.handleAddMediaIntent(intent) { response in
            let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

            // Add intent can be slower but should still be under 1 second
            XCTAssertLessThan(elapsedTime, 1.0, "Add intent should respond within 1 second")
            XCTAssertEqual(response.code, .success, "Add intent should succeed")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Caching Tests

    func testMoodCaching() {
        let phrase1 = "play energetic music"
        let phrase2 = "play energetic music" // Same phrase

        // First call should cache the result
        let mood1 = siriService.extractMoodFromIntent(createMockPlayIntent(phrase: phrase1))
        let mood2 = siriService.extractMoodFromIntent(createMockPlayIntent(phrase: phrase2))

        XCTAssertEqual(mood1, mood2, "Same phrase should return cached mood")
        XCTAssertEqual(mood1, .energetic, "Should correctly detect energetic mood")
    }

    func testMixtapeCaching() {
        let expectation1 = XCTestExpectation(description: "First mixtape request")
        let expectation2 = XCTestExpectation(description: "Second mixtape request")

        var firstResponseTime: CFAbsoluteTime = 0
        var secondResponseTime: CFAbsoluteTime = 0

        // First request
        let startTime1 = CFAbsoluteTimeGetCurrent()
        siriService.findOptimalMixtape(for: .energetic) { mixtape in
            firstResponseTime = CFAbsoluteTimeGetCurrent() - startTime1
            XCTAssertNotNil(mixtape, "Should find energetic mixtape")
            expectation1.fulfill()
        }

        wait(for: [expectation1], timeout: 2.0)

        // Second request (should be cached)
        let startTime2 = CFAbsoluteTimeGetCurrent()
        siriService.findOptimalMixtape(for: .energetic) { mixtape in
            secondResponseTime = CFAbsoluteTimeGetCurrent() - startTime2
            XCTAssertNotNil(mixtape, "Should find cached energetic mixtape")
            expectation2.fulfill()
        }

        wait(for: [expectation2], timeout: 2.0)

        // Second request should be significantly faster
        XCTAssertLessThan(secondResponseTime, firstResponseTime * 0.5, "Cached request should be at least 50% faster")
    }

    func testResponseCaching() {
        let intent = createMockPlayIntent(phrase: "play happy music")

        let expectation1 = XCTestExpectation(description: "First response")
        let expectation2 = XCTestExpectation(description: "Cached response")

        var firstResponseTime: CFAbsoluteTime = 0
        var secondResponseTime: CFAbsoluteTime = 0

        // First request
        let startTime1 = CFAbsoluteTimeGetCurrent()
        siriService.handlePlayMediaIntent(intent) { response in
            firstResponseTime = CFAbsoluteTimeGetCurrent() - startTime1
            XCTAssertEqual(response.code, .success, "First request should succeed")
            expectation1.fulfill()
        }

        wait(for: [expectation1], timeout: 2.0)

        // Second identical request (should be cached)
        let startTime2 = CFAbsoluteTimeGetCurrent()
        siriService.handlePlayMediaIntent(intent) { response in
            secondResponseTime = CFAbsoluteTimeGetCurrent() - startTime2
            XCTAssertEqual(response.code, .success, "Cached request should succeed")
            expectation2.fulfill()
        }

        wait(for: [expectation2], timeout: 2.0)

        // Cached response should be much faster
        XCTAssertLessThan(secondResponseTime, 0.1, "Cached response should be under 100ms")
    }

    // MARK: - Mood Detection Tests

    func testMoodDetectionFromPhrases() {
        let testCases: [(phrase: String, expectedMood: Mood)] = [
            ("play energetic music", .energetic),
            ("play something to pump me up", .energetic),
            ("play relaxing music", .relaxed),
            ("play something calm", .relaxed),
            ("play happy songs", .happy),
            ("play upbeat music", .happy),
            ("play focus music", .focused),
            ("play study music", .focused),
            ("play romantic songs", .romantic),
            ("play love songs", .romantic),
            ("play angry music", .angry),
            ("play intense music", .angry),
            ("play sad music", .melancholic),
            ("play emotional music", .melancholic),
        ]

        for testCase in testCases {
            let intent = createMockPlayIntent(phrase: testCase.phrase)
            let detectedMood = siriService.extractMoodFromIntent(intent)

            XCTAssertEqual(detectedMood, testCase.expectedMood,
                           "Phrase '\(testCase.phrase)' should detect mood '\(testCase.expectedMood.rawValue)'")
        }
    }

    func testFallbackToCurrentMood() {
        // Set current mood
        mockMoodEngine.currentMood = .romantic

        // Use phrase without mood keywords
        let intent = createMockPlayIntent(phrase: "play some music")
        let detectedMood = siriService.extractMoodFromIntent(intent)

        XCTAssertEqual(detectedMood, .romantic, "Should fall back to current mood when no keywords found")
    }

    // MARK: - Search Functionality Tests

    func testSearchByMoodAndTitle() {
        let expectation = XCTestExpectation(description: "Search by mood and title")

        siriService.searchCachedMixtapes(term: "Test", mood: .energetic) { results in
            XCTAssertGreaterThan(results.count, 0, "Should find mixtapes matching criteria")

            // Verify all results contain the search term or mood
            for result in results {
                let titleMatches = result.wrappedTitle.localizedCaseInsensitiveContains("Test")
                let moodMatches = result.moodTagsArray.contains(Mood.energetic.rawValue)

                XCTAssertTrue(titleMatches || moodMatches, "Result should match search criteria")
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSearchLimitResults() {
        let expectation = XCTestExpectation(description: "Search result limit")

        siriService.searchCachedMixtapes(term: "", mood: nil) { results in
            // Should limit results to 5 for performance
            XCTAssertLessThanOrEqual(results.count, 5, "Search should limit results to 5")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Concurrent Request Tests

    func testConcurrentRequestHandling() {
        let expectation = XCTestExpectation(description: "Concurrent requests")
        expectation.expectedFulfillmentCount = 5

        let queue = DispatchQueue.global(qos: .userInteractive)

        // Send 5 concurrent requests
        for i in 0 ..< 5 {
            queue.async {
                let intent = self.createMockPlayIntent(phrase: "play music \(i)")

                self.siriService.handlePlayMediaIntent(intent) { response in
                    XCTAssertEqual(response.code, .success, "Concurrent request \(i) should succeed")
                    expectation.fulfill()
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Memory Usage Tests

    func testMemoryUsageUnderLoad() {
        let startMemory = getCurrentMemoryUsage()

        // Generate many requests to test memory usage
        let expectation = XCTestExpectation(description: "Memory usage test")
        expectation.expectedFulfillmentCount = 50

        for i in 0 ..< 50 {
            let intent = createMockPlayIntent(phrase: "play music \(i)")

            siriService.handlePlayMediaIntent(intent) { _ in
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 10.0)

        let endMemory = getCurrentMemoryUsage()
        let memoryIncrease = endMemory - startMemory

        // Memory increase should be reasonable (less than 20MB)
        XCTAssertLessThan(memoryIncrease, 20 * 1024 * 1024, "Memory usage should not increase significantly under load")
    }

    // MARK: - Error Handling Tests

    func testInvalidIntentHandling() {
        let expectation = XCTestExpectation(description: "Invalid intent handling")

        // Create intent with invalid/empty data
        let intent = INPlayMediaIntent()
        // Don't set any properties - should be handled gracefully

        siriService.handlePlayMediaIntent(intent) { response in
            // Should not crash and should provide a reasonable response
            XCTAssertNotEqual(response.code, .failure, "Should handle invalid intent gracefully")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testCoreDataErrorHandling() {
        // Test with invalid context
        let invalidService = OptimizedSiriIntentService(
            moodEngine: mockMoodEngine,
            personalityEngine: mockPersonalityEngine,
            context: NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType) // No persistent store
        )

        let expectation = XCTestExpectation(description: "Core Data error handling")

        let intent = createMockAddIntent(playlistName: "Test Playlist")

        invalidService.handleAddMediaIntent(intent) { response in
            // Should handle Core Data errors gracefully
            XCTAssertEqual(response.code, .failure, "Should fail gracefully with invalid context")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - Helper Methods

    private func setUpInMemoryContext() -> NSManagedObjectContext {
        let persistentContainer = NSPersistentContainer(name: "Mixtapes") // Use actual model name

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

    private func createTestMixtapes() {
        let moods: [Mood] = [.energetic, .relaxed, .happy, .focused, .romantic]

        for (index, mood) in moods.enumerated() {
            let mixtape = MixTape(context: mockContext)
            mixtape.title = "Test Mixtape \(index + 1)"
            mixtape.moodTags = mood.rawValue
            mixtape.playCount = Int32(10 - index) // Higher play count for earlier items
            mixtape.numberOfSongs = Int16.random(in: 5 ... 20)
            mixtape.aiGenerated = Bool.random()
        }

        try! mockContext.save()
    }

    private func createMockPlayIntent(phrase: String) -> INPlayMediaIntent {
        let intent = INPlayMediaIntent()
        let mediaSearch = INMediaSearch()
        mediaSearch.mediaName = INSpeakableString(spokenPhrase: phrase)
        intent.mediaSearch = mediaSearch
        return intent
    }

    private func createMockSearchIntent(phrase: String) -> INSearchForMediaIntent {
        let intent = INSearchForMediaIntent()
        intent.mediaName = INSpeakableString(spokenPhrase: phrase)
        return intent
    }

    private func createMockAddIntent(playlistName: String) -> INAddMediaIntent {
        let intent = INAddMediaIntent()
        let destination = INMediaDestination()
        destination.mediaName = INSpeakableString(spokenPhrase: playlistName)
        intent.mediaDestination = destination
        return intent
    }

    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }

    // MARK: - Comprehensive Performance Benchmarks

    func testSiriKitPerformanceUnderLoad() {
        measure {
            let group = DispatchGroup()
            var responseTimesMs: [Double] = []
            let lock = NSLock()

            // Simulate 10 concurrent requests
            for i in 0 ..< 10 {
                group.enter()
                let intent = createMockPlayIntent(phrase: "play music \(i)")
                let startTime = CFAbsoluteTimeGetCurrent()

                siriService.handlePlayMediaIntent(intent) { _ in
                    let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                    lock.lock()
                    responseTimesMs.append(elapsedMs)
                    lock.unlock()
                    group.leave()
                }
            }

            group.wait()

            // Verify performance targets
            let avgResponseTime = responseTimesMs.reduce(0, +) / Double(responseTimesMs.count)
            XCTAssertLessThan(avgResponseTime, 500, "Average response time should be under 500ms")

            let maxResponseTime = responseTimesMs.max() ?? 0
            XCTAssertLessThan(maxResponseTime, 1000, "Maximum response time should be under 1000ms")

            let p95ResponseTime = responseTimesMs.sorted()[Int(Double(responseTimesMs.count) * 0.95)]
            XCTAssertLessThan(p95ResponseTime, 800, "95th percentile response time should be under 800ms")
        }
    }

    func testCachePerformance() {
        let intent = createMockPlayIntent(phrase: "play happy music")

        // Prime the cache
        let primeExpectation = XCTestExpectation(description: "Cache priming")
        siriService.handlePlayMediaIntent(intent) { _ in
            primeExpectation.fulfill()
        }
        wait(for: [primeExpectation], timeout: 2.0)

        // Test cached performance
        measure {
            let expectation = XCTestExpectation(description: "Cached response")
            let startTime = CFAbsoluteTimeGetCurrent()

            siriService.handlePlayMediaIntent(intent) { _ in
                let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                XCTAssertLessThan(elapsedMs, 100, "Cached responses should be under 100ms")
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }
    }

    func testMemoryConstraints() {
        let initialMemory = getCurrentMemoryUsage()
        var memoryReadings: [Int] = []

        measure {
            // Generate high load
            let expectation = XCTestExpectation(description: "Memory test")
            expectation.expectedFulfillmentCount = 20

            for i in 0 ..< 20 {
                let intent =
                    createMockPlayIntent(phrase: "play \(Mood.allCases[i % Mood.allCases.count].rawValue) music")
                siriService.handlePlayMediaIntent(intent) { _ in
                    expectation.fulfill()
                }
            }

            wait(for: [expectation], timeout: 5.0)

            // Record memory usage
            let currentMemory = getCurrentMemoryUsage()
            memoryReadings.append(currentMemory - initialMemory)
        }

        // Verify memory constraints
        let avgMemoryIncrease = memoryReadings.reduce(0, +) / memoryReadings.count
        XCTAssertLessThan(Double(avgMemoryIncrease) / 1024 / 1024, 20.0, "Average memory increase should be under 20MB")

        let peakMemoryIncrease = memoryReadings.max() ?? 0
        XCTAssertLessThan(Double(peakMemoryIncrease) / 1024 / 1024, 50.0, "Peak memory increase should be under 50MB")
    }

    func testConcurrentPerformance() {
        let concurrentUsers = 5
        let requestsPerUser = 10
        let totalRequests = concurrentUsers * requestsPerUser

        measure {
            let expectation = XCTestExpectation(description: "Concurrent performance")
            expectation.expectedFulfillmentCount = totalRequests

            var responseTimes: [(index: Int, time: Double)] = []
            let lock = NSLock()

            // Simulate multiple users making requests
            for userIndex in 0 ..< concurrentUsers {
                DispatchQueue.global(qos: .userInitiated).async {
                    for requestIndex in 0 ..< requestsPerUser {
                        let globalIndex = userIndex * requestsPerUser + requestIndex
                        let intent = self.createMockPlayIntent(phrase: "play music \(globalIndex)")
                        let startTime = CFAbsoluteTimeGetCurrent()

                        self.siriService.handlePlayMediaIntent(intent) { _ in
                            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                            lock.lock()
                            responseTimes.append((globalIndex, elapsed))
                            lock.unlock()
                            expectation.fulfill()
                        }

                        // Add small delay between requests from same user
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                }
            }

            wait(for: [expectation], timeout: 15.0)

            // Sort by request index to analyze performance degradation
            responseTimes.sort { $0.index < $1.index }

            // Verify performance remains consistent
            let firstHalfAvg = responseTimes[0 ..< totalRequests / 2].map(\.time)
                .reduce(0, +) / Double(totalRequests / 2)
            let secondHalfAvg = responseTimes[totalRequests / 2 ..< totalRequests].map(\.time)
                .reduce(0, +) / Double(totalRequests / 2)

            XCTAssertLessThan(
                secondHalfAvg / firstHalfAvg,
                1.5,
                "Performance should not degrade more than 50% under sustained load")
        }
    }

    // MARK: - Cache Validation Tests

    func testCacheInvalidation() {
        // Test cache expiration
        let testPhrase = "play test music"
        let intent = createMockPlayIntent(phrase: testPhrase)

        // Prime cache
        let primeExpectation = XCTestExpectation(description: "Cache priming")
        siriService.handlePlayMediaIntent(intent) { _ in
            primeExpectation.fulfill()
        }
        wait(for: [primeExpectation], timeout: 2.0)

        // Wait for cache to expire (cache expires after 5 minutes)
        // Simulate by triggering manual cache cleanup
        siriService.performCacheCleanup()

        // Verify cache was invalidated
        let expectation = XCTestExpectation(description: "Cache invalidation")
        let startTime = CFAbsoluteTimeGetCurrent()

        siriService.handlePlayMediaIntent(intent) { _ in
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            XCTAssertGreaterThan(elapsed, 0.1, "Response after cache invalidation should not be cached")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }
}

// MARK: - Mock Classes

class MockMoodEngine: MoodEngine {
    override var currentMood: Mood {
        get { .neutral }
        set { /* Mock implementation */ }
    }

    override var moodConfidence: Float {
        0.8
    }
}

class MockPersonalityEngine: PersonalityEngine {
    override var currentPersonality: PersonalityType {
        .explorer
    }

    override func getPersonalityTraits() -> [PersonalityTrait] {
        [
            PersonalityTrait(type: .explorer, value: 0.8),
            PersonalityTrait(type: .curator, value: 0.6),
            PersonalityTrait(type: .enthusiast, value: 0.7),
        ]
    }
}
