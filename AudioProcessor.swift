//
//  AudioProcessor.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import AVFoundation
import CoreML
import Accelerate
import AIMixtapes // Contains SharedTypes

/// Real-time audio processor with FFT analysis and mood detection
class AudioProcessor: ObservableObject {
    // Audio engine components
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let fftProcessor: FFTProcessor
    
    // Buffers and processing
    private var bufferSize: Int
    private var sampleRate: Float
    private let processingQueue = DispatchQueue(label: "AudioProcessing", qos: .userInitiated)
    
    // Configuration
    private var config: AudioProcessingConfiguration
    
    // Feature extraction and analysis
    @Published private(set) var currentFeatures: AudioFeatures?
    @Published private(set) var detectedMood: Mood = .neutral
    @Published private(set) var isAnalyzing: Bool = false
    
    // Buffer management
    private var activeBuffers: Set<AVAudioPCMBuffer> = []
    private let bufferLock = NSLock()
    
    // Analysis state
    private var featureHistory: [AudioFeatures] = []
    private let maxHistorySize = 10
    private var onFeaturesUpdate: ((AudioFeatures) -> Void)?
    
    init() {
        self.inputNode = audioEngine.inputNode
        self.fftProcessor = FFTProcessor(bufferSize: bufferSize, sampleRate: sampleRate)
        setupAudioSession()
    }
    
    deinit {
        stopRealTimeAnalysis()
        cleanupBuffers()
    }
    
    // MARK: - Buffer Management
    
