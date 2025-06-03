//
//  PerformanceValidator.swift
//  AI-Mixtapes
//  Created by AI Assistant on 05/23/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import AVFoundation
import os.log

/// Validates that the audio processing system meets performance constraints
class PerformanceValidator {
    
    // MARK: - Constraint Thresholds
    private var maxLatencyMs: Double {
        #if os(macOS)
        return 150.0  // 150ms for macOS
        #else
        return 100.0  // 100ms for iOS
        #endif
    }
    
    private var maxMemoryMB: Double {
        #if os(macOS)
        return 100.0  // 100MB for macOS
        #else
        return 50.0   // 50MB for iOS
        #endif
    }
    
    private static let minMoodAccuracy: Double = 0.8         // >80% requirement
    
    // MARK: - Test Configuration
    private static let testIterations = 50
    private static let testDuration: TimeInterval = 2.0
    private static let testSampleRate: Double = 44100.0
    
    private let audioProcessor: AudioProcessor
    private let audioAnalysisService: AudioAnalysisService
    private let logger = Logger(subsystem: "com.ai-mixtapes.performance", category: "validation")
    
    init() {
        self.audioProcessor = AudioProcessor()
        self.audioAnalysisService = AudioAnalysisService()
    }
    
    // MARK: - Public Validation Interface
    
    /// Run comprehensive performance validation
    func validatePerformanceConstraints() async -> ValidationResult {
        logger.info("Starting performance validation...")
        
        var results = ValidationResult()
        
        // Test latency constraints
        results.latencyResult = await validateLatencyConstraints()
        
        // Test memory constraints
        results.memoryResult = await validateMemoryConstraints()
        
        // Test accuracy constraints
        results.accuracyResult = await validateAccuracyConstraints()
        
        // Overall assessment
        results.overallPassed = results.latencyResult.passed && 
                               results.memoryResult.passed && 
                               results.accuracyResult.passed
        
        logValidationResults(results)
        
        return results
    }
    
    // MARK: - Latency Validation
    
    private func validateLatencyConstraints() async -> LatencyValidationResult {
        logger.info("Validating latency constraints...")
        
        var processingTimes: [TimeInterval] = []
        
        for i in 0..<Self.testIterations {
            let testBuffer = createTestAudioBuffer(
                frequency: Float(440 + i * 10),
                duration: Self.testDuration,
                sampleRate: Self.testSampleRate
            )
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                _ = try await audioProcessor.extractFeatures(from: testBuffer)
                let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                processingTimes.append(processingTime)
            } catch {
                logger.error("Feature extraction failed during latency test: \(error.localizedDescription)")
                return LatencyValidationResult(
                    passed: false,
                    averageLatencyMs: 0,
                    maxLatencyMs: 0,
                    processingTimes: []
                )
            }
        }
        
        let averageLatency = processingTimes.reduce(0, +) / Double(processingTimes.count)
        let maxLatency = processingTimes.max() ?? 0
        
        let averageLatencyMs = averageLatency * 1000
        let maxLatencyMs = maxLatency * 1000
        
        let passed = averageLatencyMs < Self.maxLatencyMs && maxLatencyMs < (Self.maxLatencyMs * 1.5)
        
