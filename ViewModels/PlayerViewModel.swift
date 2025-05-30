//
//  PlayerViewModel.swift
//  AI-Mixtapes
//
//  Created by Reactive Specialist on 05/30/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import Combine
import AVFoundation
import CoreML

// MARK: - Playback Data Model

struct PlaybackData: Equatable {
    let track: PlayingTrack?
    let audioFeatures: AudioFeatures?
    let visualizationData: VisualizationData?
    let timestamp: Date
    
    static let empty = PlaybackData(
        track: nil,
        audioFeatures: nil,
        visualizationData: nil,
        timestamp: Date()
    )
}

struct PlayingTrack: Equatable {
    let id: UUID
    let title: String
    let artist: String
    let duration: TimeInterval
    let currentTime: TimeInterval
    let isPlaying: Bool
    let mood: Mood?
}

struct VisualizationData: Equatable {
    let waveformData: [Float]
    let spectrumData: [Float]
    let peakLevel: Float
    let averageLevel: Float
    
    static let empty = VisualizationData(
        waveformData: [],
        spectrumData: [],
        peakLevel: 0.0,
        averageLevel: 0.0
    )
}

// MARK: - Player View Model

@MainActor
class PlayerViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var playbackData: PlaybackData = .empty
    @Published var isLoading: Bool = false
    @Published var error: AppError?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Private Properties
    
    private let musicService: MusicService
    private let audioAnalyzer: AudioAnalyzer
    private let aiService: AIIntegrationService
    
    private var cancellables = Set<AnyCancellable>()
    private var analysisTimer: Timer?
    
    // MARK: - Connection Status
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(AppError)
    }
    
    // MARK: - Initialization
    
    init(
        musicService: MusicService,
        audioAnalyzer: AudioAnalyzer,
        aiService: AIIntegrationService
    ) {
        self.musicService = musicService
        self.audioAnalyzer = audioAnalyzer
        self.aiService = aiService
        
        setupBindings()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    func startPlayback() {
        isLoading = true
        
        musicService.startPlayback()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.connectionStatus = .connected
                    self?.aiService.trackInteraction(type: "playback_started")
                }
            )
            .store(in: &cancellables)
    }
    
    func stopPlayback() {
        musicService.stopPlayback()
        connectionStatus = .disconnected
        playbackData = .empty
        aiService.trackInteraction(type: "playback_stopped")
    }
    
    func pausePlayback() {
        musicService.pausePlayback()
        aiService.trackInteraction(type: "playback_paused")
    }
    
    func resumePlayback() {
        musicService.resumePlayback()
        aiService.trackInteraction(type: "playback_resumed")
    }
    
    func seekTo(time: TimeInterval) {
        musicService.seekTo(time: time)
        aiService.trackInteraction(type: "playback_seek")
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Combine track and FFT publishers into unified playback data
        let combinedPublisher = Publishers.CombineLatest3(
            musicService.trackPublisher,
            audioAnalyzer.fftPublisher,
            audioAnalyzer.audioFeaturesPublisher
        )
        .map { [weak self] track, fftData, features -> PlaybackData in
            self?.createPlaybackData(
                track: track,
                fftData: fftData,
                features: features
            ) ?? .empty
        }
        .catch { [weak self] error -> Just<PlaybackData> in
            self?.handleError(error)
            return Just(.empty)
        }
        
        // Bind combined publisher to playbackData
        combinedPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.playbackData, on: self)
            .store(in: &cancellables)
        
        // Handle connection status changes
        Publishers.CombineLatest(
            musicService.connectionStatusPublisher,
            audioAnalyzer.connectionStatusPublisher
        )
        .map { musicStatus, analyzerStatus -> ConnectionStatus in
            switch (musicStatus, analyzerStatus) {
            case (.connected, .connected):
                return .connected
            case (.connecting, _), (_, .connecting):
                return .connecting
            case (.error(let error), _), (_, .error(let error)):
                return .error(error)
            default:
                return .disconnected
            }
        }
        .receive(on: DispatchQueue.main)
        .assign(to: \.connectionStatus, on: self)
        .store(in: &cancellables)
        
        // Handle errors from both services
        Publishers.Merge(
            musicService.errorPublisher,
            audioAnalyzer.errorPublisher
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] error in
            self?.handleError(error)
        }
        .store(in: &cancellables)
        
        // Track mood changes based on audio analysis
        playbackData.publisher
            .compactMap { $0.audioFeatures }
            .removeDuplicates()
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] features in
                self?.processMoodDetection(from: features)
            }
            .store(in: &cancellables)
        
        // Automatically analyze audio when playback starts
        connectionStatus.publisher
            .filter { $0 == .connected }
            .sink { [weak self] _ in
                self?.startAudioAnalysis()
            }
            .store(in: &cancellables)
    }
    
    private func createPlaybackData(
        track: MusicTrack?,
        fftData: FFTData?,
        features: AudioFeatures?
    ) -> PlaybackData {
        let playingTrack = track.map { track in
            PlayingTrack(
                id: track.id,
                title: track.title,
                artist: track.artist,
                duration: track.duration,
                currentTime: track.currentTime,
                isPlaying: track.isPlaying,
                mood: determineMood(from: features)
            )
        }
        
        let visualizationData = fftData.map { data in
            VisualizationData(
                waveformData: data.waveform,
                spectrumData: data.spectrum,
                peakLevel: data.peakLevel,
                averageLevel: data.averageLevel
            )
        } ?? .empty
        
        return PlaybackData(
            track: playingTrack,
            audioFeatures: features,
            visualizationData: visualizationData,
            timestamp: Date()
        )
    }
    
    private func startMonitoring() {
        // Start periodic monitoring for connection health
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkConnectionHealth()
        }
    }
    
    private func stopMonitoring() {
        analysisTimer?.invalidate()
        analysisTimer = nil
    }
    
    private func startAudioAnalysis() {
        audioAnalyzer.startRealTimeAnalysis()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.aiService.trackInteraction(type: "audio_analysis_started")
                }
            )
            .store(in: &cancellables)
    }
    
    private func checkConnectionHealth() {
        // Monitor for stale data or disconnections
        let now = Date()
        let dataAge = now.timeIntervalSince(playbackData.timestamp)
        
        if dataAge > 5.0 && connectionStatus == .connected {
            // Data is stale, attempt reconnection
            connectionStatus = .connecting
            reconnectServices()
        }
    }
    
    private func reconnectServices() {
        // Attempt to reconnect both services
        Publishers.Zip(
            musicService.reconnect(),
            audioAnalyzer.reconnect()
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.connectionStatus = .error(error as? AppError ?? .aiServiceUnavailable)
                }
            },
            receiveValue: { [weak self] _ in
                self?.connectionStatus = .connected
                self?.aiService.trackInteraction(type: "services_reconnected")
            }
        )
        .store(in: &cancellables)
    }
    
    private func handleError(_ error: Error) {
        let appError = error as? AppError ?? .audioProcessingFailed(error)
        self.error = appError
        
        // Track error for analytics
        aiService.trackInteraction(type: "player_error_\(appError.localizedDescription)")
        
        // Attempt recovery for certain error types
        switch appError {
        case .audioUnavailable, .audioProcessingFailed:
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.attemptRecovery()
            }
        default:
            break
        }
    }
    
    private func attemptRecovery() {
        guard error != nil else { return }
        
        isLoading = true
        error = nil
        
        // Try to restart services
        stopPlayback()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startPlayback()
        }
    }
    
    private func processMoodDetection(from features: AudioFeatures) {
        // Determine mood from audio features and update AI service
        let detectedMood = determineMood(from: features)
        
        if let mood = detectedMood {
            let confidence = calculateMoodConfidence(from: features)
            aiService.moodEngine.updateMoodFromAudio(mood, confidence: confidence)
            aiService.trackInteraction(type: "mood_detected_\(mood.rawValue)")
        }
    }
    
    private func determineMood(from features: AudioFeatures?) -> Mood? {
        guard let features = features else { return nil }
        
        // Simple mood determination logic based on audio features
        if features.energy > 0.7 && features.valence > 0.6 {
            return .energetic
        } else if features.energy < 0.3 && features.valence > 0.5 {
            return .relaxed
        } else if features.valence > 0.7 {
            return .happy
        } else if features.valence < 0.3 {
            return .melancholic
        } else if features.energy > 0.5 && features.valence < 0.4 {
            return .angry
        } else if features.instrumentalness > 0.6 {
            return .focused
        } else if features.energy < 0.5 && features.acousticness > 0.6 {
            return .romantic
        } else {
            return .neutral
        }
    }
    
    private func calculateMoodConfidence(from features: AudioFeatures) -> Float {
        // Calculate confidence based on how distinctly the features match a mood
        let energyConfidence = abs(features.energy - 0.5) * 2
        let valenceConfidence = abs(features.valence - 0.5) * 2
        
        return min((energyConfidence + valenceConfidence) / 2, 1.0)
    }
}

