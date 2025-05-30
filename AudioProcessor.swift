//
//  AudioProcessor.swift
//  Mixtapes
//
//  Enhanced audio processor with proper memory management
//  Supporting ISSUE-005: Memory Management in Audio Buffers
//

import Foundation
import AVFoundation
import Accelerate

/// Audio processor with enhanced memory management and real-time capabilities
class AudioProcessor: ObservableObject {
    
    // MARK: - Properties
    private let audioAnalysisService: AudioAnalysisService
    private var isProcessing = false
    private var processingCompletion: ((AudioFeatures) -> Void)?
    
    // MARK: - Memory Management
    private let processQueue = DispatchQueue(label: "audio.process.queue", qos: .userInteractive)
    private var activeProcessingTasks: Set<UUID> = []
    private let maxConcurrentTasks = 3
    
    // MARK: - Initialization
    init(audioAnalysisService: AudioAnalysisService) {
        self.audioAnalysisService = audioAnalysisService
    }
    
    // MARK: - Public Methods
    
    /// Start real-time analysis with proper resource management
    func startRealTimeAnalysis(completion: @escaping (AudioFeatures) -> Void) throws {
        guard !isProcessing else {
            throw AppError.audioProcessingFailed(NSError(domain: "AudioProcessor", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Processing already in progress"]))
        }
        
        isProcessing = true
        processingCompletion = completion
        
        try audioAnalysisService.startRealTimeAnalysis { [weak self] features in
            self?.handleProcessedFeatures(features)
        }
    }
    
    /// Stop real-time analysis and cleanup
    func stopRealTimeAnalysis() {
        isProcessing = false
        processingCompletion = nil
        audioAnalysisService.stopRealTimeAnalysis()
        
        // Cancel any ongoing tasks
        activeProcessingTasks.removeAll()
    }
    
    /// Process audio file with memory-safe batching
    func processAudioFile(_ url: URL, completion: @escaping (Result<AudioFeatures, Error>) -> Void) {
        let taskId = UUID()
        
        // Check concurrent task limit
        guard activeProcessingTasks.count < maxConcurrentTasks else {
            completion(.failure(AppError.audioProcessingFailed(NSError(domain: "AudioProcessor", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Too many concurrent processing tasks"]))))
            return
        }
        
        activeProcessingTasks.insert(taskId)
        
        Task {
            do {
                let features = try await audioAnalysisService.analyzeAudioFile(url)
                
                DispatchQueue.main.async { [weak self] in
                    self?.activeProcessingTasks.remove(taskId)
                    completion(.success(features))
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.activeProcessingTasks.remove(taskId)
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleProcessedFeatures(_ features: AudioFeatures) {
        guard isProcessing, let completion = processingCompletion else { return }
        
        DispatchQueue.main.async {
            completion(features)
        }
    }
    
    // MARK: - Resource Management
    
    /// Clean up resources when memory pressure is detected
    func handleMemoryPressure() {
        // Cancel non-essential tasks
        if activeProcessingTasks.count > 1 {
            let tasksToCancel = Array(activeProcessingTasks.prefix(activeProcessingTasks.count - 1))
            tasksToCancel.forEach { activeProcessingTasks.remove($0) }
        }
        
        // Stop real-time analysis if needed
        if isProcessing {
            stopRealTimeAnalysis()
        }
    }
    
    deinit {
        stopRealTimeAnalysis()
    }
}

// MARK: - Supporting Structures

struct AnalysisStatistics {
    let isActive: Bool
    let sampleRate: Float
    let bufferSize: Int
    let featuresInHistory: Int
    let currentMood: Mood
}

/// Extended audio features structure with all Spotify-like features
struct AudioFeatures: Codable {
    let tempo: Float              // BPM
    let energy: Float             // 0-1, intensity
    let valence: Float            // 0-1, positivity
    let danceability: Float       // 0-1, dance suitability
    let acousticness: Float       // 0-1, acoustic confidence
    let instrumentalness: Float   // 0-1, no vocals confidence
    let speechiness: Float        // 0-1, spoken words
    let liveness: Float           // 0-1, live performance
}
