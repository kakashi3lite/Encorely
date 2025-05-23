//
//  AudioProcessingConfiguration.swift
//  AI-Mixtapes
//  Created by AI Assistant on 05/23/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import Foundation
import AVFoundation
import Combine

/// Comprehensive configuration system for audio processing
class AudioProcessingConfiguration: ObservableObject {
    
    // MARK: - Static Configuration
    static let shared = AudioProcessingConfiguration()
    
    // MARK: - Audio Engine Settings
    @Published var sampleRate: Double = 44100.0 {
        didSet { validateAndNotify() }
    }
    
    @Published var bufferSize: UInt32 = 4096 {
        didSet { validateAndNotify() }
    }
    
    @Published var hopSize: UInt32 = 2048 {
        didSet { validateAndNotify() }
    }
    
    @Published var frameSize: UInt32 = 4096 {
        didSet { validateAndNotify() }
    }
    
    // MARK: - Analysis Settings
    @Published var analysisEnabled: Bool = true
    @Published var realTimeAnalysisEnabled: Bool = true
    @Published var moodDetectionEnabled: Bool = true
    @Published var spectralAnalysisEnabled: Bool = true
    @Published var tempoDetectionEnabled: Bool = true
    
    // MARK: - Performance Settings
    @Published var maxProcessingLatency: TimeInterval = 0.1 // seconds
    @Published var maxMemoryUsage: UInt64 = 50 * 1024 * 1024 // 50MB
    @Published var targetFPS: Double = 20.0
    @Published var enablePerformanceMonitoring: Bool = true
    
    // MARK: - Mood Detection Settings
    @Published var moodConfidenceThreshold: Float = 0.6
    @Published var moodUpdateInterval: TimeInterval = 0.5
    @Published var useCoreMLForMoodDetection: Bool = true
    @Published var enableMoodSmoothing: Bool = true
    @Published var moodSmoothingFactor: Float = 0.3
    
    // MARK: - Spectral Analysis Settings
    @Published var spectralCentroidEnabled: Bool = true
    @Published var spectralRolloffEnabled: Bool = true
    @Published var spectralFlatnessEnabled: Bool = true
    @Published var zeroCrossingRateEnabled: Bool = true
    @Published var onsetDetectionEnabled: Bool = true
    
    // MARK: - Tempo Detection Settings
    @Published var tempoDetectionMethod: TempoDetectionMethod = .onsetBased
    @Published var tempoRangeMin: Float = 60.0
    @Published var tempoRangeMax: Float = 200.0
    @Published var onsetThreshold: Float = 0.3
    @Published var tempoSmoothingEnabled: Bool = true
    
    // MARK: - Audio Quality Settings
    @Published var audioQuality: AudioQuality = .high
    @Published var enableNoiseGate: Bool = false
    @Published var noiseGateThreshold: Float = -40.0
    @Published var enableAutoGain: Bool = false
    @Published var autoGainTarget: Float = -12.0
    
    // MARK: - Visualization Settings
    @Published var visualizationUpdateRate: Double = 0.05 // FPS
    @Published var waveformPoints: Int = 100
    @Published var spectrumBins: Int = 50
    @Published var enableVisualizationSmoothing: Bool = true
    @Published var visualizationSmoothingFactor: Float = 0.7
    
    // MARK: - Device-Specific Settings
    @Published var adaptToDeviceCapabilities: Bool = true
    @Published var lowPowerModeEnabled: Bool = false
    @Published var backgroundProcessingEnabled: Bool = true
    
    // MARK: - Advanced Settings
    @Published var windowFunction: WindowFunction = .hann
    @Published var fftSize: Int = 4096
    @Published var overlapFactor: Float = 0.5
    @Published var preEmphasisEnabled: Bool = false
    @Published var preEmphasisFactor: Float = 0.97
    
    // MARK: - Logging and Debug Settings
    @Published var enableDebugLogging: Bool = false
    @Published var logPerformanceMetrics: Bool = false
    @Published var exportAnalysisData: Bool = false
    @Published var analysisDataExportInterval: TimeInterval = 60.0
    
