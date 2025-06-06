//
//  AudioAnalysisService.swift
//  Mixtapes
//
//  Enhanced with proper memory management for audio buffers
//  Fixes ISSUE-005: Memory Management in Audio Buffers
//

import Foundation
import AVFoundation
import Accelerate
import CoreML
import Combine
import os.log
import Domain
import SwiftUI
import os.signpost

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

// We don't need a legacy model anymore, using the proper AudioFeatures model instead

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

/// Enhanced audio analysis service with proper memory management
class AudioAnalysisService: ObservableObject {
    // Performance monitoring
    private let signposter = OSSignposter(subsystem: "com.aimixtapes", category: "AudioAnalysis")
    private static let audioProcessingInterval = OSSignpostInterval(name: "Audio Processing")
    private static let fftInterval = OSSignpostInterval(name: "FFT Analysis")
    private static let bufferInterval = OSSignpostInterval(name: "Buffer Management")
    
    // High-priority audio queue
    private let realTimeQueue = DispatchQueue(label: "com.aimixtapes.realtime",
                                            qos: .userInteractive,
                                            attributes: .concurrent)
    
    // MARK: - Properties
    
    @Published private(set) var isAnalyzing = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var currentFeatures: AudioFeatures?
    @Published private(set) var analysisHistory: [URL: AudioFeatures] = [:]
    @Published private(set) var performanceReport: String = ""
    
    private let audioQueue = DispatchQueue(label: "com.aimixtapes.audioanalysis", qos: .userInitiated)
    private let analysisBufferSize = 4096
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var analysisCancel: AnyCancellable?
    private let logger = Logger(subsystem: "com.aimixtapes", category: "AudioAnalysis")
    
    // MARK: - Audio Engine Components
    private let audioPlayerNode = AVAudioPlayerNode()
    private var audioTap: AVAudioNodeTap?
    
    // MARK: - Buffer Management
    private var audioBufferPool: AudioBufferPool
    private let bufferQueue = DispatchQueue(label: "audio.buffer.queue", qos: .userInteractive)
    private let analysisQueue = DispatchQueue(label: "audio.analysis.queue", qos: .utility)
    
    // MARK: - Memory Management
    private var isProcessing = false
    
    // MARK: - Configuration
    private let sampleRate: Double = 44100.0
    private let bufferSize: UInt32 = 1024
    private let maxBuffersInPool: Int = 10
    
