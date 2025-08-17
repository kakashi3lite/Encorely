//
//  SensorData.swift
//  Domain
//
//  Created by AI Assistant on 05/21/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import SharedTypes

/// Aggregated sensor data for mood and context detection
public struct SensorData: Codable {
    public let timestamp: Date
    public let audioFeatures: AudioFeatures?
    public let emotionalState: EmotionalState?
    public let contextualInfo: ContextualInfo
    public let confidence: Float // 0.0-1.0

    public init(
        timestamp: Date = Date(),
        audioFeatures: AudioFeatures? = nil,
        emotionalState: EmotionalState? = nil,
        contextualInfo: ContextualInfo = ContextualInfo(),
        confidence: Float = 0.5
    ) {
        self.timestamp = timestamp
        self.audioFeatures = audioFeatures
        self.emotionalState = emotionalState
        self.contextualInfo = contextualInfo
        self.confidence = confidence
    }
}

/// Detected emotional state from various inputs
public struct EmotionalState: Codable {
    public let facialExpression: FacialExpression?
    public let voiceSentiment: VoiceSentiment?
    public let deviceUsagePattern: DeviceUsagePattern?

    public init(
        facialExpression: FacialExpression? = nil,
        voiceSentiment: VoiceSentiment? = nil,
        deviceUsagePattern: DeviceUsagePattern? = nil
    ) {
        self.facialExpression = facialExpression
        self.voiceSentiment = voiceSentiment
        self.deviceUsagePattern = deviceUsagePattern
    }
}

/// Facial expression analysis results
public struct FacialExpression: Codable {
    public let happiness: Float // 0.0-1.0
    public let sadness: Float // 0.0-1.0
    public let anger: Float // 0.0-1.0
    public let surprise: Float // 0.0-1.0
    public let fear: Float // 0.0-1.0
    public let disgust: Float // 0.0-1.0
    public let neutral: Float // 0.0-1.0

    public init(
        happiness: Float,
        sadness: Float,
        anger: Float,
        surprise: Float,
        fear: Float,
        disgust: Float,
        neutral: Float
    ) {
        self.happiness = happiness
        self.sadness = sadness
        self.anger = anger
        self.surprise = surprise
        self.fear = fear
        self.disgust = disgust
        self.neutral = neutral
    }
}

/// Voice sentiment analysis
public enum VoiceSentiment: String, Codable, CaseIterable {
    case positive, negative, neutral, excited, calm, frustrated
}

/// Device usage patterns for context
public struct DeviceUsagePattern: Codable {
    public let timeOfDay: TimeOfDay
    public let isMoving: Bool
    public let batteryLevel: Float
    public let isCharging: Bool

    public init(timeOfDay: TimeOfDay, isMoving: Bool = false, batteryLevel: Float = 1.0, isCharging: Bool = false) {
        self.timeOfDay = timeOfDay
        self.isMoving = isMoving
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
    }
}