    // MARK: - Configuration Validation
    private var validationErrors: [String] = []
    private var configurationVersion: String = "1.0.0"
    
    // MARK: - Notification Publishers
    let configurationChanged = PassthroughSubject<Void, Never>()
    let validationFailed = PassthroughSubject<[String], Never>()
    
    private init() {
        loadConfiguration()
        setupDeviceAdaptation()
    }
    
    // MARK: - Configuration Management
    
    /// Load configuration from UserDefaults
    func loadConfiguration() {
        let defaults = UserDefaults.standard
        
        // Audio Engine Settings
        if let savedSampleRate = defaults.object(forKey: "audio.sampleRate") as? Double {
            sampleRate = savedSampleRate
        }
        
        bufferSize = UInt32(defaults.integer(forKey: "audio.bufferSize")) == 0 ? 4096 : UInt32(defaults.integer(forKey: "audio.bufferSize"))
        hopSize = UInt32(defaults.integer(forKey: "audio.hopSize")) == 0 ? 2048 : UInt32(defaults.integer(forKey: "audio.hopSize"))
        frameSize = UInt32(defaults.integer(forKey: "audio.frameSize")) == 0 ? 4096 : UInt32(defaults.integer(forKey: "audio.frameSize"))
        
        // Analysis Settings
        analysisEnabled = defaults.object(forKey: "analysis.enabled") as? Bool ?? true
        realTimeAnalysisEnabled = defaults.object(forKey: "analysis.realTime") as? Bool ?? true
        moodDetectionEnabled = defaults.object(forKey: "analysis.moodDetection") as? Bool ?? true
        
        // Performance Settings
        maxProcessingLatency = defaults.object(forKey: "performance.maxLatency") as? TimeInterval ?? 0.1
        maxMemoryUsage = UInt64(defaults.integer(forKey: "performance.maxMemory")) == 0 ? 50 * 1024 * 1024 : UInt64(defaults.integer(forKey: "performance.maxMemory"))
        targetFPS = defaults.object(forKey: "performance.targetFPS") as? Double ?? 20.0
        
        // Mood Detection Settings
        moodConfidenceThreshold = defaults.object(forKey: "mood.confidenceThreshold") as? Float ?? 0.6
        moodUpdateInterval = defaults.object(forKey: "mood.updateInterval") as? TimeInterval ?? 0.5
        useCoreMLForMoodDetection = defaults.object(forKey: "mood.useCoreML") as? Bool ?? true
        
        // Device-specific adaptation
        if adaptToDeviceCapabilities {
            adaptToCurrentDevice()
        }
    }
    
    /// Save configuration to UserDefaults
    func saveConfiguration() {
        let defaults = UserDefaults.standard
        
        // Audio Engine Settings
        defaults.set(sampleRate, forKey: "audio.sampleRate")
        defaults.set(Int(bufferSize), forKey: "audio.bufferSize")
        defaults.set(Int(hopSize), forKey: "audio.hopSize")
        defaults.set(Int(frameSize), forKey: "audio.frameSize")
        
        // Analysis Settings
        defaults.set(analysisEnabled, forKey: "analysis.enabled")
        defaults.set(realTimeAnalysisEnabled, forKey: "analysis.realTime")
        defaults.set(moodDetectionEnabled, forKey: "analysis.moodDetection")
        
        // Performance Settings
        defaults.set(maxProcessingLatency, forKey: "performance.maxLatency")
        defaults.set(Int(maxMemoryUsage), forKey: "performance.maxMemory")
        defaults.set(targetFPS, forKey: "performance.targetFPS")
        
        // Mood Detection Settings
        defaults.set(moodConfidenceThreshold, forKey: "mood.confidenceThreshold")
        defaults.set(moodUpdateInterval, forKey: "mood.updateInterval")
        defaults.set(useCoreMLForMoodDetection, forKey: "mood.useCoreML")
        
        defaults.set(configurationVersion, forKey: "config.version")
        defaults.synchronize()
    }
    
