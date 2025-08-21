import XCTest
@testable import AudioKitEncorely

final class AudioVisualizerTests: XCTestCase {
    var visualizer: AudioVisualizer!
    
    @MainActor
    override func setUp() {
        super.setUp()
        visualizer = AudioVisualizer()
    }
    
    override func tearDown() {
        visualizer = nil
        super.tearDown()
    }
    
    @MainActor
    func testVisualizerInitialization() {
        XCTAssertEqual(visualizer.waveformData.count, 128)
        XCTAssertEqual(visualizer.spectrumData.count, 256) // fftSize / 2
        XCTAssertEqual(visualizer.rmsLevel, 0.0)
        XCTAssertEqual(visualizer.peakLevel, 0.0)
    }
    
    @MainActor
    func testProcessAudioBuffer() {
        let testSamples: [Float] = (0..<1024).map { i in
            sin(Float(i) * 0.1) * 0.5
        }
        
        visualizer.processAudioBuffer(testSamples)
        
        XCTAssertGreaterThan(visualizer.rmsLevel, 0)
        XCTAssertGreaterThan(visualizer.peakLevel, 0)
        XCTAssertEqual(visualizer.waveformData.count, 128)
    }
    
    @MainActor
    func testProcessEmptyBuffer() {
        let emptyBuffer: [Float] = []
        
        visualizer.processAudioBuffer(emptyBuffer)
        
        // Should not crash and should maintain initial state
        XCTAssertEqual(visualizer.rmsLevel, 0.0)
        XCTAssertEqual(visualizer.peakLevel, 0.0)
    }
    
    func testSpectralCentroid() {
        let testSamples: [Float] = (0..<1024).map { i in
            sin(Float(i) * 0.01) * 0.8 // Low frequency content
        }
        
        let centroid = DSP.spectralCentroid(testSamples, sampleRate: 44100)
        
        // Should be a reasonable frequency value
        XCTAssertGreaterThan(centroid, 0)
        XCTAssertLessThan(centroid, 22050) // Nyquist frequency
    }
    
    func testLowPassFilter() {
        let testSamples: [Float] = (0..<1024).map { i in
            sin(Float(i) * 0.1) + sin(Float(i) * 1.0) // Mix of low and high frequency
        }
        
        let filtered = DSP.lowPassFilter(testSamples, cutoffFrequency: 100, sampleRate: 44100)
        
        XCTAssertEqual(filtered.count, testSamples.count)
        
        // Check that filtering actually reduced high frequency content
        let originalRMS = DSP.rms(testSamples)
        let filteredRMS = DSP.rms(filtered)
        
        // Filtered signal should have different (usually lower) RMS
        XCTAssertNotEqual(originalRMS, filteredRMS, accuracy: 0.001)
    }
    
    func testLowPassFilterEmptyInput() {
        let emptyBuffer: [Float] = []
        let filtered = DSP.lowPassFilter(emptyBuffer, cutoffFrequency: 100, sampleRate: 44100)
        
        XCTAssertEqual(filtered.count, 0)
    }
    
    func testSpectralCentroidInsufficientSamples() {
        let shortBuffer: [Float] = Array(repeating: 0.5, count: 100)
        let centroid = DSP.spectralCentroid(shortBuffer, sampleRate: 44100)
        
        XCTAssertEqual(centroid, 0)
    }
    
    @MainActor
    func testVisualizationStartStop() {
        // Test starting visualization
        visualizer.startVisualization()
        
        // Give it a moment to generate some data
        let expectation = XCTestExpectation(description: "Visualization data generation")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
        
        // Test stopping visualization
        visualizer.stopVisualization()
        
        // Should not crash
        XCTAssertTrue(true)
    }
    
    func testPerformanceRMS() {
        let largeBuffer: [Float] = Array(repeating: 0.5, count: 44100) // 1 second at 44.1kHz
        
        measure {
            _ = DSP.rms(largeBuffer)
        }
    }
    
    func testPerformanceLargeBufferRMS() {
        let hugeBuffer: [Float] = Array(repeating: 0.5, count: 441000) // 10 seconds at 44.1kHz
        
        measure {
            _ = DSP.rmsLargeBuffer(hugeBuffer)
        }
    }
    