    // MARK: - Publishers
    private let featuresSubject = PassthroughSubject<AudioFeatures, Never>()
    var featuresPublisher: AnyPublisher<AudioFeatures, Never> {
        featuresSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    init() {
        self.audioBufferPool = AudioBufferPool(maxBuffers: maxBuffersInPool, bufferSize: bufferSize)
        setupAudioEngine()
    }
    
    deinit {
        cleanup()
    }
    
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
                self?.progress = 0
            },
            receiveCompletion: { [weak self] _ in
                self?.isAnalyzing = false
                self?.cleanup()
                self?.updatePerformanceReport()
            },
            receiveCancel: { [weak self] in
                self?.cancelAnalysis()
            }
        )
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    /// Analyze a short audio segment for real-time processing
    /// - Parameter buffer: Audio buffer to analyze
    /// - Returns: Extracted audio features
    func analyzeAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AudioFeatures? {
        guard !isAnalyzing else { return nil }
        
        // Process with FFT
        guard let spectralFeatures = fftProcessor.analyzeSpectralFeatures(buffer) else {
            return nil
        }
        
        // Create audio features from spectral features
        let features = AudioFeatures.from(spectralFeatures: spectralFeatures)
        
        // Update current features
        DispatchQueue.main.async {
            self.currentFeatures = features
        }
        
        return features
    }
    
    /// Cancels any ongoing analysis
    func cancelCurrentAnalysis() {
        cancelAnalysis()
    }
    
    /// Returns performance statistics
    func getPerformanceStatistics() -> String {
        return performanceMetrics.generateReport()
    }
    
    /// Start real-time audio analysis with proper buffer management
    /// - Parameter completion: Closure to receive analyzed audio features
    /// - Throws: AudioAnalysisError if analysis cannot be started
    func startRealTimeAnalysis(completion: @escaping (AudioFeatures) -> Void) throws {
        guard !isAnalyzing else {
            throw AudioAnalysisError.serviceUnavailable
        }
        
        isAnalyzing = true
        isProcessing = true
        
        // Setup audio tap with managed buffers
        try setupAudioTap { [weak self] features in
            DispatchQueue.main.async {
                self?.currentFeatures = features
                self?.featuresSubject.send(features)
                completion(features)
            }
        }
        
        // Start audio engine
        try audioEngine.start()
        audioPlayerNode.play()
    }
    
    /// Stop real-time analysis and cleanup resources
    func stopRealTimeAnalysis() {
        isAnalyzing = false
        isProcessing = false
        
        // Stop audio engine
        audioPlayerNode.stop()
        audioEngine.stop()
        
        // Remove audio tap and cleanup buffers
        removeAudioTap()
        
        // Clean up buffer pool
        audioBufferPool.releaseAllBuffers()
    }
    
    /// Analyze a specific audio file with memory-safe processing
    /// - Parameter url: URL of the audio file
    /// - Returns: Extracted audio features
    /// - Throws: AudioAnalysisError if analysis fails
    func analyzeAudioFile(_ url: URL) async throws -> AudioFeatures {
        return try await withCheckedThrowingContinuation { continuation in
            analysisQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: AudioAnalysisError.serviceUnavailable)
                    return
                }
                
                do {
                    let audioFile = try AVAudioFile(forReading: url)
                    let features = try self.extractFeaturesFromFile(audioFile)
                    continuation.resume(returning: features)
                } catch {
                    continuation.resume(throwing: AudioAnalysisError.unknown(error))
                }
            }
        }
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
            // Check if we already have processed this file
            if let cachedFeatures = analysisHistory[url] {
                logger.info("Using cached analysis for \(url.lastPathComponent)")
                promise(.success(cachedFeatures))
                return
            }
            
            // Setup audio session
            try setupAudioSession()
            
            // Load and validate audio file
            guard let audioFile = try? loadAudioFile(url: url) else {
                throw AudioAnalysisError.fileNotFound(url)
            }
            
            // Process audio in chunks
            let features = try processAudioChunks(audioFile: audioFile, options: options)
            
            // Cache the results
            DispatchQueue.main.async {
                self.analysisHistory[url] = features
                self.currentFeatures = features
            }
            
            // Log success metrics
            let processingTime = processStartTime != nil ? Date().timeIntervalSince(processStartTime!) : 0
            logSuccessMetrics(audioFile: audioFile, processingTime: processingTime)
            
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
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioAnalysisError.fileNotFound(url)
        }
        
        guard let file = try? AVAudioFile(forReading: url) else {
            throw AudioAnalysisError.invalidAudioFormat("Could not read audio file format")
        }
        
        self.audioFile = file
        return file
    }
    
    private func extractFeaturesFromBuffer(_ buffer: AVAudioPCMBuffer) -> AudioFeatures {
        guard let channelData = buffer.floatChannelData?[0] else {
            return AudioFeatures()
        }
        
        // Get spectral features using FFT with memory safety
        guard let spectralFeatures = fftProcessor.analyzeSpectralFeatures(buffer) else {
            return AudioFeatures()
        }
        
        autoreleasepool {
            // Calculate RMS energy with high-precision vDSP
            var rms: Float = 0
            vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(buffer.frameLength))
            
            // Calculate peak and dynamic range
            var peak: Float = 0
            vDSP_maxv(channelData, 1, &peak, vDSP_Length(buffer.frameLength))
            let dynamicRange = 20 * log10f(peak / (rms + Float.ulpOfOne))
            
            // Calculate zero-crossing rate
            var zeroCrossings: Float = 0
            var prevSample: Float = 0
            for i in 0..<Int(buffer.frameLength) {
                if (channelData[i] * prevSample) < 0 {
                    zeroCrossings += 1
                }
                prevSample = channelData[i]
            }
            let zcr = zeroCrossings / Float(buffer.frameLength)
            
            // Calculate energy distribution features
            let bandEnergies = calculateBandEnergies(channelData, frameCount: Int(buffer.frameLength))
            
            // Create AudioFeatures with real DSP calculations
            var features = AudioFeatures()
            
            // Core features
            features.rms = rms
            features.peakAmplitude = peak
            features.zeroCrossingRate = zcr
            features.crest = peak / (rms + Float.ulpOfOne)
            
            // Spectral features
            features.spectralCentroid = spectralFeatures.centroid
            features.spectralRolloff = spectralFeatures.rolloff
            features.spectralFlatness = spectralFeatures.flatness
            features.spectralSpread = spectralFeatures.spread
            features.spectralFlux = spectralFeatures.flux
            features.harmonicRatio = spectralFeatures.harmonicRatio
            
            // Energy features
            features.bassEnergy = bandEnergies.bass
            features.midEnergy = bandEnergies.mid
            features.trebleEnergy = bandEnergies.treble
            features.subBandEnergies = bandEnergies.subBands
            
            // High-level features
            features.energy = calculatePerceptualEnergy(rms: rms, spectralFeatures: spectralFeatures)
            features.valence = calculateValence(spectralFeatures: spectralFeatures)
            features.danceability = calculateDanceability(
                zcr: zcr,
                spectralFeatures: spectralFeatures,
                energy: features.energy
            )
            features.acousticness = calculateAcousticness(
                centroid: spectralFeatures.centroid,
                spread: spectralFeatures.spread,
                flatness: spectralFeatures.flatness
            )
            
            return features
        }
    }
    
    private func calculateBandEnergies(_ samples: UnsafePointer<Float>, frameCount: Int) -> (bass: Float, mid: Float, treble: Float, subBands: [Float]) {
        // Configure frequency bands (Hz)
        let bassRange = (20.0, 250.0)
        let midRange = (250.0, 4000.0)
        let trebleRange = (4000.0, 20000.0)
        
        // Get magnitude spectrum using vDSP
        var magnitudes = [Float](repeating: 0, count: frameCount/2)
        var window = [Float](repeating: 0, count: frameCount)
        vDSP_hann_window(&window, vDSP_Length(frameCount), Int32(0))
        
        var realp = [Float](repeating: 0, count: frameCount/2)
        var imagp = [Float](repeating: 0, count: frameCount/2)
        
        // Apply window and calculate spectrum
        var windowedSamples = [Float](repeating: 0, count: frameCount)
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(frameCount))
        
        // Perform FFT
        let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Double(frameCount))), FFTRadix(kFFTRadix2))!
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
        windowedSamples.withUnsafeBytes { ptr in
            let typePtr = ptr.bindMemory(to: DSPComplex.self)
            vDSP_ctoz(typePtr.baseAddress!, 2, &splitComplex, 1, vDSP_Length(frameCount/2))
        }
        
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Double(frameCount))), FFTDirection(FFT_FORWARD))
        
        // Calculate magnitude spectrum
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(frameCount/2))
        
        // Calculate band energies
        let freqResolution = 44100.0 / Double(frameCount)
        var bassEnergy: Float = 0
        var midEnergy: Float = 0
        var trebleEnergy: Float = 0
        
        // Split into sub-bands for detailed analysis
        let subBandCount = 8
        var subBandEnergies = [Float](repeating: 0, count: subBandCount)
        
        for i in 0..<frameCount/2 {
            let frequency = Double(i) * freqResolution
            let magnitude = magnitudes[i]
            
            // Accumulate band energies
            if frequency >= bassRange.0 && frequency < bassRange.1 {
                bassEnergy += magnitude
            } else if frequency >= midRange.0 && frequency < midRange.1 {
                midEnergy += magnitude
            } else if frequency >= trebleRange.0 && frequency < trebleRange.1 {
                trebleEnergy += magnitude
            }
            
            // Calculate sub-band energies
            let subBandIndex = Int((frequency / 22050.0) * Double(subBandCount))
            if subBandIndex < subBandCount {
                subBandEnergies[subBandIndex] += magnitude
            }
        }
        
        // Normalize energies
        let totalEnergy = bassEnergy + midEnergy + trebleEnergy
        if totalEnergy > 0 {
            bassEnergy /= totalEnergy
            midEnergy /= totalEnergy
            trebleEnergy /= totalEnergy
            
            // Normalize sub-bands
            for i in 0..<subBandCount {
                subBandEnergies[i] /= totalEnergy
            }
        }
        
        return (bass: bassEnergy, mid: midEnergy, treble: trebleEnergy, subBands: subBandEnergies)
    }
    
    private func calculatePerceptualEnergy(rms: Float, spectralFeatures: SpectralFeatures) -> Float {
        // Combine RMS energy with spectral features for perceptual energy
        let spectralWeight = 0.7
        let rmsWeight = 0.3
        
        let spectralEnergy = (spectralFeatures.bassEnergy * 1.2 +  // Bass emphasis
                             spectralFeatures.midEnergy * 1.0 +     // Mid balanced
                             spectralFeatures.trebleEnergy * 0.8)   // Treble de-emphasis
        
        return (spectralWeight * spectralEnergy + rmsWeight * rms)
            .clamped(to: 0...1)
    }
    
    private func calculateValence(spectralFeatures: SpectralFeatures) -> Float {
        // Calculate emotional valence based on spectral features
        let brightness = spectralFeatures.brightness
        let harmonicRatio = spectralFeatures.harmonicRatio ?? 0
        let spectralContrast = spectralFeatures.spectralContrast ?? 0
        
        // Bright, harmonic content tends to indicate positive valence
        let brightnessWeight = 0.4
        let harmonicWeight = 0.35
        let contrastWeight = 0.25
        
        let valence = brightnessWeight * brightness +
                      harmonicWeight * harmonicRatio +
                      contrastWeight * spectralContrast
        
        return valence.clamped(to: 0...1)
    }
    
    private func calculateDanceability(zcr: Float, spectralFeatures: SpectralFeatures, energy: Float) -> Float {
        // Calculate danceability based on rhythm and spectral features
        let rhythmStrength = 1.0 - zcr                  // Lower ZCR often indicates stronger rhythm
        let spectralFlux = spectralFeatures.flux        // Changes in spectrum indicate rhythm
        let beatEnergy = energy                         // Overall energy level
        
        let fluxWeight = 0.4
        let rhythmWeight = 0.35
        let energyWeight = 0.25
        
        let danceability = fluxWeight * spectralFlux +
                          rhythmWeight * rhythmStrength +
                          energyWeight * beatEnergy
        
        return danceability.clamped(to: 0...1)
    }
    
    private func calculateAcousticness(centroid: Float, spread: Float, flatness: Float) -> Float {
        // Calculate acousticness based on spectral shape
        // Acoustic sounds tend to have lower centroid and more varied spectrum
        
        // Normalize features to 0-1 range
        let normalizedCentroid = (centroid / 10000.0).clamped(to: 0...1)  // Typical range 0-10kHz
        let normalizedSpread = (spread / 5000.0).clamped(to: 0...1)       // Typical range 0-5kHz
        let normalizedFlatness = flatness                                  // Already 0-1
        
        // Acoustic sounds tend to have:
        // - Lower spectral centroid (more energy in lower frequencies)
        // - Higher spectral spread (more varied frequency content)
        // - Lower spectral flatness (more peaks and valleys in spectrum)
        
        let centroidWeight = 0.4
        let spreadWeight = 0.3
        let flatnessWeight = 0.3
        
        let acousticness = centroidWeight * (1.0 - normalizedCentroid) +  // Invert centroid
                          spreadWeight * normalizedSpread +
                          flatnessWeight * (1.0 - normalizedFlatness)     // Invert flatness
        
        return acousticness.clamped(to: 0...1)
    }
}

