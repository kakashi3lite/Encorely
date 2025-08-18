//
//  SupportingTypes.swift
//  Domain
//
//  Created by Claude AI on 05/30/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import AVFoundation
import Foundation
import SharedTypes

// MARK: - Voice Command Types

/// Voice command representation
public struct VoiceCommand {
    public let intent: VoiceIntent
    public let parameters: [String: Any]
    public let confidence: Float
    public let originalText: String

    public init(intent: VoiceIntent, parameters: [String: Any], confidence: Float, originalText: String) {
        self.intent = intent
        self.parameters = parameters
        self.confidence = confidence
        self.originalText = originalText
    }
}

/// Voice command intents
public enum VoiceIntent: String, CaseIterable {
    case playMood = "play_mood"
    case createMixtape = "create_mixtape"
    case analyzeSong = "analyze_song"
    case showInsights = "show_insights"
    case pauseMusic = "pause_music"
    case skipSong = "skip_song"
}

// MARK: - Speech Analysis Types

/// Speech sentiment analysis result
public struct SpeechSentiment {
    public let emotion: Mood
    public let confidence: Float
    public let valence: Float // -1.0 (negative) to 1.0 (positive)
    public let arousal: Float // 0.0 (calm) to 1.0 (excited)
    public let timestamp: Date

    public init(emotion: Mood, confidence: Float, valence: Float, arousal: Float, timestamp: Date = Date()) {
        self.emotion = emotion
        self.confidence = confidence
        self.valence = valence
        self.arousal = arousal
        self.timestamp = timestamp
    }
}

/// Speech recognition authorization status
public enum SpeechRecognitionAuthStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
}

// MARK: - Download Types

/// Download progress tracking
public struct DownloadProgress {
    public let identifier: String
    public let bytesDownloaded: Int64
    public let totalBytes: Int64
    public let progress: Double
    public let state: DownloadState
    public let estimatedTimeRemaining: TimeInterval?

    public init(identifier: String, bytesDownloaded: Int64, totalBytes: Int64,
                progress: Double, state: DownloadState, estimatedTimeRemaining: TimeInterval? = nil)
    {
        self.identifier = identifier
        self.bytesDownloaded = bytesDownloaded
        self.totalBytes = totalBytes
        self.progress = progress
        self.state = state
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}

/// Download result
public struct DownloadResult {
    public let identifier: String
    public let url: URL?
    public let success: Bool
    public let error: Error?
    public let completedAt: Date

    public init(identifier: String, url: URL? = nil, success: Bool, error: Error? = nil, completedAt: Date = Date()) {
        self.identifier = identifier
        self.url = url
        self.success = success
        self.error = error
        self.completedAt = completedAt
    }
}

/// Download states
public enum DownloadState {
    case queued
    case downloading
    case paused
    case completed
    case failed
    case cancelled
}

/// Download priority levels
public enum DownloadPriority: Int, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3
}

// MARK: - Usage Pattern Types

/// User usage patterns for smart caching
public struct UserUsagePattern {
    public let frequentMoods: [Mood]
    public let peakListeningHours: [Int]
    public let preferredGenres: [String]
    public let averageSessionLength: TimeInterval
    public let downloadedContentUsage: Double

    public init(frequentMoods: [Mood], peakListeningHours: [Int], preferredGenres: [String],
                averageSessionLength: TimeInterval, downloadedContentUsage: Double)
    {
        self.frequentMoods = frequentMoods
        self.peakListeningHours = peakListeningHours
        self.preferredGenres = preferredGenres
        self.averageSessionLength = averageSessionLength
        self.downloadedContentUsage = downloadedContentUsage
    }
}

// MARK: - Visualization Types

/// Real-time visualization data
public struct VisualizationData {
    public let waveformData: [Float]
    public let spectrumData: [Float]
    public let frequencyBands: [FrequencyBand]
    public let timestamp: Date

    public init(
        waveformData: [Float],
        spectrumData: [Float],
        frequencyBands: [FrequencyBand],
        timestamp: Date = Date()
    ) {
        self.waveformData = waveformData
        self.spectrumData = spectrumData
        self.frequencyBands = frequencyBands
        self.timestamp = timestamp
    }
}

/// Frequency band data for visualizations
public struct FrequencyBand {
    public let frequency: Float
    public let magnitude: Float
    public let phase: Float

    public init(frequency: Float, magnitude: Float, phase: Float) {
        self.frequency = frequency
        self.magnitude = magnitude
        self.phase = phase
    }
}

// MARK: - AI Training Types

/// Mood feedback for ML training
public struct MoodFeedback {
    public let audioFeatures: AudioFeatures
    public let userCorrectedMood: Mood
    public let originalDetectedMood: Mood
    public let confidence: Float
    public let timestamp: Date

    public init(audioFeatures: AudioFeatures, userCorrectedMood: Mood, originalDetectedMood: Mood,
                confidence: Float, timestamp: Date = Date())
    {
        self.audioFeatures = audioFeatures
        self.userCorrectedMood = userCorrectedMood
        self.originalDetectedMood = originalDetectedMood
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

// MARK: - Downloadable Protocol

/// Downloadable content protocol
public protocol Downloadable {
    var downloadIdentifier: String { get }
    var downloadURL: URL { get }
    var estimatedSize: Int64 { get }
    var priority: DownloadPriority { get }
}
