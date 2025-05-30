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