extension Array where Element == Int {
    var mostCommon: Element? {
        var counts = [Element: Int]()
        self.forEach { counts[$0, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Supporting Types

struct AnalysisOptions: OptionSet {
    let rawValue: Int
    
    static let spectralAnalysis = AnalysisOptions(rawValue: 1 << 0)
    static let tempoAnalysis = AnalysisOptions(rawValue: 1 << 1)
    static let pitchAnalysis = AnalysisOptions(rawValue: 1 << 2)
    static let loudnessAnalysis = AnalysisOptions(rawValue: 1 << 3)
    static let rhythmAnalysis = AnalysisOptions(rawValue: 1 << 4)
    static let moodAnalysis = AnalysisOptions(rawValue: 1 << 5)
    static let genreAnalysis = AnalysisOptions(rawValue: 1 << 6)
    static let harmonicAnalysis = AnalysisOptions(rawValue: 1 << 7)
    static let cachingEnabled = AnalysisOptions(rawValue: 1 << 8)
    static let highPrecision = AnalysisOptions(rawValue: 1 << 9)
    static let lowLatency = AnalysisOptions(rawValue: 1 << 10)
    
    static let quick: AnalysisOptions = [.spectralAnalysis, .loudnessAnalysis]
    static let standard: AnalysisOptions = [.spectralAnalysis, .tempoAnalysis, .loudnessAnalysis, .rhythmAnalysis, .cachingEnabled]
    static let comprehensive: AnalysisOptions = [.spectralAnalysis, .tempoAnalysis, .pitchAnalysis, .loudnessAnalysis, .rhythmAnalysis, .moodAnalysis, .harmonicAnalysis, .cachingEnabled, .highPrecision]
    
    static let `default`: AnalysisOptions = .standard
}

struct PerformanceMetrics {
    private(set) var analysisCount = 0
    private(set) var totalDuration: TimeInterval = 0
    private(set) var averageProcessingTime: TimeInterval = 0
    private(set) var memoryUsage: Int = 0
    private(set) var cpuLoad: Double = 0
    private(set) var peakMemoryUsage: Int = 0
    private var processingTimes: [TimeInterval] = []
    private let maxHistoryEntries = 20
    
    mutating func recordAnalysis(duration: TimeInterval, format: String, processingTime: TimeInterval = 0, memoryUsed: Int = 0) {
        analysisCount += 1
        totalDuration += duration
        
        // Update processing times history
        processingTimes.append(processingTime)
        if processingTimes.count > maxHistoryEntries {
            processingTimes.removeFirst()
        }
        
        // Calculate average processing time
        let total = processingTimes.reduce(0, +)
        averageProcessingTime = processingTimes.isEmpty ? 0 : total / Double(processingTimes.count)
        
        // Update memory metrics
        memoryUsage = memoryUsed
        peakMemoryUsage = max(peakMemoryUsage, memoryUsed)
        
        // Estimate CPU load based on processing time relative to audio duration
        if duration > 0 {
            cpuLoad = min(1.0, processingTime / duration)
        }
    }
    
    var isProcessingEfficient: Bool {
        return averageProcessingTime < 0.1 && cpuLoad < 0.5
    }
    
    func generateReport() -> String {
        return """
        Analysis Report:
        - Total files processed: \(analysisCount)
        - Total audio duration: \(String(format: "%.2f", totalDuration))s
        - Average processing time: \(String(format: "%.3f", averageProcessingTime))s
        - Current memory usage: \(memoryUsage / 1024) KB
        - Peak memory usage: \(peakMemoryUsage / 1024) KB
        - Estimated CPU load: \(String(format: "%.1f", cpuLoad * 100))%
        - Processing efficiency: \(isProcessingEfficient ? "Good" : "Needs optimization")
        """
    }
}

// MARK: - AVAudioFile Extension

extension AVAudioFile {
    var duration: TimeInterval {
        Double(length) / processingFormat.sampleRate
    }
}

// MARK: - AudioFeatures Extensions
extension AudioFeatures {
    /// Create AudioFeatures from SpectralFeatures
    static func from(spectralFeatures: SpectralFeatures) -> AudioFeatures {
        var features = AudioFeatures()
        
        // Copy spectral features to create a new instance
        features.spectralFeatures = spectralFeatures
        
        // Set band energies and other metrics based on spectral features
        features.energy = (spectralFeatures.bassEnergy + spectralFeatures.midEnergy + spectralFeatures.trebleEnergy) / 3.0
        features.valence = spectralFeatures.brightness * 0.5 + 0.25 // Default estimate
        features.tempo = spectralFeatures.estimatedTempo > 0 ? spectralFeatures.estimatedTempo : 120.0 // Default tempo
        features.danceability = min(1.0, spectralFeatures.flux * 2.0)
        features.acousticness = 1.0 - spectralFeatures.brightness
        
        return features
    }
    
    // Properties to match with SpectralFeatures structure to make the code cleaner
    var spectralCentroid: Float {
        get { spectralFeatures?.centroid ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.centroid = newValue 
        }
    }
    
    var spectralSpread: Float {
        get { spectralFeatures?.spread ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.spread = newValue 
        }
    }
    
    var spectralRolloff: Float {
        get { spectralFeatures?.rolloff ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.rolloff = newValue 
        }
    }
    
    var spectralFlux: Float {
        get { spectralFeatures?.flux ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.flux = newValue 
        }
    }
    
    var bassEnergy: Float {
        get { spectralFeatures?.bassEnergy ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.bassEnergy = newValue 
        }
    }
    
    var midEnergy: Float {
        get { spectralFeatures?.midEnergy ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.midEnergy = newValue 
        }
    }
    
    var trebleEnergy: Float {
        get { spectralFeatures?.trebleEnergy ?? 0 }
        set { 
            if spectralFeatures == nil {
                spectralFeatures = SpectralFeatures()
            }
            spectralFeatures?.trebleEnergy = newValue 
        }
    }
}

private func cleanupBuffers() {
    audioBufferPool.releaseAllBuffers()
}

private func getOrCreateBuffer(with format: AVAudioFormat, frameCapacity: AVAudioFrameCount) -> AVAudioPCMBuffer {
    if let buffer = audioBufferPool.obtainBuffer() {
        if buffer.format == format && buffer.frameCapacity >= frameCapacity {
            return buffer
        }
        audioBufferPool.returnBuffer(buffer)
    }
    
    // Create new buffer if none available
    return AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity)!
}

private func trackBuffer(_ buffer: AVAudioPCMBuffer) {
    bufferQueue.async {
        self.audioBufferPool.trackBuffer(buffer)
    }
}

private func untrackBuffer(_ buffer: AVAudioPCMBuffer) {
    bufferQueue.async {
        self.audioBufferPool.untrackBuffer(buffer)
    }
}

private func returnBufferToPool(_ buffer: AVAudioPCMBuffer) {
    audioBufferPool.returnBuffer(buffer)
}

private func cleanup() {
    cancelAnalysis()
    cleanupBuffers()
    audioFile = nil
    currentFeatures = nil
    progress = 0
    isAnalyzing = false
    
    // Release audio engine resources
    audioPlayerNode.stop()
    removeAudioTap()
    audioEngine.stop()
    
    do {
        try AVAudioSession.sharedInstance().setActive(false)
    } catch {
        logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
    }
}

private func cancelAnalysis() {
    analysisCancel?.cancel()
    analysisCancel = nil
    cleanup()
}

// MARK: - Performance Monitoring

private func updatePerformanceReport() {
    let report = """
    Audio Analysis Performance:
    - Memory Usage: \(String(format: "%.1f", Double(audioBufferPool.totalBufferMemory) / 1024 / 1024))MB
    - Active Buffers: \(audioBufferPool.activeBufferCount)
    - Peak Buffer Usage: \(audioBufferPool.peakBufferCount)
    - Processing Time: \(String(format: "%.2f", processStartTime != nil ? Date().timeIntervalSince(processStartTime!) : 0))s
    - Buffer Pool Size: \(audioBufferPool.currentPoolSize)/\(maxBuffersInPool)
    """
    
    logger.info("\(report)")
}

private func handleAnalysisError(_ error: AudioAnalysisError, retryBlock: @escaping () -> Void, promise: @escaping (Result<AudioFeatures, Error>) -> Void) {
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        
        self.isAnalyzing = false
        self.progress = 0
        
        // Log error details
        logger.error("Analysis failed: \(error.localizedDescription)")
        
        // Handle specific errors
        switch error {
        case .deviceResourcesUnavailable:
            // Device is low on resources - cleanup and retry
            self.cleanup()
            self.audioBufferPool.reducePoolSize()
            retryBlock()
            
        case .bufferProcessingFailed(let reason):
            // Buffer processing error - attempt recovery
            logger.error("Buffer processing failed: \(reason)")
            self.cleanupBuffers()
            retryBlock()
            
        case .analysisTimeout:
            // Save progress and allow resume
            self.saveAnalysisState()
            promise(.failure(error))
            
        case .insufficientAudioData:
            // Not enough audio data to analyze
            promise(.failure(error))
            
        case .permissionDenied:
            // Audio permission issues
            self.requestAudioPermissions { granted in
                if granted {
                    retryBlock()
                } else {
                    promise(.failure(error))
                }
            }
            
        default:
            // Unrecoverable error
            promise(.failure(error))
        }
        
        self.updatePerformanceReport()
    }
}

private func saveAnalysisState() {
    stateQueue.async { [weak self] in
        guard let self = self else { return }
        
        let state = AnalysisState(
            progress: self.progress,
            currentFeatures: self.currentFeatures,
            timestamp: Date()
        )
        
        UserDefaults.standard.set(try? JSONEncoder().encode(state), forKey: stateKey)
    }
}

private func loadAnalysisState() -> AnalysisState? {
    guard let data = UserDefaults.standard.data(forKey: stateKey),
          let state = try? JSONDecoder().decode(AnalysisState.self, from: data) else {
        return nil
    }
    return state
}

private func requestAudioPermissions(completion: @escaping (Bool) -> Void) {
    AVAudioSession.sharedInstance().requestRecordPermission { granted in
        DispatchQueue.main.async {
            completion(granted)
        }
    }
}

private func checkpointIfNeeded() {
    let now = Date()
    if lastCheckpointTime == nil || now.timeIntervalSince(lastCheckpointTime!) >= checkpointInterval {
        saveAnalysisState()
        lastCheckpointTime = now
    }
}

private struct AnalysisState: Codable {
    let progress: Double
    let currentFeatures: AudioFeatures?
    let timestamp: Date
}
