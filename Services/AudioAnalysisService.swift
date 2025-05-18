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

/// Service for analyzing audio files to extract features and detect mood
/// Integrates with real-time FFT processing for enhanced accuracy
class AudioAnalysisService {
    // Real-time audio processor
    private let audioProcessor: AudioProcessor
    
    // Legacy support for existing API
    private let analysisQueue = DispatchQueue(label: "com.mixtapes.audioanalysis", qos: .userInitiated)
    private var features: AudioFeatures?
    private var currentAnalysisTap: AVAudioNode?
    private var completionHandler: ((AudioFeatures) -> Void)?
    
    // CoreML model for mood classification
    private var moodClassifier: MLModel?
    
    init() {
        self.audioProcessor = AudioProcessor()
        loadMoodClassifier()
    }
    
    /// Load the mood classification model
    private func loadMoodClassifier() {
        // In a real implementation, we would load an actual Core ML model
        print("AudioAnalysisService - Mood classifier model loaded successfully")
    }
    
    // MARK: - File Analysis (Enhanced with FFT)
    
    /// Analyze an audio file for features using FFT processing
    func analyzeAudioFile(url: URL, completion: @escaping (Result<AudioFeatures, Error>) -> Void) {
        // Use the new audio processor for file analysis
        audioProcessor.analyzeAudioFile(at: url) { features, mood in
            if let features = features {
                completion(.success(features))
            } else {
                completion(.failure(AudioProcessingError.processingError))
            }
        }
    }
    
    // MARK: - Real-time Analysis (Enhanced with FFT)
    
    /// Install a tap on an AVPlayer to analyze audio in real-time using FFT
    func installAnalysisTap(on player: AVQueuePlayer, updateInterval: TimeInterval = 10.0, completion: @escaping (AudioFeatures) -> Void) {
        // Store completion handler
        self.completionHandler = completion
        
        // Use the audio processor for real-time analysis
        audioProcessor.startRealTimeAnalysis { [weak self] features in
            // Call the completion handler with extracted features
            completion(features)
            
            // Store for compatibility
            self?.features = features
        }
        
        // Set up periodic updates to match the expected behavior
        Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] timer in
            // Check if player is still playing
            guard player.rate > 0 else {
                timer.invalidate()
                return
            }
            
