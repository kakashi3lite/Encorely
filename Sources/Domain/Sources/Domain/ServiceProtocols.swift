//
//  ServiceProtocols.swift
//  Domain
//
//  Created by Claude AI on 05/30/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import AVFoundation
import Combine
import CoreData
import CoreML
import Foundation
import SharedTypes

// MARK: - Type Aliases
public protocol SongProtocol: NSManagedObject {}
public protocol MixTapeProtocol: NSManagedObject {}

public typealias Song = any SongProtocol
public typealias MixTape = any MixTapeProtocol

// MARK: - Music Service Protocol

/// Core music playback and management interface
public protocol MusicServiceProtocol {
    /// Current playback state
    var isPlaying: Bool { get }
    var currentTrack: Song? { get }
    var playbackProgress: Double { get }

    /// Publishers for reactive updates
    var playbackStatePublisher: AnyPublisher<Bool, Never> { get }
    var currentTrackPublisher: AnyPublisher<Song?, Never> { get }
    var progressPublisher: AnyPublisher<Double, Never> { get }

    /// Core playback operations
    func play(_ mixtape: MixTape) async throws
    func play(_ song: Song) async throws
    func pause()
    func resume()
    func skip(to position: TimeInterval)
    func next() async throws
    func previous() async throws

    /// AI-enhanced operations
    func crossfadeTo(_ nextSong: Song, duration: TimeInterval) async throws
    func adjustPlaybackForMood(_ mood: Mood) async
}

// MARK: - Audio Analyzer Protocol

/// Real-time audio analysis and mood detection interface
public protocol AudioAnalyzerProtocol {
    /// Analysis state
    var isAnalyzing: Bool { get }
    var currentFeatures: AudioFeatures? { get }

    /// Publishers for real-time updates
    var audioFeaturesPublisher: AnyPublisher<AudioFeatures, Never> { get }
    var moodDetectionPublisher: AnyPublisher<Mood, Never> { get }
    var visualizationDataPublisher: AnyPublisher<VisualizationData, Never> { get }

    /// Core analysis operations
    func startRealTimeAnalysis() async throws
    func stopRealTimeAnalysis()
    func analyzeAudioFile(_ url: URL) async throws -> AudioFeatures
    func detectMoodFromAudio(_ features: AudioFeatures) async -> Mood

    /// Advanced AI features
    func trainPersonalizedMoodModel(from userFeedback: [MoodFeedback]) async throws
    func generateAudioVisualization() async -> VisualizationData
}

// MARK: - Speech Service Protocol

/// Voice commands and speech sentiment analysis interface
public protocol SpeechServiceProtocol {
    /// Recognition state
    var isListening: Bool { get }
    var recognitionAuthorizationStatus: SpeechRecognitionAuthStatus { get }

    /// Publishers for voice interactions
    var speechRecognitionPublisher: AnyPublisher<String, Never> { get }
    var voiceCommandPublisher: AnyPublisher<VoiceCommand, Never> { get }
    var speechSentimentPublisher: AnyPublisher<SpeechSentiment, Never> { get }

    /// Core speech operations
    func requestRecognitionPermission() async -> Bool
    func startListening() async throws
    func stopListening()
    func processVoiceCommand(_ text: String) async -> VoiceCommand?

    /// AI sentiment analysis
    func analyzeSpeechSentiment(from audioBuffer: AVAudioPCMBuffer) async -> SpeechSentiment
    func enableContinuousListening(for duration: TimeInterval) async throws
}

// MARK: - Download Service Protocol

/// Content downloading and caching interface
public protocol DownloadServiceProtocol {
    /// Download state
    var activeDownloads: [String: DownloadProgress] { get }
    var downloadQueueCount: Int { get }

    /// Publishers for download updates
    var downloadProgressPublisher: AnyPublisher<DownloadProgress, Never> { get }
    var downloadCompletionPublisher: AnyPublisher<DownloadResult, Never> { get }

    /// Core download operations
    func downloadSong(_ song: Song) async throws -> URL
    func downloadMixtape(_ mixtape: MixTape) async throws -> [URL]
    func cancelDownload(for identifier: String)
    func pauseDownload(for identifier: String)
    func resumeDownload(for identifier: String)

    /// AI-enhanced operations
    func preloadRecommendedContent(for mood: Mood) async
    func smartCacheManagement(basedOn usage: UserUsagePattern) async
    func downloadWithPriority(_ items: [Downloadable], priority: DownloadPriority) async throws
}
