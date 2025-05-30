import XCTest
import AVFoundation
import Combine
@testable import AIMixtapes

/// Tests for the enhanced AudioAnalysisService with focus on memory management and buffer handling
class AudioAnalysisServiceTests: XCTestCase {
    // Audio analysis service instance
    var audioAnalysisService: AudioAnalysisService!
    var cancellables = Set<AnyCancellable>()
    
    // Test configuration
    private let testSampleRate: Double = 44100.0
    private let testBufferSize: UInt32 = 4096
    private let maxMemoryLimit = 50 * 1024 * 1024 // 50MB limit
    
    override func setUp() {
        super.setUp()
        audioAnalysisService = AudioAnalysisService()
    }
    
    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables = []
        audioAnalysisService = nil
        super.tearDown()
    }
    
    /// Tests the creation of spectral features
    func testSpectralFeatureCreation() {
        // Create a mock spectral features set
        var spectralFeatures = SpectralFeatures()
        spectralFeatures.centroid = 2000.0
        spectralFeatures.spread = 1500.0
        spectralFeatures.rolloff = 4000.0
        spectralFeatures.flux = 0.6
        spectralFeatures.bassEnergy = 0.8
        spectralFeatures.midEnergy = 0.5
        spectralFeatures.trebleEnergy = 0.3
        spectralFeatures.brightness = 0.7
        
        // Convert to audio features
        let audioFeatures = AudioFeatures.from(spectralFeatures: spectralFeatures)
        
        // Verify the conversion worked correctly
        XCTAssertEqual(audioFeatures.spectralFeatures?.centroid, 2000.0)
        XCTAssertEqual(audioFeatures.spectralFeatures?.spread, 1500.0)
        XCTAssertEqual(audioFeatures.spectralFeatures?.bassEnergy, 0.8)
        XCTAssertEqual(audioFeatures.energy, (0.8 + 0.5 + 0.3) / 3.0)
        XCTAssertGreaterThan(audioFeatures.valence ?? 0, 0.0)
        XCTAssertLessThan(audioFeatures.valence ?? 1.1, 1.0)
    }
    
    /// Tests the mood factory methods
    func testMoodFactoryMethods() {
        // Test different moods
        let energeticFeatures = AudioFeatures.forMood(.energetic)
        let relaxedFeatures = AudioFeatures.forMood(.relaxed)
        let happyFeatures = AudioFeatures.forMood(.happy)
        
        // Verify the features match the expected mood characteristics
        XCTAssertGreaterThan(energeticFeatures.energy ?? 0, 0.7)
        XCTAssertLessThan(relaxedFeatures.energy ?? 1.0, 0.5)
        XCTAssertGreaterThan(happyFeatures.valence ?? 0, 0.7)
    }
    
    /// Tests the performance metrics
    func testPerformanceMetrics() {
        var metrics = PerformanceMetrics()
        
        // Record some sample analysis data
        metrics.recordAnalysis(duration: 180.0, format: "44.1kHz, 2 channels", processingTime: 2.5, memoryUsed: 1024 * 1024)
        metrics.recordAnalysis(duration: 240.0, format: "44.1kHz, 2 channels", processingTime: 3.0, memoryUsed: 2 * 1024 * 1024)
        
        // Get the report and verify it contains expected information
        let report = metrics.generateReport()
        XCTAssertTrue(report.contains("Total files processed: 2"))
        XCTAssertTrue(report.contains("Total audio duration: 420"))
    }
    
    /// Tests distance and similarity calculations
    func testDistanceCalculation() {
        let featureSet1 = AudioFeatures(
            tempo: 120.0,
            energy: 0.8,
            valence: 0.7
        )
        
        let featureSet2 = AudioFeatures(
            tempo: 124.0,
            energy: 0.75,
            valence: 0.65
        )
        
        let featureSet3 = AudioFeatures(
            tempo: 80.0,
            energy: 0.3,
            valence: 0.2
        )
        
        // Similar features should have low distance
        let distance1to2 = featureSet1.distance(to: featureSet2)
        XCTAssertLessThan(distance1to2, 0.3)
        
        // Different features should have high distance
        let distance1to3 = featureSet1.distance(to: featureSet3)
        XCTAssertGreaterThan(distance1to3, 0.5)
        
        // Similarity is the inverse of distance
        let similarity1to2 = featureSet1.similarity(to: featureSet2)
        XCTAssertGreaterThan(similarity1to2, 0.7)
    }
    
    /// Tests memory usage stability during analysis
    func testMemoryUsageDuringAnalysis() {
        let buffer = createTestBuffer(duration: 5.0) // 5 seconds of audio
        let initialMemory = getMemoryUsage()
        
        // Perform multiple analyses to stress test memory management
        for _ in 0..<10 {
            autoreleasepool {
                _ = audioAnalysisService.analyzeAudioBuffer(buffer)
            }
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        XCTAssertLessThan(memoryIncrease, maxMemoryLimit / 2, "Memory usage increased beyond acceptable limits")
    }
    
    /// Tests buffer pool management and reuse
    func testBufferPoolManagement() {
        let expectation = XCTestExpectation(description: "Buffer pool management")
        let analysisCount = 5
        var completedAnalyses = 0
        
        // Perform concurrent analyses to stress test buffer pool
        for _ in 0..<analysisCount {
            DispatchQueue.global().async {
                autoreleasepool {
                    let buffer = self.createTestBuffer(duration: 1.0)
                    let features = self.audioAnalysisService.analyzeAudioBuffer(buffer)
                    XCTAssertNotNil(features, "Analysis should complete successfully")
                    
                    DispatchQueue.main.async {
                        completedAnalyses += 1
                        if completedAnalyses == analysisCount {
                            expectation.fulfill()
                        }
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Tests memory cleanup after large analysis
    func testMemoryCleanupAfterLargeAnalysis() {
        let initialMemory = getMemoryUsage()
        
        autoreleasepool {
            // Create and analyze a large buffer
            let largeBuffer = createTestBuffer(duration: 10.0)
            _ = audioAnalysisService.analyzeAudioBuffer(largeBuffer)
        }
        
        // Force cleanup
        audioAnalysisService.cancelCurrentAnalysis()
        
        // Memory should return close to initial state
        let finalMemory = getMemoryUsage()
        let memoryDifference = abs(finalMemory - initialMemory)
        
        XCTAssertLessThan(memoryDifference, 1024 * 1024, "Memory not properly cleaned up after analysis")
    }
    
    /// Tests concurrent buffer management
    func testConcurrentBufferManagement() {
        let expectation = XCTestExpectation(description: "Concurrent buffer management")
        let operationCount = 10
        let group = DispatchGroup()
        
        // Perform multiple concurrent operations
        for i in 0..<operationCount {
            group.enter()
            DispatchQueue.global().async {
                autoreleasepool {
                    let buffer = self.createTestBuffer(duration: Double(i) / 10.0 + 0.5)
                    let features = self.audioAnalysisService.analyzeAudioBuffer(buffer)
                    XCTAssertNotNil(features, "Analysis \(i) should complete successfully")
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    /// Tests high memory pressure handling
    func testHighMemoryPressureHandling() {
        // Create multiple large buffers to trigger memory pressure
        var buffers: [AVAudioPCMBuffer] = []
        let initialMemory = getMemoryUsage()
        
        // Add buffers until we hit memory pressure
        for i in 0..<10 {
            autoreleasepool {
                let buffer = createTestBuffer(duration: 2.0)
                buffers.append(buffer)
                _ = audioAnalysisService.analyzeAudioBuffer(buffer)
                
                let currentMemory = getMemoryUsage()
                print("Memory after buffer \(i): \(currentMemory / 1024 / 1024) MB")
            }
        }
        
        // Clear buffers
        buffers.removeAll()
        
        // Memory should be managed properly
        let finalMemory = getMemoryUsage()
        XCTAssertLessThan(finalMemory - initialMemory, maxMemoryLimit, "Memory pressure not handled properly")
    }
    
    /// Tests edge cases in buffer allocation and deallocation
    func testBufferAllocationEdgeCases() {
        // Test 1: Rapid allocation and deallocation
        let expectation1 = XCTestExpectation(description: "Rapid buffer operations")
        let operationCount = 100
        var peakMemory = 0
        
        DispatchQueue.concurrentPerform(iterations: operationCount) { _ in
            autoreleasepool {
                let buffer = createTestBuffer(duration: 0.1) // Small duration
                _ = audioAnalysisService.analyzeAudioBuffer(buffer)
                let currentMemory = getMemoryUsage()
                peakMemory = max(peakMemory, currentMemory)
            }
        }
        
        // Test 2: Maximum buffer size
        let largeBuffer = createTestBuffer(duration: 30.0) // Very long duration
        let initialMemory = getMemoryUsage()
        _ = audioAnalysisService.analyzeAudioBuffer(largeBuffer)
        let maxMemory = getMemoryUsage()
        
        // Test 3: Zero-length buffer
        let emptyFormat = AVAudioFormat(standardFormatWithSampleRate: testSampleRate, channels: 1)!
        let emptyBuffer = AVAudioPCMBuffer(pcmFormat: emptyFormat, frameCapacity: 0)!
        let result = audioAnalysisService.analyzeAudioBuffer(emptyBuffer)
        
        // Cleanup and verify
        audioAnalysisService.cancelCurrentAnalysis()
        let finalMemory = getMemoryUsage()
        
        // Assertions
        XCTAssertLessThan(peakMemory, maxMemoryLimit, "Peak memory during rapid operations exceeded limit")
        XCTAssertLessThan(maxMemory - initialMemory, maxMemoryLimit, "Memory usage for large buffer exceeded limit")
        XCTAssertNil(result, "Zero-length buffer should return nil result")
        XCTAssertLessThan(finalMemory - initialMemory, 1024 * 1024, "Memory not properly cleaned up")
        
        expectation1.fulfill()
        wait(for: [expectation1], timeout: 10.0)
    }

    /// Tests buffer pool exhaustion scenarios
    func testBufferPoolExhaustion() {
        // Create concurrent requests exceeding pool size
        let expectation = XCTestExpectation(description: "Pool exhaustion test")
        let poolSize = 10 // Known pool size
        let requestCount = poolSize * 2
        var successfulAnalyses = 0
        var failedAnalyses = 0
        
        let group = DispatchGroup()
        
        for _ in 0..<requestCount {
            group.enter()
            DispatchQueue.global().async {
                autoreleasepool {
                    let buffer = self.createTestBuffer(duration: 1.0)
                    if self.audioAnalysisService.analyzeAudioBuffer(buffer) != nil {
                        successfulAnalyses += 1
                    } else {
                        failedAnalyses += 1
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            // Verify pool behavior
            XCTAssertGreaterThan(successfulAnalyses, 0, "Some analyses should succeed")
            XCTAssertGreaterThan(failedAnalyses, 0, "Some analyses should fail due to pool exhaustion")
            XCTAssertEqual(successfulAnalyses + failedAnalyses, requestCount, "All requests should be accounted for")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    /// Tests recovery from memory pressure conditions
    func testMemoryPressureRecovery() {
        let initialMemory = getMemoryUsage()
        var memoryReadings: [Int] = []
        
        // Phase 1: Create memory pressure
        for _ in 0..<5 {
            autoreleasepool {
                let largeBuffer = createTestBuffer(duration: 5.0)
                _ = audioAnalysisService.analyzeAudioBuffer(largeBuffer)
                memoryReadings.append(getMemoryUsage())
            }
        }
        
        // Phase 2: Force cleanup
        audioAnalysisService.cancelCurrentAnalysis()
        
        // Phase 3: Verify recovery
        let postCleanupMemory = getMemoryUsage()
        
        // Phase 4: Test normal operation after recovery
        let testBuffer = createTestBuffer(duration: 1.0)
        let features = audioAnalysisService.analyzeAudioBuffer(testBuffer)
        
        // Phase 5: Final memory check
        let finalMemory = getMemoryUsage()
        
        // Assertions
        XCTAssertNotNil(features, "Analysis should work after recovery")
        XCTAssertGreaterThan(memoryReadings.max() ?? 0, initialMemory, "Memory pressure should have occurred")
        XCTAssertLessThan(postCleanupMemory - initialMemory, 5 * 1024 * 1024, "Cleanup should release most memory")
        XCTAssertLessThan(finalMemory - initialMemory, 10 * 1024 * 1024, "Memory usage should remain stable after recovery")
    }

    /// Tests automatic memory pressure detection and handling
    func testAutomaticMemoryPressureHandling() {
        let expectation = XCTestExpectation(description: "Memory pressure handling")
        let initialMemory = getMemoryUsage()
        var peakMemory = initialMemory
        var memoryReadings: [Int] = []
        
        // Create steady stream of analysis requests
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            autoreleasepool {
                let buffer = self.createTestBuffer(duration: 1.0)
                _ = self.audioAnalysisService.analyzeAudioBuffer(buffer)
                let currentMemory = self.getMemoryUsage()
                peakMemory = max(peakMemory, currentMemory)
                memoryReadings.append(currentMemory)
            }
        }
        
        // Let it run for a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            timer.invalidate()
            
            // Analyze memory pattern
            let memoryIncreases = zip(memoryReadings, memoryReadings.dropFirst())
                .map { $1 - $0 }
            let sustainedIncrease = memoryIncreases.filter { $0 > 0 }.count
            
            // Verify memory management
            XCTAssertLessThan(peakMemory - initialMemory, self.maxMemoryLimit, "Peak memory should stay under limit")
            XCTAssertLessThan(Double(sustainedIncrease) / Double(memoryReadings.count), 0.7,
                             "Memory should not continuously increase")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    /// Tests parallel audio processing with memory constraints
    func testParallelAudioProcessing() {
        let expectation = XCTestExpectation(description: "Parallel processing")
        let initialMemory = getMemoryUsage()
        let operationCount = 10
        var completedOperations = 0
        var peakMemory = initialMemory
        let semaphore = DispatchSemaphore(value: 3) // Limit concurrent operations
        
        // Run multiple analyses in parallel
        for i in 0..<operationCount {
            DispatchQueue.global().async {
                semaphore.wait()
                autoreleasepool {
                    // Create varying buffer sizes
                    let duration = Double(i % 3 + 1) // 1, 2, or 3 seconds
                    let buffer = self.createTestBuffer(duration: duration)
                    
                    // Analyze buffer
                    let features = self.audioAnalysisService.analyzeAudioBuffer(buffer)
                    XCTAssertNotNil(features, "Analysis \(i) failed")
                    
                    // Track memory
                    let currentMemory = self.getMemoryUsage()
                    peakMemory = max(peakMemory, currentMemory)
                    
                    // Complete operation
                    DispatchQueue.main.async {
                        completedOperations += 1
                        if completedOperations == operationCount {
                            // Verify results
                            let finalMemory = self.getMemoryUsage()
                            XCTAssertLessThan(peakMemory - initialMemory, self.maxMemoryLimit,
                                           "Peak memory exceeded limit during parallel processing")
                            XCTAssertLessThan(finalMemory - initialMemory, 5 * 1024 * 1024,
                                           "Memory not properly released after parallel processing")
                            expectation.fulfill()
                        }
                    }
                }
                semaphore.signal()
            }
        }
        
        wait(for: [expectation], timeout: 30.0)
    }

    /// Tests interleaved audio operations with varying priorities
    func testInterleavedOperations() {
        let expectation = XCTestExpectation(description: "Interleaved operations")
        var activeOperations = 0
        let maxConcurrent = 3
        
        // High priority operations (short buffers)
        let highPriorityQueue = DispatchQueue(label: "com.test.high", qos: .userInitiated, attributes: .concurrent)
        // Low priority operations (long buffers)
        let lowPriorityQueue = DispatchQueue(label: "com.test.low", qos: .utility, attributes: .concurrent)
        
        let operationGroup = DispatchGroup()
        
        // Start low priority operations
        for _ in 0..<5 {
            operationGroup.enter()
            lowPriorityQueue.async {
                autoreleasepool {
                    if activeOperations < maxConcurrent {
                        activeOperations += 1
                        let buffer = self.createTestBuffer(duration: 3.0)
                        _ = self.audioAnalysisService.analyzeAudioBuffer(buffer)
                        activeOperations -= 1
                    }
                    operationGroup.leave()
                }
            }
        }
        
        // Start high priority operations
        for _ in 0..<10 {
            operationGroup.enter()
            highPriorityQueue.async {
                autoreleasepool {
                    if activeOperations < maxConcurrent {
                        activeOperations += 1
                        let buffer = self.createTestBuffer(duration: 0.5)
                        _ = self.audioAnalysisService.analyzeAudioBuffer(buffer)
                        activeOperations -= 1
                    }
                    operationGroup.leave()
                }
            }
        }
        
        operationGroup.notify(queue: .main) {
            XCTAssertEqual(activeOperations, 0, "All operations should be completed")
            XCTAssertLessThan(self.getMemoryUsage(), self.maxMemoryLimit, "Memory limit not exceeded")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    /// Tests buffer pool under stress conditions
    func testBufferPoolStress() {
        let expectation = XCTestExpectation(description: "Buffer pool stress test")
        let initialMemory = getMemoryUsage()
        let iterations = 50
        var successfulOperations = 0
        var failedOperations = 0
        var peakMemory = initialMemory
        
        // Track processing time
        let startTime = CFAbsoluteTimeGetCurrent()
        let group = DispatchGroup()
        
        // Function to simulate varying workloads
        func processWithSize(_ size: Int) {
            group.enter()
            DispatchQueue.global().async {
                autoreleasepool {
                    let duration = Double(size) / 10.0 // 0.1s to 0.5s
                    let buffer = self.createTestBuffer(duration: duration)
                    
                    if self.audioAnalysisService.analyzeAudioBuffer(buffer) != nil {
                        successfulOperations += 1
                    } else {
                        failedOperations += 1
                    }
                    
                    let currentMemory = self.getMemoryUsage()
                    peakMemory = max(peakMemory, currentMemory)
                    
                    group.leave()
                }
            }
        }
        
        // Create mixed workload pattern
        for i in 0..<iterations {
            let size = (i % 5) + 1 // Vary buffer sizes
            processWithSize(size)
            
            // Occasionally request multiple buffers simultaneously
            if i % 10 == 0 {
                for _ in 0..<3 {
                    processWithSize(2)
                }
            }
        }
        
        group.notify(queue: .main) {
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            // Verify test results
            XCTAssertGreaterThan(successfulOperations, 0, "Some operations should succeed")
            XCTAssertLessThan(failedOperations, iterations / 2, "Failure rate should be reasonable")
            XCTAssertLessThan(peakMemory - initialMemory, self.maxMemoryLimit, "Memory usage should stay under limit")
            XCTAssertLessThan(duration, 30.0, "Processing should complete in reasonable time")
            
            // Verify pool recovery
            self.audioAnalysisService.cancelCurrentAnalysis()
            let finalMemory = self.getMemoryUsage()
            XCTAssertLessThan(finalMemory - initialMemory, 5 * 1024 * 1024, "Pool should release memory after stress")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 45.0)
    }

    /// Tests buffer pool recovery after sustained load
    func testBufferPoolRecovery() {
        let initialMemory = getMemoryUsage()
        var memoryProfile: [Int] = []
        
        // Phase 1: Create sustained load
        for _ in 0..<10 {
            autoreleasepool {
                let buffer = createTestBuffer(duration: 2.0)
                _ = audioAnalysisService.analyzeAudioBuffer(buffer)
                memoryProfile.append(getMemoryUsage())
                Thread.sleep(forTimeInterval: 0.1) // Simulate real-world timing
            }
        }
        
        // Phase 2: Allow pool to recover
        audioAnalysisService.cancelCurrentAnalysis()
        Thread.sleep(forTimeInterval: 1.0)
        
        // Phase 3: Verify recovery
        let postRecoveryMemory = getMemoryUsage()
        
        // Phase 4: Test pool functionality after recovery
        var postRecoverySuccess = 0
        for _ in 0..<5 {
            autoreleasepool {
                let buffer = createTestBuffer(duration: 1.0)
                if audioAnalysisService.analyzeAudioBuffer(buffer) != nil {
                    postRecoverySuccess += 1
                }
            }
        }
        
        // Verify results
        XCTAssertGreaterThan(memoryProfile.max() ?? 0, initialMemory, "Load should cause memory usage")
        XCTAssertLessThan(postRecoveryMemory - initialMemory, 5 * 1024 * 1024, "Recovery should release memory")
        XCTAssertEqual(postRecoverySuccess, 5, "Pool should be fully functional after recovery")
    }
    
    // MARK: - Helper Methods
    
    private func createTestBuffer(duration: TimeInterval) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * testSampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: testSampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        
        buffer.frameLength = frameCount
        if let channelData = buffer.floatChannelData?[0] {
            // Fill with white noise for testing
            for i in 0..<Int(frameCount) {
                channelData[i] = Float.random(in: -1...1)
            }
        }
        
        return buffer
    }
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}