    private func trackBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        activeBuffers.insert(buffer)
    }
    
    private func untrackBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        activeBuffers.remove(buffer)
    }
    
    private func cleanupBuffers() {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        activeBuffers.removeAll()
    }
    
    // MARK: - Audio Processing
    
    func startRealTimeAnalysis(onFeaturesUpdate: @escaping (AudioFeatures) -> Void) {
        self.onFeaturesUpdate = onFeaturesUpdate
        
        guard !audioEngine.isRunning else {
            print("AudioProcessor - Already analyzing")
            return
        }
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: inputFormat) { [weak self] buffer, time in
            self?.trackBuffer(buffer)
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try audioEngine.start()
            DispatchQueue.main.async {
                self.isAnalyzing = true
            }
        } catch {
            print("AudioProcessor - Failed to start audio engine: \(error)")
        }
    }
    
    func stopRealTimeAnalysis() {
        guard audioEngine.isRunning else { return }
        
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        cleanupBuffers()
        
        DispatchQueue.main.async {
            self.isAnalyzing = false
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            defer { self.untrackBuffer(buffer) }
            
            guard let spectralFeatures = self.fftProcessor.processBuffer(buffer) else {
                return
            }
            
            let audioFeatures = self.extractAudioFeatures(from: spectralFeatures)
            self.updateFeatureHistory(audioFeatures)
            
            DispatchQueue.main.async {
                self.currentFeatures = audioFeatures
                self.detectedMood = self.determineCurrentMood(from: audioFeatures)
                self.onFeaturesUpdate?(audioFeatures)
            }
        }
    }
    
    private func extractAudioFeatures(from spectral: SpectralFeatures) -> AudioFeatures {
        // Calculate energy and valence using helper methods
        let energy = calculateEnergy(
            bassEnergy: spectral.bassEnergy,
            midEnergy: spectral.midEnergy,
            trebleEnergy: spectral.trebleEnergy,
            brightness: spectral.brightness
        )
        
        let valence = calculateValence(
            bassEnergy: spectral.bassEnergy,
            midEnergy: spectral.midEnergy,
            trebleEnergy: spectral.trebleEnergy,
            brightness: spectral.brightness
        )
        
        // Calculate danceability
        let danceability = calculateDanceability(
            tempo: spectral.estimatedTempo,
            beatStrength: spectral.beatStrength
        )
        
        // Calculate acousticness
        let acousticness = 1.0 - (spectral.bassEnergy + spectral.trebleEnergy) / 2.0
        
        // Calculate instrumentalness (based on spectral contrast and harmonic ratio)
        let instrumentalness = calculateInstrumentalness(
            spectralContrast: spectral.spectralContrast,
            harmonicRatio: spectral.harmonicRatio
        )
        
        // Calculate speechiness (based on zero crossing rate and spectral flatness)
        let speechiness = calculateSpeechiness(
            zeroCrossingRate: spectral.zeroCrossingRate,
            spectralFlatness: spectral.spectralFlatness
        )
        
        // Calculate liveness (based on dynamic range and spectral flux)
        let liveness = calculateLiveness(
            dynamicRange: spectral.dynamicRange,
            spectralFlux: spectral.spectralFlux
        )
        
        return AudioFeatures(
            tempo: spectral.estimatedTempo,
            energy: energy,
            valence: valence,
            danceability: danceability,
            acousticness: acousticness,
            instrumentalness: instrumentalness,
            speechiness: speechiness,
            liveness: liveness
        )
    }
    
    private func calculateInstrumentalness(spectralContrast: Float, harmonicRatio: Float) -> Float {
        // Higher instrumentalness: High spectral contrast and harmonic ratio
        let contrast = min(1.0, spectralContrast / 20.0)
        let harmonic = min(1.0, harmonicRatio)
        return (contrast * 0.6 + harmonic * 0.4)
    }
    
    private func calculateSpeechiness(zeroCrossingRate: Float, spectralFlatness: Float) -> Float {
        // Higher speechiness: High zero crossing rate and spectral flatness
        let zcr = min(1.0, zeroCrossingRate / 3000.0)
        let flatness = min(1.0, spectralFlatness * 2.0)
        return (zcr * 0.7 + flatness * 0.3)
    }
    
    private func calculateLiveness(dynamicRange: Float, spectralFlux: Float) -> Float {
        // Higher liveness: High dynamic range and spectral flux
        let range = min(1.0, dynamicRange / 60.0)
        let flux = min(1.0, spectralFlux / 10.0)
        return (range * 0.6 + flux * 0.4)
    }
    
    private func calculateValence(bassEnergy: Float, midEnergy: Float, trebleEnergy: Float, brightness: Float) -> Float {
        // Higher valence: More treble and mid energy, moderate brightness
        let energyBalance = (midEnergy + trebleEnergy) / (bassEnergy + 1.0)
        let brightnessContribution = abs(brightness - 0.6) // Optimal brightness around 0.6
        return min(1.0, (energyBalance * 0.7 + (1.0 - brightnessContribution) * 0.3))
    }
    
    private func calculateDanceability(tempo: Float, beatStrength: Float) -> Float {
        // Higher danceability: Strong beats and tempo between 90-130 BPM
        let tempoFactor = 1.0 - abs((tempo - 110.0) / 50.0) // Peak at 110 BPM
        return min(1.0, (beatStrength * 0.7 + tempoFactor * 0.3))
    }
    
    private func calculateLiveness(spectral: SpectralFeatures) -> Float {
        // Higher liveness: More dynamic range and spectral flux
        return min(1.0, (spectral.dynamicRange * 0.5 + spectral.spectralFlux * 0.5) / 20.0)
    }
    
    private func determineCurrentMood(from features: AudioFeatures) -> Mood {
        // Enhanced mood detection using multiple features
        if features.energy > 0.7 && features.tempo > 120 {
            return features.valence > 0.6 ? .energetic : .angry
        } else if features.energy < 0.4 && features.tempo < 100 {
            return features.valence > 0.5 ? .relaxed : .melancholic
        } else if features.valence > 0.7 {
            return .happy
        } else if features.energy > 0.5 && features.valence > 0.4 && features.valence < 0.6 {
            return .focused
        } else if features.energy < 0.6 && features.valence > 0.5 && features.valence < 0.8 {
            return .romantic
        }
        return .neutral
    }
    
    private func updateFeatureHistory(_ features: AudioFeatures) {
        featureHistory.append(features)
        if featureHistory.count > maxHistorySize {
            featureHistory.removeFirst()
        }
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("AudioProcessor - Failed to setup audio session: \(error)")
        }
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