        return LatencyValidationResult(
            passed: passed,
            averageLatencyMs: averageLatencyMs,
            maxLatencyMs: maxLatencyMs,
            processingTimes: processingTimes
        )
    }
    
    // MARK: - Memory Validation
    
    private func validateMemoryConstraints() async -> MemoryValidationResult {
        logger.info("Validating memory constraints...")
        
        let initialMemory = getMemoryUsage()
        var peakMemory = initialMemory
        
        // Stress test with multiple concurrent processes
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let buffer = self.createLargeTestBuffer(
                        frequency: Float(440 + i * 50),
                        duration: 5.0
                    )
                    
                    do {
                        _ = try await self.audioProcessor.extractFeatures(from: buffer)
                    } catch {
                        self.logger.error("Memory stress test failed: \(error.localizedDescription)")
                    }
                    
                    // Track peak memory
                    let currentMemory = self.getMemoryUsage()
                    if currentMemory > peakMemory {
                        peakMemory = currentMemory
                    }
                }
            }
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        let initialMemoryMB = Double(initialMemory) / (1024 * 1024)
        let peakMemoryMB = Double(peakMemory) / (1024 * 1024)
        let finalMemoryMB = Double(finalMemory) / (1024 * 1024)
        let memoryIncreaseMB = Double(memoryIncrease) / (1024 * 1024)
        
        let passed = peakMemoryMB < Self.maxMemoryMB && memoryIncreaseMB < (Self.maxMemoryMB * 0.2)
        
        return MemoryValidationResult(
            passed: passed,
            initialMemoryMB: initialMemoryMB,
            peakMemoryMB: peakMemoryMB,
            finalMemoryMB: finalMemoryMB,
            memoryIncreaseMB: memoryIncreaseMB
        )
    }
    
    // MARK: - Accuracy Validation
    
    private func validateAccuracyConstraints() async -> AccuracyValidationResult {
        logger.info("Validating mood detection accuracy...")
        
        let testCases = createMoodTestCases()
        var correctPredictions = 0
        var totalPredictions = 0
        var detailedResults: [MoodTestResult] = []
        
        for testCase in testCases {
            let buffer = createMoodSpecificAudioBuffer(
                mood: testCase.expectedMood,
                duration: 3.0
            )
            
            do {
                let features = try await audioProcessor.extractFeatures(from: buffer)
                let predictedMood = features.getDominantMood()
                
                let isCorrect = predictedMood == testCase.expectedMood
                if isCorrect {
                    correctPredictions += 1
                }
                totalPredictions += 1
                
                detailedResults.append(MoodTestResult(
                    expectedMood: testCase.expectedMood,
                    predictedMood: predictedMood,
                    features: features,
                    isCorrect: isCorrect,
                    confidence: calculateMoodConfidence(features: features, mood: predictedMood)
                ))
                
            } catch {
                logger.error("Mood detection test failed: \(error.localizedDescription)")
                totalPredictions += 1
                
                detailedResults.append(MoodTestResult(
                    expectedMood: testCase.expectedMood,
                    predictedMood: .neutral,
                    features: nil,
                    isCorrect: false,
                    confidence: 0.0
                ))
            }
        }
        
        let accuracy = totalPredictions > 0 ? Double(correctPredictions) / Double(totalPredictions) : 0.0
        let passed = accuracy >= Self.minMoodAccuracy
        
        return AccuracyValidationResult(
            passed: passed,
            accuracy: accuracy,
            correctPredictions: correctPredictions,
            totalPredictions: totalPredictions,
            detailedResults: detailedResults
        )
    }
    
    // MARK: - Test Data Generation
    
    private func createTestAudioBuffer(
        frequency: Float,
        duration: TimeInterval,
        sampleRate: Double
    ) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        
        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        
        for i in 0..<Int(frameCount) {
            let sample = sin(2.0 * .pi * frequency * Float(i) / Float(sampleRate))
            channelData[i] = sample
        }
        
        return buffer
    }
    
    private func createLargeTestBuffer(frequency: Float, duration: TimeInterval) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * Self.testSampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.testSampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        
        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        
        // Create complex multi-frequency signal
        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(Self.testSampleRate)
            let sample = sin(2.0 * .pi * frequency * t) * 0.5 +
                        sin(2.0 * .pi * (frequency * 2) * t) * 0.3 +
                        sin(2.0 * .pi * (frequency * 0.5) * t) * 0.2
            channelData[i] = sample
        }
        
        return buffer
    }
    
    private func createMoodTestCases() -> [MoodTestCase] {
        return [
            MoodTestCase(expectedMood: .energetic, description: "High tempo, high energy"),
            MoodTestCase(expectedMood: .relaxed, description: "Low tempo, low energy"),
            MoodTestCase(expectedMood: .happy, description: "Medium tempo, high valence"),
            MoodTestCase(expectedMood: .melancholic, description: "Low tempo, low valence"),
            MoodTestCase(expectedMood: .focused, description: "Medium tempo, balanced energy"),
            MoodTestCase(expectedMood: .romantic, description: "Slow tempo, medium valence"),
            MoodTestCase(expectedMood: .angry, description: "Fast tempo, high energy, low valence"),
            MoodTestCase(expectedMood: .neutral, description: "Balanced all features")
        ]
    }
    
    private func createMoodSpecificAudioBuffer(mood: Mood, duration: TimeInterval) -> AVAudioPCMBuffer {
        let frameCount = AVAudioFrameCount(duration * Self.testSampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.testSampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        
        buffer.frameLength = frameCount
        let channelData = buffer.floatChannelData![0]
        
        // Generate audio characteristics specific to each mood
        let (baseFreq, tempo, amplitude) = getMoodCharacteristics(mood)
        let beatsPerSecond = tempo / 60.0
        let samplesPerBeat = Float(Self.testSampleRate) / beatsPerSecond
        
        for i in 0..<Int(frameCount) {
            let t = Float(i) / Float(Self.testSampleRate)
            let beatPhase = Float(i).truncatingRemainder(dividingBy: samplesPerBeat) / samplesPerBeat
            
            // Base tone
            var sample = sin(2.0 * .pi * baseFreq * t) * amplitude
            
            // Add mood-specific characteristics
            switch mood {
            case .energetic:
                // Add harmonics and beat emphasis
                sample += sin(2.0 * .pi * baseFreq * 2 * t) * 0.3
                if beatPhase < 0.1 {
                    sample *= 1.5
                }
                
            case .relaxed:
                // Softer, more sustained tones
                sample *= 0.6
                sample += sin(2.0 * .pi * baseFreq * 0.5 * t) * 0.2
                
            case .happy:
                // Major key harmonics
                sample += sin(2.0 * .pi * baseFreq * 1.25 * t) * 0.4  // Major third
                sample += sin(2.0 * .pi * baseFreq * 1.5 * t) * 0.3   // Perfect fifth
                
            case .melancholic:
                // Minor key intervals
                sample += sin(2.0 * .pi * baseFreq * 1.2 * t) * 0.4   // Minor third
                sample *= 0.7
                
            case .angry:
                // Dissonant harmonics and sharp attacks
                sample += sin(2.0 * .pi * baseFreq * 1.41 * t) * 0.5  // Tritone
                if beatPhase < 0.05 {
                    sample *= 2.0
                }
                
            default:
                // Keep basic sine wave for other moods
                break
            }
            
            channelData[i] = sample
        }
        
        return buffer
    }
    
    private func getMoodCharacteristics(_ mood: Mood) -> (frequency: Float, tempo: Float, amplitude: Float) {
        switch mood {
        case .energetic:
            return (440.0, 140.0, 0.9)
        case .relaxed:
            return (220.0, 70.0, 0.4)
        case .happy:
            return (330.0, 120.0, 0.8)
        case .melancholic:
            return (196.0, 60.0, 0.5)
        case .focused:
            return (440.0, 100.0, 0.6)
        case .romantic:
            return (293.0, 80.0, 0.6)
        case .angry:
            return (466.0, 160.0, 0.95)
        case .neutral:
            return (440.0, 120.0, 0.7)
        }
    }
    
    private func calculateMoodConfidence(features: AudioFeatures, mood: Mood) -> Float {
        return mood.matchScore(for: features)
    }
    
    // MARK: - System Memory Monitoring
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    // MARK: - Logging
    
    private func logValidationResults(_ results: ValidationResult) {
        logger.info("=== Performance Validation Results ===")
        
        // Latency Results
        logger.info("Latency: \(results.latencyResult.passed ? "PASSED" : "FAILED")")
        logger.info("  Average: \(String(format: "%.1f", results.latencyResult.averageLatencyMs))ms (target: <\(Self.maxLatencyMs)ms)")
        logger.info("  Maximum: \(String(format: "%.1f", results.latencyResult.maxLatencyMs))ms")
        
        // Memory Results
        logger.info("Memory: \(results.memoryResult.passed ? "PASSED" : "FAILED")")
        logger.info("  Peak Usage: \(String(format: "%.1f", results.memoryResult.peakMemoryMB))MB (target: <\(Self.maxMemoryMB)MB)")
        logger.info("  Memory Increase: \(String(format: "%.1f", results.memoryResult.memoryIncreaseMB))MB")
        
        // Accuracy Results
        logger.info("Accuracy: \(results.accuracyResult.passed ? "PASSED" : "FAILED")")
        logger.info("  Mood Detection: \(String(format: "%.1f", results.accuracyResult.accuracy * 100))% (target: >\(Self.minMoodAccuracy * 100)%)")
        logger.info("  Correct Predictions: \(results.accuracyResult.correctPredictions)/\(results.accuracyResult.totalPredictions)")
        
        // Overall Result
        logger.info("Overall: \(results.overallPassed ? "PASSED" : "FAILED")")
        
        // Detailed mood results
        for result in results.accuracyResult.detailedResults {
            let status = result.isCorrect ? "✓" : "✗"
            logger.debug("\(status) Expected: \(result.expectedMood.rawValue), Got: \(result.predictedMood.rawValue), Confidence: \(String(format: "%.2f", result.confidence))")
        }
    }
}

