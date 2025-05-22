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
import Combine
import os.log

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
    case serviceUnavailable
    case maxRetriesExceeded
    case networkUnavailable
    case unknown(Error)
    
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
        case .serviceUnavailable:
            return "Audio analysis service is currently unavailable"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .networkUnavailable:
            return "Network unavailable for analysis"
        case .unknown(let error):
            return "Unknown error occurred: \(error.localizedDescription)"
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
        case .serviceUnavailable:
            return "Try again later."
        case .maxRetriesExceeded:
            return "Please try again later."
        case .networkUnavailable:
            return "Check your network connection and try again."
        case .unknown:
            return "Please try again."
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
    
    mutating func updateWith(rms: Float) {
        // Update features with new data
    }
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
class AudioAnalysisService: ObservableObject {
    // MARK: - Properties
    
    @Published private(set) var isAnalyzing = false
    @Published private(set) var progress: Double = 0
    private let audioQueue = DispatchQueue(label: "com.aimixtapes.audioanalysis", qos: .userInitiated)
    private let analysisBufferSize = 4096
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var analysisCancel: AnyCancellable?
    private let logger = Logger(subsystem: "com.aimixtapes", category: "AudioAnalysis")
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    
    // Performance monitoring
    private var performanceMetrics = PerformanceMetrics()
    
    // MARK: - Public Interface
    
    /// Analyze audio file with robust error handling and progress updates
    /// - Parameters:
    ///   - url: URL of the audio file
    ///   - options: Analysis options
    /// - Returns: Publisher with analysis results or error
    func analyzeAudio(at url: URL, options: AnalysisOptions = .default) -> AnyPublisher<AudioFeatures, Error> {
        Deferred {
            Future { [weak self] promise in
                guard let self = self else {
                    promise(.failure(AudioAnalysisError.serviceUnavailable))
                    return
                }
                
                self.audioQueue.async {
                    self.performAnalysis(url: url, options: options, promise: promise)
                }
            }
        }
        .handleEvents(
            receiveSubscription: { [weak self] _ in
                self?.isAnalyzing = true
            },
            receiveCompletion: { [weak self] _ in
                self?.isAnalyzing = false
                self?.cleanup()
            },
            receiveCancel: { [weak self] in
                self?.cancelAnalysis()
            }
        )
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Private Implementation
    
    private func performAnalysis(url: URL, options: AnalysisOptions, promise: @escaping (Result<AudioFeatures, Error>) -> Void) {
        var retryCount = 0
        
        func retry() {
            guard retryCount < maxRetries else {
                promise(.failure(AudioAnalysisError.maxRetriesExceeded))
                return
            }
            
            retryCount += 1
            logger.info("Retrying analysis (attempt \(retryCount)/\(maxRetries))")
            
            DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) {
                self.performAnalysis(url: url, options: options, promise: promise)
            }
        }
        
        do {
            // Setup audio session
            try setupAudioSession()
            
            // Load and validate audio file
            guard let audioFile = try? loadAudioFile(url: url) else {
                throw AudioAnalysisError.fileNotFound(url)
            }
            
            // Process audio in chunks
            let features = try processAudioChunks(audioFile: audioFile, options: options)
            
            // Log success metrics
            logSuccessMetrics(audioFile: audioFile)
            
            promise(.success(features))
        } catch let error as AudioAnalysisError {
            handleAnalysisError(error, retryBlock: retry, promise: promise)
        } catch {
            promise(.failure(AudioAnalysisError.unknown(error)))
        }
    }
    
    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }
    
    private func loadAudioFile(url: URL) throws -> AVAudioFile {
        guard let file = try? AVAudioFile(forReading: url) else {
            throw AudioAnalysisError.fileNotFound(url)
        }
        return file
    }
    
    private func processAudioChunks(audioFile: AVAudioFile, options: AnalysisOptions) throws -> AudioFeatures {
        var features = AudioFeatures()
        let format = audioFile.processingFormat
        let channelCount = format.channelCount
        
        // Configure buffer
        let bufferSize = AVAudioFrameCount(analysisBufferSize)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize)!
        
        var totalFrames: AVAudioFrameCount = 0
        let frameCount = audioFile.length
        
        while totalFrames < frameCount {
            try autoreleasepool {
                // Read chunk
                try audioFile.read(into: buffer)
                
                // Process chunk
                if let channelData = buffer.floatChannelData {
                    processAudioData(channelData, channelCount: channelCount, frameLength: buffer.frameLength, features: &features)
                }
                
                totalFrames += buffer.frameLength
                updateProgress(Double(totalFrames) / Double(frameCount))
            }
        }
        
        return features
    }
    
    private func processAudioData(_ channelData: UnsafePointer<UnsafeMutablePointer<Float>>, channelCount: AVAudioChannelCount, frameLength: AVAudioFrameCount, features: inout AudioFeatures) {
        // Process audio data using vDSP
        var rms: Float = 0
        vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(frameLength))
        
        // Update features
        features.updateWith(rms: rms)
    }
    
    private func updateProgress(_ progress: Double) {
        DispatchQueue.main.async {
            self.progress = min(max(progress, 0), 1)
        }
    }
    
    private func cancelAnalysis() {
        audioQueue.async { [weak self] in
            self?.cleanup()
        }
    }
    
    private func cleanup() {
        audioFile = nil
        audioEngine?.stop()
        audioEngine = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Handling
    
    private func handleAnalysisError(_ error: AudioAnalysisError, retryBlock: @escaping () -> Void, promise: @escaping (Result<AudioFeatures, Error>) -> Void) {
        logger.error("Audio analysis error: \(error.localizedDescription)")
        
        switch error {
        case .deviceResourcesUnavailable, .networkUnavailable:
            retryBlock()
        default:
            promise(.failure(error))
        }
    }
    
    private func logSuccessMetrics(audioFile: AVAudioFile) {
        performanceMetrics.recordAnalysis(
            duration: audioFile.duration,
            format: audioFile.processingFormat.description
        )
    }
}

// MARK: - Supporting Types

struct AnalysisOptions: OptionSet {
    let rawValue: Int
    
    static let spectralAnalysis = AnalysisOptions(rawValue: 1 << 0)
    static let tempoAnalysis = AnalysisOptions(rawValue: 1 << 1)
    static let pitchAnalysis = AnalysisOptions(rawValue: 1 << 2)
    
    static let `default`: AnalysisOptions = [.spectralAnalysis, .tempoAnalysis]
}

struct PerformanceMetrics {
    private(set) var analysisCount = 0
    private(set) var totalDuration: TimeInterval = 0
    private(set) var averageProcessingTime: TimeInterval = 0
    
    mutating func recordAnalysis(duration: TimeInterval, format: String) {
        analysisCount += 1
        totalDuration += duration
        // Update metrics
    }
}

// MARK: - AVAudioFile Extension

extension AVAudioFile {
    var duration: TimeInterval {
        Double(length) / processingFormat.sampleRate
    }
}