    /// Reset configuration to defaults
    func resetToDefaults() {
        sampleRate = 44100.0
        bufferSize = 4096
        hopSize = 2048
        frameSize = 4096
        
        analysisEnabled = true
        realTimeAnalysisEnabled = true
        moodDetectionEnabled = true
        spectralAnalysisEnabled = true
        tempoDetectionEnabled = true
        
        maxProcessingLatency = 0.1
        maxMemoryUsage = 50 * 1024 * 1024
        targetFPS = 20.0
        
        moodConfidenceThreshold = 0.6
        moodUpdateInterval = 0.5
        useCoreMLForMoodDetection = true
        
        audioQuality = .high
        tempoDetectionMethod = .onsetBased
        windowFunction = .hann
        
        saveConfiguration()
        configurationChanged.send()
    }
    
    // MARK: - Device Adaptation
    
    private func setupDeviceAdaptation() {
        // Monitor device performance and adapt settings
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.adaptToBatteryLevel()
        }
        
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.processInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.adaptToThermalState()
        }
    }
    
    private func adaptToCurrentDevice() {
        let device = UIDevice.current
        let deviceType = getDeviceType()
        
        switch deviceType {
        case .iPhone_SE, .iPhone_8, .iPhone_X:
            // Older devices - reduce quality for performance
            audioQuality = .medium
            targetFPS = 15.0
            waveformPoints = 50
            spectrumBins = 25
            
        case .iPhone_12, .iPhone_13, .iPhone_14:
            // Modern devices - high quality
            audioQuality = .high
            targetFPS = 30.0
            waveformPoints = 100
            spectrumBins = 50
            
        case .iPhone_15, .iPhone_Pro:
            // Latest devices - maximum quality
            audioQuality = .ultra
            targetFPS = 60.0
            waveformPoints = 200
            spectrumBins = 100
            
        case .iPad:
            // iPads - optimize for larger processing capability
            audioQuality = .ultra
            targetFPS = 60.0
            waveformPoints = 200
            spectrumBins = 100
            bufferSize = 2048 // smaller buffers for lower latency
            
        case .unknown:
            // Conservative settings for unknown devices
            audioQuality = .medium
            targetFPS = 20.0
        }
    }
    
    private func adaptToBatteryLevel() {
        let batteryLevel = UIDevice.current.batteryLevel
        
        if batteryLevel < 0.2 && UIDevice.current.batteryState == .unplugged {
            // Low battery - enable power saving
            lowPowerModeEnabled = true
            targetFPS = 10.0
            backgroundProcessingEnabled = false
            enablePerformanceMonitoring = false
        } else if batteryLevel > 0.5 {
            // Good battery - restore normal operation
            lowPowerModeEnabled = false
            targetFPS = audioQuality == .ultra ? 60.0 : 30.0
            backgroundProcessingEnabled = true
            enablePerformanceMonitoring = true
        }
    }
    
    private func adaptToThermalState() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .critical, .serious:
            // Reduce processing to prevent overheating
            targetFPS = 10.0
            realTimeAnalysisEnabled = false
            visualizationUpdateRate = 0.2 // FPS
            
        case .fair:
            // Moderate processing
            targetFPS = 20.0
            realTimeAnalysisEnabled = true
            visualizationUpdateRate = 0.1 // FPS
            
        case .nominal:
            // Normal processing
            adaptToCurrentDevice()
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Configuration Validation
    
    private func validateAndNotify() {
        validationErrors.removeAll()
        
        // Validate audio settings
        if sampleRate < 22050 || sampleRate > 96000 {
            validationErrors.append("Sample rate must be between 22,050 and 96,000 Hz")
        }
        
        if bufferSize < 256 || bufferSize > 8192 {
            validationErrors.append("Buffer size must be between 256 and 8,192 samples")
        }
        
        if hopSize > frameSize {
            validationErrors.append("Hop size cannot be larger than frame size")
        }
        
        // Validate performance settings
        if maxProcessingLatency < 0.01 || maxProcessingLatency > 1.0 {
            validationErrors.append("Max processing latency must be between 10ms and 1000ms")
        }
        
        if maxMemoryUsage < 10 * 1024 * 1024 || maxMemoryUsage > 200 * 1024 * 1024 {
            validationErrors.append("Max memory usage must be between 10MB and 200MB")
        }
        
        // Validate mood detection settings
        if moodConfidenceThreshold < 0.1 || moodConfidenceThreshold > 1.0 {
            validationErrors.append("Mood confidence threshold must be between 0.1 and 1.0")
        }
        
        if moodUpdateInterval < 0.1 || moodUpdateInterval > 5.0 {
            validationErrors.append("Mood update interval must be between 0.1 and 5.0 seconds")
        }
        
        // Validate tempo detection settings
        if tempoRangeMin >= tempoRangeMax {
            validationErrors.append("Tempo range minimum must be less than maximum")
        }
        
        if tempoRangeMin < 30 || tempoRangeMax > 300 {
            validationErrors.append("Tempo range must be between 30 and 300 BPM")
        }
        
        // Send notifications
        if validationErrors.isEmpty {
            configurationChanged.send()
            saveConfiguration()
        } else {
            validationFailed.send(validationErrors)
        }
    }
    
    // MARK: - Preset Configurations
    
    func applyPreset(_ preset: ConfigurationPreset) {
        switch preset {
        case .performance:
            applyPerformancePreset()
        case .quality:
            applyQualityPreset()
        case .battery:
            applyBatteryPreset()
        case .realtime:
            applyRealtimePreset()
        case .analysis:
            applyAnalysisPreset()
        }
    }
    
    private func applyPerformancePreset() {
        // Optimize for speed and low latency
        bufferSize = 1024
        hopSize = 512
        frameSize = 1024
        targetFPS = 60.0
        maxProcessingLatency = 0.05
        spectralAnalysisEnabled = false
        onsetDetectionEnabled = false
        enableVisualizationSmoothing = false
    }
    
    private func applyQualityPreset() {
        // Optimize for analysis accuracy
        bufferSize = 8192
        hopSize = 4096
        frameSize = 8192
        targetFPS = 15.0
        maxProcessingLatency = 0.2
        spectralAnalysisEnabled = true
        onsetDetectionEnabled = true
        enableVisualizationSmoothing = true
        preEmphasisEnabled = true
    }
    
    private func applyBatteryPreset() {
        // Optimize for battery life
        lowPowerModeEnabled = true
        targetFPS = 10.0
        visualizationUpdateRate = 0.2
        backgroundProcessingEnabled = false
        enablePerformanceMonitoring = false
        realTimeAnalysisEnabled = false
    }
    
    private func applyRealtimePreset() {
        // Optimize for real-time interaction
        bufferSize = 2048
        hopSize = 1024
        targetFPS = 30.0
        maxProcessingLatency = 0.08
        moodUpdateInterval = 0.25
        realTimeAnalysisEnabled = true
        visualizationUpdateRate = 0.033 // FPS
    }
    
    private func applyAnalysisPreset() {
        // Optimize for detailed analysis
        spectralAnalysisEnabled = true
        spectralCentroidEnabled = true
        spectralRolloffEnabled = true
        spectralFlatnessEnabled = true
        zeroCrossingRateEnabled = true
        onsetDetectionEnabled = true
        tempoDetectionEnabled = true
        moodDetectionEnabled = true
        useCoreMLForMoodDetection = true
    }
    
    // MARK: - Export/Import
    
    func exportConfiguration() -> Data? {
        let configDict: [String: Any] = [
            "version": configurationVersion,
            "audio": [
                "sampleRate": sampleRate,
                "bufferSize": bufferSize,
                "hopSize": hopSize,
                "frameSize": frameSize
            ],
            "analysis": [
                "enabled": analysisEnabled,
                "realTime": realTimeAnalysisEnabled,
                "moodDetection": moodDetectionEnabled,
                "spectralAnalysis": spectralAnalysisEnabled,
                "tempoDetection": tempoDetectionEnabled
            ],
            "performance": [
                "maxLatency": maxProcessingLatency,
                "maxMemory": maxMemoryUsage,
                "targetFPS": targetFPS,
                "monitoring": enablePerformanceMonitoring
            ],
            "mood": [
                "confidenceThreshold": moodConfidenceThreshold,
                "updateInterval": moodUpdateInterval,
                "useCoreML": useCoreMLForMoodDetection,
                "smoothing": enableMoodSmoothing,
                "smoothingFactor": moodSmoothingFactor
            ]
        ]
        
        return try? JSONSerialization.data(withJSONObject: configDict, options: .prettyPrinted)
    }
    
    func importConfiguration(from data: Data) throws {
        let configDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let config = configDict else {
            throw ConfigurationError.invalidFormat
        }
        
        // Import audio settings
        if let audioConfig = config["audio"] as? [String: Any] {
            if let sampleRate = audioConfig["sampleRate"] as? Double {
                self.sampleRate = sampleRate
            }
            if let bufferSize = audioConfig["bufferSize"] as? UInt32 {
                self.bufferSize = bufferSize
            }
            // ... import other settings
        }
        
        // Validate after import
        validateAndNotify()
    }
    
    // MARK: - Utility Methods
    
    private func getDeviceType() -> DeviceType {
        let device = UIDevice.current
        let identifier = device.modelIdentifier
        
        if identifier.contains("iPhone") {
            if identifier.contains("15") {
                return .iPhone_15
            } else if identifier.contains("Pro") {
                return .iPhone_Pro
            } else if identifier.contains("14") || identifier.contains("13") || identifier.contains("12") {
                return .iPhone_12
            } else {
                return .iPhone_8
            }
        } else if identifier.contains("iPad") {
            return .iPad
        }
        
        return .unknown
    }
}

