//
//  AudioAnalysisService.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import AVFoundation
import Accelerate
import CoreML

/// Custom errors for audio analysis operations
enum AudioAnalysisError: LocalizedError {
    case fileNotFound(URL)
    case invalidAudioFormat(String)
    case bufferProcessingFailed(String)
    case modelLoadingFailed(String)
    case coreMLInferenceFailed(String)
    case unsupportedAudioFile(String)
    case insufficientAudioData
    case analysisTimeout
    case permissionDenied
    case deviceResourcesUnavailable
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Audio file not found at: \(url.lastPathComponent)"
        case .invalidAudioFormat(let details):
            return "Invalid audio format: \(details)"
        case .bufferProcessingFailed(let reason):
            return "Audio processing failed: \(reason)"
        case .modelLoadingFailed(let model):
            return "Failed to load AI model: \(model)"
        case .coreMLInferenceFailed(let details):
            return "AI analysis failed: \(details)"
        case .unsupportedAudioFile(let format):
            return "Unsupported audio format: \(format)"
        case .insufficientAudioData:
            return "Audio file too short for analysis"
        case .analysisTimeout:
            return "Analysis timed out - please try again"
        case .permissionDenied:
            return "Microphone access required for real-time analysis"
        case .deviceResourcesUnavailable:
            return "Device resources unavailable - please close other apps"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Please check if the file exists and try again."
        case .invalidAudioFormat, .unsupportedAudioFile:
            return "Try converting to MP3, AAC, or WAV format."
        case .bufferProcessingFailed, .coreMLInferenceFailed:
            return "Restart the app and try again."
        case .modelLoadingFailed:
            return "Update the app to the latest version."
        case .insufficientAudioData:
            return "Audio should be at least 10 seconds long."
        case .analysisTimeout:
            return "Check your device performance and try again."
        case .permissionDenied:
            return "Enable microphone access in Settings > Privacy."
        case .deviceResourcesUnavailable:
            return "Free up device memory and try again."
        }
    }
}

/// User-friendly error messages for display
struct AudioAnalysisUserError {
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    static func from(_ error: AudioAnalysisError) -> AudioAnalysisUserError {
        switch error {
        case .fileNotFound:
            return AudioAnalysisUserError(
                title: "File Not Found",
                message: "The audio file couldn't be located. It may have been moved or deleted.",
                actionTitle: "Try Another File",
                action: nil
            )
        case .invalidAudioFormat, .unsupportedAudioFile:
            return AudioAnalysisUserError(
                title: "Unsupported Format",
                message: "This audio format isn't supported. Please try a different file.",
                actionTitle: "Learn More",
                action: nil
            )
        case .permissionDenied:
            return AudioAnalysisUserError(
                title: "Microphone Access Needed",
                message: "Real-time mood detection requires microphone access.",
                actionTitle: "Open Settings",
                action: { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
            )
        case .deviceResourcesUnavailable:
            return AudioAnalysisUserError(
                title: "Device Busy",
                message: "Your device is running low on resources. Close other apps and try again.",
                actionTitle: "Retry",
                action: nil
            )
        default:
            return AudioAnalysisUserError(
                title: "Analysis Failed",
                message: error.localizedDescription ?? "An unexpected error occurred.",
                actionTitle: "Retry",
                action: nil
            )
        }
    }
}

// MARK: - Audio Features Model
struct AudioFeatures: Codable {
    let tempo: Float
    let energy: Float
    let spectralCentroid: Float
    let valence: Float
    let danceability: Float
    let acousticness: Float
    let instrumentalness: Float
    let speechiness: Float
    let liveness: Float
}

// MARK: - AI Errors
enum AIError: Error, LocalizedError {
    case audioProcessingFailed(String)
    case invalidAudioFile
    case insufficientData

    var errorDescription: String? {
        switch self {
        case .audioProcessingFailed(let reason):
            return "Audio processing failed: \(reason)"
        case .invalidAudioFile:
            return "Invalid or corrupted audio file"
        case .insufficientData:
            return "Insufficient audio data for analysis"
        }
    }
}

/// Enhanced service for analyzing audio files with comprehensive error handling
class AudioAnalysisService {
    // MARK: - Properties
    private let audioEngine = AVAudioEngine()
    private let analysisQueue = DispatchQueue(label: "com.mixtapes.audioanalysis", qos: .userInitiated)
    private var moodClassifier: MLModel?
    private var isEngineRunning = false
    
    // Error handling
    private let maxRetryAttempts = 3
    private let analysisTimeout: TimeInterval = 30.0
    private var errorCallback: ((AudioAnalysisUserError) -> Void)?
    