// MARK: - Service Protocols

protocol MusicService {
    var trackPublisher: AnyPublisher<MusicTrack?, Never> { get }
    var connectionStatusPublisher: AnyPublisher<ServiceConnectionStatus, Never> { get }
    var errorPublisher: AnyPublisher<AppError, Never> { get }
    
    func startPlayback() -> AnyPublisher<Void, AppError>
    func stopPlayback()
    func pausePlayback()
    func resumePlayback()
    func seekTo(time: TimeInterval)
    func reconnect() -> AnyPublisher<Void, AppError>
}

protocol AudioAnalyzer {
    var fftPublisher: AnyPublisher<FFTData?, Never> { get }
    var audioFeaturesPublisher: AnyPublisher<AudioFeatures?, Never> { get }
    var connectionStatusPublisher: AnyPublisher<ServiceConnectionStatus, Never> { get }
    var errorPublisher: AnyPublisher<AppError, Never> { get }
    
    func startRealTimeAnalysis() -> AnyPublisher<Void, AppError>
    func stopRealTimeAnalysis()
    func reconnect() -> AnyPublisher<Void, AppError>
}

// MARK: - Supporting Types

struct MusicTrack: Equatable {
    let id: UUID
    let title: String
    let artist: String
    let duration: TimeInterval
    let currentTime: TimeInterval
    let isPlaying: Bool
}