// MARK: - Supporting Types

enum AudioQuality: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"
    
    var displayName: String {
        switch self {
        case .low: return "Low (Battery Saver)"
        case .medium: return "Medium (Balanced)"
        case .high: return "High (Recommended)"
        case .ultra: return "Ultra (Maximum Quality)"
        }
    }
}

enum TempoDetectionMethod: String, CaseIterable {
    case onsetBased = "onset"
    case autocorrelation = "autocorr"
    case hybrid = "hybrid"
    
    var displayName: String {
        switch self {
        case .onsetBased: return "Onset Detection"
        case .autocorrelation: return "Autocorrelation"
        case .hybrid: return "Hybrid (Recommended)"
        }
    }
}

enum WindowFunction: String, CaseIterable {
    case hann = "hann"
    case hamming = "hamming"
    case blackman = "blackman"
    case rectangular = "rectangular"
    
    var displayName: String {
        switch self {
        case .hann: return "Hann (Recommended)"
        case .hamming: return "Hamming"
        case .blackman: return "Blackman"
        case .rectangular: return "Rectangular"
        }
    }
}

enum ConfigurationPreset: String, CaseIterable {
    case performance = "performance"
    case quality = "quality"
    case battery = "battery"
    case realtime = "realtime"
    case analysis = "analysis"
    