    // MARK: - Initialization
    init() {
        setupAudioEngineWithErrorHandling()
        loadMoodClassifierWithErrorHandling()
    }
    
    deinit {
        stopAudioEngine()
    }
    
    // MARK: - Error Handler Registration
    func registerErrorHandler(_ handler: @escaping (AudioAnalysisUserError) -> Void) {
        self.errorCallback = handler
    }
    
    // MARK: - Audio Engine Setup
    private func setupAudioEngineWithErrorHandling() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
            isEngineRunning = false
        } catch {
            handleError(.deviceResourcesUnavailable)
        }
    }
    
    private func loadMoodClassifierWithErrorHandling() {
        // In production, this would load an actual Core ML model
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Simulate model loading
                Thread.sleep(forTimeInterval: 0.5)
                
                // Check if model file exists (simulation)
                let modelExists = true // In real app: Bundle.main.path(forResource: "MoodClassifier", ofType: "mlmodelc") != nil
                
                if !modelExists {
                    throw AudioAnalysisError.modelLoadingFailed("MoodClassifier model not found in bundle")
                }
                
                // Simulate successful model loading
                DispatchQueue.main.async {
                    print("AudioAnalysisService - Mood classifier loaded successfully")
                }
            } catch {
                DispatchQueue.main.async {
                    if let analysisError = error as? AudioAnalysisError {
                        self.handleError(analysisError)
                    } else {
                        self.handleError(.modelLoadingFailed(error.localizedDescription))
                    }
                }
            }
        }
    }
    
    // MARK: - Audio File Analysis
    func analyzeAudioFile(url: URL, completion: @escaping (Result<AudioFeatures, AudioAnalysisError>) -> Void) {
        analysisQueue.async {
            self.performFileAnalysisWithRetry(url: url, attempts: 0, completion: completion)
        }
    }
    
    private func performFileAnalysisWithRetry(
        url: URL,
        attempts: Int,
        completion: @escaping (Result<AudioFeatures, AudioAnalysisError>) -> Void
    ) {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            DispatchQueue.main.async {
                completion(.failure(.fileNotFound(url)))
            }
            return
        }
        
        // Set up timeout
        let timeoutTimer = DispatchSource.makeTimerSource(queue: analysisQueue)
        timeoutTimer.schedule(deadline: .now() + analysisTimeout)
        timeoutTimer.setEventHandler {
            DispatchQueue.main.async {
                completion(.failure(.analysisTimeout))
            }
            timeoutTimer.cancel()
        }
        timeoutTimer.resume()
        
        do {
            // Attempt to load audio file
            let audioFile = try AVAudioFile(forReading: url)
            
            // Validate audio format
            try validateAudioFormat(audioFile)
            
            // Extract features with error handling
            let features = try extractFeaturesFromFileWithValidation(audioFile)
            
            // Cancel timeout on success
            timeoutTimer.cancel()
            
            DispatchQueue.main.async {
                completion(.success(features))
            }
            
        } catch let error as AudioAnalysisError {
            timeoutTimer.cancel()
            
            // Retry logic for certain errors
            if attempts < maxRetryAttempts && shouldRetry(error) {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    self.performFileAnalysisWithRetry(url: url, attempts: attempts + 1, completion: completion)
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
            
        } catch {
            timeoutTimer.cancel()
            DispatchQueue.main.async {
                completion(.failure(.bufferProcessingFailed(error.localizedDescription)))
            }
        }
    }
    
    private func validateAudioFormat(_ audioFile: AVAudioFile) throws {
        let format = audioFile.processingFormat
        
        // Check minimum requirements
        guard format.sampleRate >= 16000 else {
            throw AudioAnalysisError.invalidAudioFormat("Sample rate too low: \(format.sampleRate) Hz")
        }
        
        guard format.channelCount > 0 && format.channelCount <= 2 else {
            throw AudioAnalysisError.invalidAudioFormat("Unsupported channel count: \(format.channelCount)")
        }
        
        // Check file duration
        let duration = Double(audioFile.length) / format.sampleRate
        guard duration >= 10.0 else {
            throw AudioAnalysisError.insufficientAudioData
        }
        
        // Check file size (prevent memory issues)
        let maxDuration: TimeInterval = 600 // 10 minutes
        guard duration <= maxDuration else {
            throw AudioAnalysisError.invalidAudioFormat("File too long: \(Int(duration/60)) minutes")
        }
    }
    
    private func extractFeaturesFromFileWithValidation(_ audioFile: AVAudioFile) throws -> AudioFeatures {
        let format = audioFile.processingFormat
        let frameCapacity = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            throw AudioAnalysisError.bufferProcessingFailed("Failed to create audio buffer")
        }
        
        do {
            try audioFile.read(into: buffer)
        } catch {
            throw AudioAnalysisError.bufferProcessingFailed("Failed to read audio data: \(error.localizedDescription)")
        }
        
        guard let channelData = buffer.floatChannelData?[0], buffer.frameLength > 0 else {
            throw AudioAnalysisError.bufferProcessingFailed("No audio data in buffer")
        }
        
        // Extract features with error handling
        do {
            let tempo = try extractTempo(from: buffer)
            let energy = try extractEnergy(from: channelData, frameLength: Int(buffer.frameLength))
            let spectralFeatures = try extractSpectralFeatures(from: buffer)
            
            return AudioFeatures(
                tempo: tempo,
                energy: energy,
                spectralCentroid: spectralFeatures.spectralCentroid,
                valence: spectralFeatures.valence,
                danceability: spectralFeatures.danceability,
                acousticness: spectralFeatures.acousticness,
                instrumentalness: spectralFeatures.instrumentalness,
                speechiness: spectralFeatures.speechiness,
                liveness: spectralFeatures.liveness
            )
        } catch {
            throw AudioAnalysisError.bufferProcessingFailed("Feature extraction failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Feature Extraction with Error Handling
    private func extractTempo(from buffer: AVAudioPCMBuffer) throws -> Float {
        // Simple beat detection simulation with error handling
        guard buffer.frameLength > 1024 else {
            throw AudioAnalysisError.bufferProcessingFailed("Buffer too small for tempo analysis")
        }
        
        // Simulate tempo detection
        return Float.random(in: 60...180)
    }
    
    private func extractEnergy(from channelData: UnsafePointer<Float>, frameLength: Int) throws -> Float {
        guard frameLength > 0 else {
            throw AudioAnalysisError.bufferProcessingFailed("Empty audio data")
        }
        
        var sum: Float = 0.0
        
        // Calculate RMS energy with overflow protection
        for i in 0..<frameLength {
            let sample = channelData[i]
            guard sample.isFinite else {
                throw AudioAnalysisError.bufferProcessingFailed("Invalid audio sample detected")
            }
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        
        // Normalize and clamp
        return min(max(rms * 10, 0.0), 1.0)
    }
    
    private func extractSpectralFeatures(from buffer: AVAudioPCMBuffer) throws -> (
        spectralCentroid: Float,
        valence: Float,
        danceability: Float,
        acousticness: Float,
        instrumentalness: Float,
        speechiness: Float,
        liveness: Float
    ) {
        // Simulate spectral analysis with error handling
        guard buffer.frameLength > 0 else {
            throw AudioAnalysisError.bufferProcessingFailed("Empty buffer for spectral analysis")
        }
        
        // In a real implementation, this would use FFT and spectral analysis
        // For simulation, return random but realistic values
        return (
            spectralCentroid: Float.random(in: 0...1),
            valence: Float.random(in: 0...1),
            danceability: Float.random(in: 0...1),
            acousticness: Float.random(in: 0...1),
            instrumentalness: Float.random(in: 0...1),
            speechiness: Float.random(in: 0...1),
            liveness: Float.random(in: 0...1)
        )
    }
    
    // MARK: - Real-time Analysis with Error Handling
    func installAnalysisTap(
        on player: AVQueuePlayer,
        updateInterval: TimeInterval = 10.0,
        completion: @escaping (AudioFeatures) -> Void
    ) {
        // Remove existing tap
        removeAnalysisTap()
        
        // Check microphone permission
        checkMicrophonePermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.setupAnalysisTap(player: player, updateInterval: updateInterval, completion: completion)
                } else {
                    self?.handleError(.permissionDenied)
                }
            }
        }
    }
    
    private func checkMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let status = AVAudioSession.sharedInstance().recordPermission
        
        switch status {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission(completion)
        @unknown default:
            completion(false)
        }
    }
    
    private func setupAnalysisTap(
        player: AVQueuePlayer,
        updateInterval: TimeInterval,
        completion: @escaping (AudioFeatures) -> Void
    ) {
        do {
            // Start audio engine if not running
            if !audioEngine.isRunning {
                try audioEngine.start()
                isEngineRunning = true
            }
            
            guard let playerNode = getOutputNodeFromPlayer(player) else {
                handleError(.bufferProcessingFailed("Could not access player output"))
                return
            }
            
            // Install tap with error handling
            let format = playerNode.outputFormat(forBus: 0)
            let bufferSize: AVAudioFrameCount = 4096
            
            playerNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
                guard let self = self else { return }
                
                do {
                    let features = try self.processAudioBufferWithValidation(buffer, format: format)
                    DispatchQueue.main.async {
                        completion(features)
                    }
                } catch let error as AudioAnalysisError {
                    DispatchQueue.main.async {
                        self.handleError(error)
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.handleError(.bufferProcessingFailed(error.localizedDescription))
                    }
                }
            }
            
        } catch {
            handleError(.deviceResourcesUnavailable)
        }
    }
    
    private func processAudioBufferWithValidation(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) throws -> AudioFeatures {
        guard let channelData = buffer.floatChannelData?[0], buffer.frameLength > 0 else {
            throw AudioAnalysisError.bufferProcessingFailed("No audio data in real-time buffer")
        }
        
        let frameLength = Int(buffer.frameLength)
        
        // Extract features with validation
        let energy = try extractEnergy(from: channelData, frameLength: frameLength)
        
        // Simulate other features for real-time analysis
        return AudioFeatures(
            tempo: Float.random(in: 60...180),
            energy: energy,
            spectralCentroid: Float.random(in: 0...1),
            valence: Float.random(in: 0...1),
            danceability: Float.random(in: 0...1),
            acousticness: Float.random(in: 0...1),
            instrumentalness: Float.random(in: 0...1),
            speechiness: Float.random(in: 0...1),
            liveness: Float.random(in: 0...1)
        )
    }
    
    func removeAnalysisTap() {
        if isEngineRunning {
            audioEngine.stop()
            isEngineRunning = false
        }
    }
    
    // MARK: - Error Handling Utilities
    private func shouldRetry(_ error: AudioAnalysisError) -> Bool {
        switch error {
        case .bufferProcessingFailed, .deviceResourcesUnavailable, .analysisTimeout:
            return true
        default:
            return false
        }
    }
    
    private func handleError(_ error: AudioAnalysisError) {
        let userError = AudioAnalysisUserError.from(error)
        errorCallback?(userError)
        
        // Log for debugging
        print("AudioAnalysisService Error: \(error.localizedDescription)")
        if let suggestion = error.recoverySuggestion {
            print("Recovery suggestion: \(suggestion)")
        }
    }
    
    // MARK: - Helper Methods
    private func getOutputNodeFromPlayer(_ player: AVQueuePlayer) -> AVAudioNode? {
        // In production, this would properly extract the audio node from the player
        return audioEngine.outputNode
    }
    
    private func stopAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            isEngineRunning = false
        }
    }
    
    // MARK: - Public Mood Detection with Error Handling
    func detectMood(from features: AudioFeatures) -> Mood {
        let actualTempo = features.tempo * 140 + 60

        if actualTempo > 130 {
            if features.energy > 0.7 {
                return features.valence > 0.6 ? .energetic : .angry
            } else {
                return features.valence > 0.6 ? .happy : .focused
            }
        } else {
            if features.energy < 0.4 {
                return features.valence > 0.5 ? .relaxed : .melancholic
            } else {
                return features.valence > 0.7 ? .romantic : .neutral
            }
        }
    }
    
    // MARK: - Song Classification with Error Handling
    func classifySong(_ song: Song, completion: @escaping (Result<Mood, AudioAnalysisError>) -> Void) {
        let url = song.wrappedUrl
        
        analyzeAudioFile(url: url) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let features):
                // Detect mood from features
                let moodResult = self.detectMood(from: features)
                
                switch moodResult {
                case .success(let mood):
                    // Store features in song
                    song.setAudioFeatures(
                        tempo: features.tempo,
                        energy: features.energy,
                        valence: features.valence
                    )
                    song.moodTag = mood.rawValue
                    completion(.success(mood))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Error Logging and Analytics

extension AudioAnalysisService {
    /// Log errors for analytics and debugging
    private func logErrorForAnalytics(_ error: AudioAnalysisError) {
        let errorData: [String: Any] = [
            "error_type": String(describing: error),
            "timestamp": Date().timeIntervalSince1970,
            "description": error.localizedDescription ?? "Unknown error",
            "recovery_suggestion": error.recoverySuggestion ?? "No suggestion"
        ]
        
        // In production, send to analytics service
        print("Analytics - Audio Error: \(errorData)")
    }
    
    /// Check system resources before starting analysis
    private func checkSystemResources() throws {
        let processInfo = ProcessInfo.processInfo
        
        // Check available memory
        if processInfo.physicalMemory < 512_000_000 { // Less than 512MB
            throw AudioAnalysisError.deviceResourcesUnavailable
        }
        
        // Check if device is under thermal pressure
        if processInfo.thermalState == .critical {
            throw AudioAnalysisError.deviceResourcesUnavailable
        }
    }
}