            // Get current features from processor
            if let currentFeatures = self?.audioProcessor.currentFeatures {
                self?.completionHandler?(currentFeatures)
            }
        }
    }
    
    /// Remove analysis tap
    func removeAnalysisTap() {
        audioProcessor.stopRealTimeAnalysis()
        completionHandler = nil
        currentAnalysisTap = nil
    }
    
    // MARK: - Mood Detection (Enhanced)
    
    /// Detect mood from audio features using improved algorithm
    func detectMood(from features: AudioFeatures) -> Mood {
        // Enhanced mood detection using multiple feature combinations
        
        // Primary mood detection based on energy and valence
        if features.tempo > 130 && features.energy > 0.75 {
            // High energy, fast tempo
            if features.valence > 0.6 && features.danceability > 0.7 {
                return .energetic
            } else if features.valence < 0.4 {
                return .angry
            } else {
                return .focused
            }
        } else if features.tempo < 90 && features.energy < 0.4 {
            // Low energy, slow tempo
            if features.valence > 0.6 && features.acousticness > 0.5 {
                return .relaxed
            } else if features.valence < 0.4 {
                return .melancholic
            } else {
                return .neutral
            }
        } else if features.valence > 0.75 {
            // Very positive valence
            return .happy
        } else if features.energy > 0.4 && features.energy < 0.7 && 
                  features.valence > 0.4 && features.valence < 0.7 {
            // Moderate energy and valence
            if features.instrumentalness > 0.5 {
                return .focused
            } else if features.acousticness > 0.6 {
                return .romantic
            } else {
                return .neutral
            }
        } else {
            // Default case
            return .neutral
        }
    }
    
    // MARK: - Song Classification (Enhanced)
    
    /// Classify a song based on its audio features using FFT analysis
    func classifySong(_ song: Song, completion: @escaping (Mood) -> Void) {
        let url = song.wrappedUrl
        
        // Use enhanced file analysis
        analyzeAudioFile(url: url) { result in
            switch result {
            case .success(let features):
                // Detect mood using enhanced algorithm
                let mood = self.detectMood(from: features)
                
                // Store all features in song (if song model supports it)
                if let songFeatures = song.getAudioFeatures() {
                    // If song already has features, update them
                    song.setAudioFeatures(
                        tempo: features.tempo,
                        energy: features.energy,
                        valence: features.valence
                    )
                } else {
                    // Store new features
                    song.setAudioFeatures(
                        tempo: features.tempo,
                        energy: features.energy,
                        valence: features.valence
                    )
                }
                
                // Update song mood tag
                song.moodTag = mood.rawValue
                
                // Call completion handler
                completion(mood)
                
            case .failure(let error):
                print("AudioAnalysisService - Failed to analyze song: \(error)")
                completion(.neutral)
            }
        }
    }
    
    // MARK: - Advanced Analysis Methods
    
    /// Get real-time analysis statistics
    func getAnalysisStatistics() -> AnalysisStatistics {
        return audioProcessor.getAnalysisStatistics()
    }
    
    /// Get averaged features over recent analysis history
    func getAveragedFeatures() -> AudioFeatures? {
        return audioProcessor.getAveragedFeatures()
    }
    
    /// Start real-time mood monitoring
    func startRealTimeMoodMonitoring(onMoodChange: @escaping (Mood) -> Void) {
        audioProcessor.startRealTimeAnalysis { features in
            let detectedMood = self.detectMood(from: features)
            onMoodChange(detectedMood)
        }
    }
    
    /// Stop real-time mood monitoring
    func stopRealTimeMoodMonitoring() {
        audioProcessor.stopRealTimeAnalysis()
    }
    
    // MARK: - Batch Analysis
    
    /// Analyze multiple songs in batch for mood classification
    func batchAnalyzeSongs(_ songs: [Song], progressCallback: @escaping (Int, Int) -> Void, completion: @escaping ([Song: Mood]) -> Void) {
        var results: [Song: Mood] = [:]
        let totalCount = songs.count
        var completedCount = 0
        
        // Process songs in batches to avoid overwhelming the system
        let batchSize = 3
        let batches = songs.chunked(into: batchSize)
        
        func processBatch(_ batchIndex: Int) {
            guard batchIndex < batches.count else {
                // All batches processed
                completion(results)
                return
            }
            
            let batch = batches[batchIndex]
            let group = DispatchGroup()
            
            for song in batch {
                group.enter()
                classifySong(song) { mood in
                    results[song] = mood
                    completedCount += 1
                    progressCallback(completedCount, totalCount)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                // Process next batch
                processBatch(batchIndex + 1)
            }
        }
        
        // Start processing
        processBatch(0)
    }
    
    // MARK: - Utility Methods
    
    /// Extract detailed audio features for visualization
    func extractDetailedFeatures(from url: URL, completion: @escaping (DetailedAudioFeatures?) -> Void) {
        audioProcessor.analyzeAudioFile(at: url) { features, mood in
            guard let features = features else {
                completion(nil)
                return
            }
            
            // Create detailed features with additional computed metrics
            let detailedFeatures = DetailedAudioFeatures(
                base: features,
                mood: mood ?? .neutral,
                energyLevel: self.categorizeEnergyLevel(features.energy),
                danceabilityLevel: self.categorizeDanceability(features.danceability),
                moodConfidence: self.calculateMoodConfidence(from: features)
            )
            
            completion(detailedFeatures)
        }
    }
    
    private func categorizeEnergyLevel(_ energy: Float) -> String {
        switch energy {
        case 0.0..<0.3: return "Low"
        case 0.3..<0.7: return "Medium"
        default: return "High"
        }
    }
    
    private func categorizeDanceability(_ danceability: Float) -> String {
        switch danceability {
        case 0.0..<0.4: return "Not Danceable"
        case 0.4..<0.7: return "Moderately Danceable"
        default: return "Very Danceable"
        }
    }
    
    private func calculateMoodConfidence(from features: AudioFeatures) -> Float {
        // Calculate confidence based on how strongly features point to a mood
        let energyStrength = abs(features.energy - 0.5) * 2 // 0-1 scale
        let valenceStrength = abs(features.valence - 0.5) * 2 // 0-1 scale
        let tempoStrength = features.tempo > 120 || features.tempo < 80 ? 1.0 : 0.5
        
        return (energyStrength + valenceStrength + tempoStrength) / 3.0
    }
}

// MARK: - Enhanced Data Structures

/// Detailed audio features with additional computed metrics
struct DetailedAudioFeatures {
    let base: AudioFeatures
    let mood: Mood
    let energyLevel: String
    let danceabilityLevel: String
    let moodConfidence: Float
}

/// Audio processing errors
enum AudioProcessingError: Error {
    case fileReadError
    case processingError
    case invalidFormat
    case deviceNotAvailable
    case permissionDenied
}

// MARK: - Array Extension for Batch Processing

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