struct FFTData: Equatable {
    let waveform: [Float]
    let spectrum: [Float]
    let peakLevel: Float
    let averageLevel: Float
}

enum ServiceConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case error(AppError)
}

// MARK: - Convenience Extensions

extension PlayerViewModel {
    
    var isPlaying: Bool {
        playbackData.track?.isPlaying ?? false
    }
    
    var currentTrack: PlayingTrack? {
        playbackData.track
    }
    
    var hasAudioData: Bool {
        !playbackData.visualizationData?.waveformData.isEmpty ?? false
    }
    
    var currentMood: Mood? {
        playbackData.track?.mood
    }
    
    var isConnected: Bool {
        if case .connected = connectionStatus {
            return true
        }
        return false
    }
}

// MARK: - Preview Support

#if DEBUG
extension PlayerViewModel {
    static let preview: PlayerViewModel = {
        PlayerViewModel(
            musicService: MockMusicService(),
            audioAnalyzer: MockAudioAnalyzer(),
            aiService: AIIntegrationService(context: PersistenceController.preview.container.viewContext)
        )
    }()
}

class MockMusicService: MusicService {
    var trackPublisher: AnyPublisher<MusicTrack?, Never> {
        Just(MusicTrack(
            id: UUID(),
            title: "Sample Song",
            artist: "Sample Artist",
            duration: 180,
            currentTime: 45,
            isPlaying: true
        )).eraseToAnyPublisher()
    }
    
    var connectionStatusPublisher: AnyPublisher<ServiceConnectionStatus, Never> {
        Just(.connected).eraseToAnyPublisher()
    }
    
    var errorPublisher: AnyPublisher<AppError, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    func startPlayback() -> AnyPublisher<Void, AppError> {
        Just(()).setFailureType(to: AppError.self).eraseToAnyPublisher()
    }
    
    func stopPlayback() {}
    func pausePlayback() {}
    func resumePlayback() {}
    func seekTo(time: TimeInterval) {}
    
    func reconnect() -> AnyPublisher<Void, AppError> {
        Just(()).setFailureType(to: AppError.self).eraseToAnyPublisher()
    }
}

class MockAudioAnalyzer: AudioAnalyzer {
    var fftPublisher: AnyPublisher<FFTData?, Never> {
        Just(FFTData(
            waveform: Array(repeating: 0.5, count: 100),
            spectrum: Array(repeating: 0.3, count: 50),
            peakLevel: 0.8,
            averageLevel: 0.4
        )).eraseToAnyPublisher()
    }
    
    var audioFeaturesPublisher: AnyPublisher<AudioFeatures?, Never> {
        Just(AudioFeatures(
            tempo: 120,
            energy: 0.6,
            valence: 0.7,
            danceability: 0.8,
            acousticness: 0.3,
            instrumentalness: 0.1,
            speechiness: 0.05,
            liveness: 0.2
        )).eraseToAnyPublisher()
    }
    
    var connectionStatusPublisher: AnyPublisher<ServiceConnectionStatus, Never> {
        Just(.connected).eraseToAnyPublisher()
    }
    
    var errorPublisher: AnyPublisher<AppError, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    func startRealTimeAnalysis() -> AnyPublisher<Void, AppError> {
        Just(()).setFailureType(to: AppError.self).eraseToAnyPublisher()
    }
    
    func stopRealTimeAnalysis() {}
    
    func reconnect() -> AnyPublisher<Void, AppError> {
        Just(()).setFailureType(to: AppError.self).eraseToAnyPublisher()
    }
}
#endif