// MARK: - Result Structures

struct ValidationResult {
    var latencyResult = LatencyValidationResult(passed: false, averageLatencyMs: 0, maxLatencyMs: 0, processingTimes: [])
    var memoryResult = MemoryValidationResult(passed: false, initialMemoryMB: 0, peakMemoryMB: 0, finalMemoryMB: 0, memoryIncreaseMB: 0)
    var accuracyResult = AccuracyValidationResult(passed: false, accuracy: 0, correctPredictions: 0, totalPredictions: 0, detailedResults: [])
    var overallPassed = false
}

struct LatencyValidationResult {
    let passed: Bool
    let averageLatencyMs: Double
    let maxLatencyMs: Double
    let processingTimes: [TimeInterval]
}

struct MemoryValidationResult {
    let passed: Bool
    let initialMemoryMB: Double
    let peakMemoryMB: Double
    let finalMemoryMB: Double
    let memoryIncreaseMB: Double
}

struct AccuracyValidationResult {
    let passed: Bool
    let accuracy: Double
    let correctPredictions: Int
    let totalPredictions: Int
    let detailedResults: [MoodTestResult]
}

struct MoodTestCase {
    let expectedMood: Mood
    let description: String
}

struct MoodTestResult {
    let expectedMood: Mood
    let predictedMood: Mood
    let features: AudioFeatures?
    let isCorrect: Bool
    let confidence: Float
}

// MARK: - Usage Example

/*
// Run validation in your app or tests
let validator = PerformanceValidator()

Task {
    let results = await validator.validatePerformanceConstraints()
    
    if results.overallPassed {
        print("✅ All performance constraints met!")
    } else {
        print("❌ Performance validation failed:")
        
        if !results.latencyResult.passed {
            print("  - Latency constraint failed")
        }
        if !results.memoryResult.passed {
            print("  - Memory constraint failed")  
        }
        if !results.accuracyResult.passed {
            print("  - Accuracy constraint failed")
        }
    }
}
*/