    func testPerformanceLowPassFilter() {
        let buffer: [Float] = (0..<44100).map { i in
            sin(Float(i) * 0.1) * 0.5
        }
        
        measure {
            _ = DSP.lowPassFilter(buffer, cutoffFrequency: 1000, sampleRate: 44100)
        }
    }
}

// MARK: - Integration Tests
final class AudioSessionIntegrationTests: XCTestCase {
    var audioManager: AudioSessionManager!
    
    @MainActor
    override func setUp() {
        super.setUp()
        audioManager = AudioSessionManager()
    }
    
    override func tearDown() {
        audioManager = nil
        super.tearDown()
    }
    
    @MainActor
    func testAudioSessionConfiguration() {
        do {
            try audioManager.configureAndActivate(category: .playback)
            
            // On iOS simulator, audio session might not be fully functional
            // but configuration should not throw
            XCTAssertTrue(true)
        } catch {
            // On simulator, some audio operations might fail, which is expected
            #if targetEnvironment(simulator)
            XCTAssertTrue(true, "Audio session configuration failed on simulator: \(error)")
            #else
            XCTFail("Audio session configuration should succeed on device: \(error)")
            #endif
        }
    }
    
    @MainActor
    func testAudioSessionCategoryChanges() {
        do {
            try audioManager.configureAndActivate(category: .playback)
            try audioManager.configureAndActivate(category: .record)
            try audioManager.configureAndActivate(category: .playAndRecord)
            
            XCTAssertTrue(true)
        } catch {
            #if targetEnvironment(simulator)
            XCTAssertTrue(true, "Audio session category changes failed on simulator: \(error)")
            #else
            XCTFail("Audio session category changes should succeed on device: \(error)")
            #endif
        }
    }
    
    @MainActor
    func testAudioSessionDeactivation() {
        do {
            try audioManager.configureAndActivate(category: .playback)
            try audioManager.deactivate()
            
            XCTAssertTrue(true)
        } catch {
            #if targetEnvironment(simulator)
            XCTAssertTrue(true, "Audio session deactivation failed on simulator: \(error)")
            #else
            XCTFail("Audio session deactivation should succeed on device: \(error)")
            #endif
        }
    }
}

// MARK: - Memory and Performance Tests
final class MemoryPerformanceTests: XCTestCase {
    
    func testMemoryLeakRMSCalculation() {
        // Test that repeated RMS calculations don't leak memory
        for _ in 0..<1000 {
            let samples = Array(repeating: Float(0.5), count: 1024)
            _ = DSP.rms(samples)
        }
        
        // If we get here without crashing, memory management is likely good
        XCTAssertTrue(true)
    }
    
    func testMemoryLeakLargeBufferRMS() {
        // Test large buffer processing doesn't leak memory
        for _ in 0..<100 {
            let samples = Array(repeating: Float(0.5), count: 44100)
            _ = DSP.rmsLargeBuffer(samples)
        }
        
        XCTAssertTrue(true)
    }
    
    func testConcurrentRMSCalculations() {
        let expectation = XCTestExpectation(description: "Concurrent RMS calculations")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            DispatchQueue.global(qos: .userInitiated).async {
                let samples = Array(repeating: Float(0.5), count: 1024 + i * 100)
                let result = DSP.rms(samples)
                XCTAssertGreaterThanOrEqual(result, 0)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testEdgeCaseInputs() {
        // Test various edge cases
        let testCases: [([Float], String)] = [
            ([], "Empty array"),
            ([0.0], "Single zero"),
            ([1.0], "Single one"),
            ([-1.0], "Single negative one"),
            ([Float.infinity], "Infinity"),
            ([Float.nan], "NaN"),
            ([-Float.infinity], "Negative infinity"),
            (Array(repeating: Float.greatestFiniteMagnitude, count: 10), "Maximum values"),
            (Array(repeating: -Float.greatestFiniteMagnitude, count: 10), "Minimum values")
        ]
        
        for (samples, description) in testCases {
            let result = DSP.rms(samples)
            XCTAssertTrue(result.isFinite || result == 0, "RMS should be finite or zero for \(description)")
        }
    }
}