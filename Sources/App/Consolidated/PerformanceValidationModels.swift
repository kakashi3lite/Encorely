//  PerformanceValidationModels.swift
//  Data-only result & test case structures extracted from PerformanceValidator to shrink its size.
//  Intentionally value-centric (no methods) to keep serialization / test snapshotting trivial.

import Foundation

struct ValidationResult {
    var latencyResult = LatencyValidationResult(
        passed: false,
        averageLatencyMs: 0,
        maxLatencyMs: 0,
        processingTimes: []
    )
    var memoryResult = MemoryValidationResult(
        passed: false,
        initialMemoryMB: 0,
        peakMemoryMB: 0,
        finalMemoryMB: 0,
        memoryIncreaseMB: 0
    )
    var accuracyResult = AccuracyValidationResult(
        passed: false,
        accuracy: 0,
        correctPredictions: 0,
        totalPredictions: 0,
        detailedResults: []
    )
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