    var displayName: String {
        switch self {
        case .performance: return "Performance (Speed)"
        case .quality: return "Quality (Accuracy)"
        case .battery: return "Battery Saver"
        case .realtime: return "Real-time"
        case .analysis: return "Deep Analysis"
        }
    }
    
    var description: String {
        switch self {
        case .performance:
            return "Optimized for speed and low latency. Best for real-time applications."
        case .quality:
            return "Optimized for analysis accuracy. Best for detailed music analysis."
        case .battery:
            return "Optimized for battery life. Reduces processing to extend usage time."
        case .realtime:
            return "Balanced for real-time interaction. Good for live visualizations."
        case .analysis:
            return "Enables all analysis features. Best for comprehensive music insights."
        }
    }
}

enum DeviceType {
    case iPhone_SE
    case iPhone_8
    case iPhone_X
    case iPhone_12
    case iPhone_13
    case iPhone_14
    case iPhone_15
    case iPhone_Pro
    case iPad
    case unknown
}

enum ConfigurationError: LocalizedError {
    case invalidFormat
    case validationFailed([String])
    case unsupportedVersion
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid configuration file format"
        case .validationFailed(let errors):
            return "Configuration validation failed: \(errors.joined(separator: ", "))"
        case .unsupportedVersion:
            return "Unsupported configuration version"
        }
    }
}

// MARK: - UIDevice Extension

extension UIDevice {
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }
}
