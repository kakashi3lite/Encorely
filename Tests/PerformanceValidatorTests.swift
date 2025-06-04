//
//  PerformanceValidatorTests.swift
//  AI-MixtapesTests
//  Created by AI Assistant on 05/23/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import XCTest
@testable import App

final class PerformanceValidatorTests: XCTestCase {
    var validator: PerformanceValidator!
    
    override func setUpWithError() throws {
        validator = PerformanceValidator()
    }
    
    override func tearDownWithError() throws {
        validator = nil
    }
    
    func testValidatorInitialization() {
        XCTAssertNotNil(validator, "PerformanceValidator should initialize successfully")
    }
    
    func testValidationResultStructure() {
        let result = ValidationResult()
        
        // Default state should be failing
        XCTAssertFalse(result.overallPassed)
        XCTAssertFalse(result.latencyResult.passed)
        XCTAssertFalse(result.memoryResult.passed)
        XCTAssertFalse(result.accuracyResult.passed)
    }
    
    func testBasicLatencyValidation() async throws {
        // This is a smoke test, just checking if the function runs without crashing
        let result = await validator.validateLatencyConstraints()
        
        // We don't assert on the result since it depends on hardware, but we check the structure
        XCTAssertFalse(result.processingTimes.isEmpty, "Latency test should collect processing times")
        XCTAssertGreaterThan(result.maxLatencyMs, 0, "Maximum latency should be greater than zero")
        XCTAssertLessThanOrEqual(result.averageLatencyMs, result.maxLatencyMs, "Average latency should be less than or equal to maximum latency")
    }
    
    func testMoodTestCaseGeneration() {
        let testCases = validator.createMoodTestCases()
        
        // Verify we have test cases for all the key moods
        XCTAssertTrue(testCases.contains(where: { $0.expectedMood == .energetic }))
        XCTAssertTrue(testCases.contains(where: { $0.expectedMood == .relaxed }))
        XCTAssertTrue(testCases.contains(where: { $0.expectedMood == .happy }))
        XCTAssertTrue(testCases.contains(where: { $0.expectedMood == .melancholic }))
    }
    
    func testFullValidationWorkflow() async throws {
        // This is an expensive test, so we mark it with a longer timeout
        let expectation = XCTestExpectation(description: "Full validation should complete")
        
        // Run the validation asynchronously
        Task {
            let results = await validator.validatePerformanceConstraints()
            
            // We don't assert pass/fail because it's hardware-dependent
            // Instead we verify the structure is populated
            XCTAssertNotNil(results.latencyResult)
            XCTAssertNotNil(results.memoryResult)
            XCTAssertNotNil(results.accuracyResult)
            XCTAssertGreaterThan(results.accuracyResult.totalPredictions, 0)
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 30.0)
    }
    
    // MARK: - Helper Methods
    
    func validateTestAudioBuffer(_ buffer: AVAudioPCMBuffer, frequency: Float, duration: TimeInterval) {
        XCTAssertEqual(buffer.frameLength, AVAudioFrameCount(duration * buffer.format.sampleRate))
        XCTAssertEqual(buffer.format.channelCount, 1)
        
        // Verify buffer has actual content
        let channelData = buffer.floatChannelData![0]
        var nonZeroSamples = false
        
        for i in 0..<Int(buffer.frameLength) {
            if abs(channelData[i]) > 0.01 {
                nonZeroSamples = true
                break
            }
        }
        
        XCTAssertTrue(nonZeroSamples, "Generated audio buffer should contain non-zero samples")
    }
}

// MARK: - Extension to Make Internal Methods Testable

extension PerformanceValidator {
    // Expose internal methods for testing
    func validateLatencyConstraints() async -> LatencyValidationResult {
        return await self.validateLatencyConstraints()
    }
    
    func createMoodTestCases() -> [MoodTestCase] {
        return self.createMoodTestCases()
    }
    
    func createTestAudioBuffer(frequency: Float, duration: TimeInterval, sampleRate: Double) -> AVAudioPCMBuffer {
        return self.createTestAudioBuffer(frequency: frequency, duration: duration, sampleRate: sampleRate)
    }
}
