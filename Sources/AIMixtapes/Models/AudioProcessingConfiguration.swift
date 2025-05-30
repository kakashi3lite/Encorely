import Foundation
import AVFoundation
import Combine

public class AudioProcessingConfiguration: ObservableObject {
    // MARK: - Published Properties
    
    // Core Settings
    @Published var sampleRate: Double = MLConfig.FeatureExtraction.sampleRate
    @Published var bufferSize: Int = MLConfig.FeatureExtraction.fftSize
    @Published var hopSize: Int = MLConfig.FeatureExtraction.hopSize
    @Published var frameSize: Int = MLConfig.FeatureExtraction.windowSize
    
    // Feature Analysis Settings
    @Published var analysisEnabled: Bool = true
    @Published var realTimeAnalysisEnabled: Bool = true
    @Published var spectralAnalysisEnabled: Bool = true
    @Published var tempoDetectionEnabled: Bool = true
    @Published var onsetDetectionEnabled: Bool = true
    
    // Performance Settings
    @Published var maxProcessingLatency: TimeInterval = MLConfig.Performance.maxProcessingLatency
    @Published var maxMemoryUsage: UInt64 = UInt64(MLConfig.Performance.maxMemoryUsage)
    @Published var targetFPS: Double = MLConfig.Performance.targetFPS
    @Published var enablePerformanceMonitoring: Bool = true
    
    // Mood Detection Settings
    @Published var moodDetectionEnabled: Bool = true
    @Published var moodUpdateInterval: TimeInterval = MLConfig.Analysis.moodUpdateInterval
    @Published var moodConfidenceThreshold: Float = MLConfig.Analysis.confidenceThreshold
    @Published var useCoreMLForMoodDetection: Bool = true
    @Published var moodStabilityFactor: Float = MLConfig.Analysis.moodStabilityFactor
    
    // Device Adaptation
    @Published var adaptToDeviceCapabilities: Bool = MLConfig.DeviceAdaptation.adaptToDeviceCapabilities
    @Published var lowPowerModeEnabled: Bool = MLConfig.DeviceAdaptation.lowPowerModeEnabled
    @Published var backgroundProcessingEnabled: Bool = MLConfig.DeviceAdaptation.backgroundProcessingEnabled
    
    // MARK: - Private Properties
    private let configurationChanged = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupDefaults()
        setupObservers()
        
        if adaptToDeviceCapabilities {
            adaptToCurrentDevice()
        }
    }
    
    // MARK: - Configuration Methods
    
    private func setupDefaults() {
        let defaults = UserDefaults.standard
        
        // Load saved settings or use defaults
        sampleRate = defaults.double(forKey: "audio.sampleRate")
        bufferSize = defaults.integer(forKey: "audio.bufferSize")
        hopSize = defaults.integer(forKey: "audio.hopSize")
        frameSize = defaults.integer(forKey: "audio.frameSize")
        
        analysisEnabled = defaults.bool(forKey: "analysis.enabled")
        realTimeAnalysisEnabled = defaults.bool(forKey: "analysis.realTime")
        spectralAnalysisEnabled = defaults.bool(forKey: "analysis.spectral")
        tempoDetectionEnabled = defaults.bool(forKey: "analysis.tempo")
        
        maxProcessingLatency = defaults.double(forKey: "performance.maxLatency")
        targetFPS = defaults.double(forKey: "performance.targetFPS")
        
        moodConfidenceThreshold = defaults.float(forKey: "mood.confidenceThreshold")
        moodUpdateInterval = defaults.double(forKey: "mood.updateInterval")
        useCoreMLForMoodDetection = defaults.bool(forKey: "mood.useCoreML")
    }
    
    private func setupObservers() {
        // Monitor device state changes
        NotificationCenter.default.publisher(for: NSProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.adaptToThermalState()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSProcessInfo.powerStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.adaptToPowerState()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Device Adaptation
    
    private func adaptToCurrentDevice() {
        let device = UIDevice.current
        let processorCount = ProcessInfo.processInfo.processorCount
        
        // Adapt buffer size based on device capability
        if processorCount >= 6 {
            bufferSize = 4096  // High-end devices
        } else if processorCount >= 4 {
            bufferSize = 2048  // Mid-range devices
        } else {
            bufferSize = 1024  // Lower-end devices
        }
        
        // Adjust hop size
        hopSize = bufferSize / 2
        
        // Adjust target FPS
        if device.userInterfaceIdiom == .phone {
            targetFPS = device.modelIdentifier.contains("iPhone14") ? 30 : 20
        } else {
            targetFPS = 30  // iPad and other devices
        }
    }
    
    private func adaptToThermalState() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .nominal:
            restoreDefaultSettings()
        case .fair:
            applyModeratePowerSaving()
        case .serious, .critical:
            applyAggressivePowerSaving()
        @unknown default:
            restoreDefaultSettings()
        }
    }
    
    private func adaptToPowerState() {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            applyLowPowerMode()
        } else {
            restoreDefaultSettings()
        }
    }
    
    // MARK: - Power Management
    
    private func applyLowPowerMode() {
        bufferSize = 4096
        hopSize = 2048
        targetFPS = 15
        maxProcessingLatency = 0.2
        moodUpdateInterval = 1.0
        backgroundProcessingEnabled = false
        enablePerformanceMonitoring = false
    }
    
    private func applyModeratePowerSaving() {
        bufferSize = 3072
        hopSize = 1536
        targetFPS = 20
        maxProcessingLatency = 0.15
        moodUpdateInterval = 0.75
    }
    
    private func applyAggressivePowerSaving() {
        bufferSize = 4096
        hopSize = 2048
        targetFPS = 10
        maxProcessingLatency = 0.3
        moodUpdateInterval = 1.5
        spectralAnalysisEnabled = false
        backgroundProcessingEnabled = false
    }
    
    private func restoreDefaultSettings() {
        adaptToCurrentDevice()
        
        spectralAnalysisEnabled = true
        tempoDetectionEnabled = true
        onsetDetectionEnabled = true
        
        maxProcessingLatency = MLConfig.Performance.maxProcessingLatency
        targetFPS = MLConfig.Performance.targetFPS
        
        moodUpdateInterval = MLConfig.Analysis.moodUpdateInterval
        useCoreMLForMoodDetection = true
        backgroundProcessingEnabled = true
    }
    
    // MARK: - Presets
    
    public func applyPreset(_ preset: AudioProcessingPreset) {
        switch preset {
        case .lowLatency:
            applyLowLatencyPreset()
        case .highQuality:
            applyHighQualityPreset()
        case .balanced:
            applyBalancedPreset()
        case .powerSaving:
            applyPowerSavingPreset()
        }
        
        configurationChanged.send()
    }
    
    private func applyLowLatencyPreset() {
        bufferSize = 1024
        hopSize = 512
        targetFPS = 30
        maxProcessingLatency = 0.05
        moodUpdateInterval = 0.2
        realTimeAnalysisEnabled = true
        
        saveConfiguration()
    }
    
    private func applyHighQualityPreset() {
        bufferSize = 4096
        hopSize = 2048
        targetFPS = 30
        spectralAnalysisEnabled = true
        onsetDetectionEnabled = true
        tempoDetectionEnabled = true
        useCoreMLForMoodDetection = true
        
        saveConfiguration()
    }
    
    private func applyBalancedPreset() {
        bufferSize = 2048
        hopSize = 1024
        targetFPS = 20
        maxProcessingLatency = 0.1
        moodUpdateInterval = 0.5
        
        saveConfiguration()
    }
    
    private func applyPowerSavingPreset() {
        bufferSize = 4096
        hopSize = 2048
        targetFPS = 15
        maxProcessingLatency = 0.2
        moodUpdateInterval = 1.0
        spectralAnalysisEnabled = true
        tempoDetectionEnabled = false
        onsetDetectionEnabled = false
        backgroundProcessingEnabled = false
        
        saveConfiguration()
    }
    
    // MARK: - Persistence
    
    private func saveConfiguration() {
        let defaults = UserDefaults.standard
        
        defaults.set(sampleRate, forKey: "audio.sampleRate")
        defaults.set(bufferSize, forKey: "audio.bufferSize")
        defaults.set(hopSize, forKey: "audio.hopSize")
        defaults.set(frameSize, forKey: "audio.frameSize")
        
        defaults.set(analysisEnabled, forKey: "analysis.enabled")
        defaults.set(realTimeAnalysisEnabled, forKey: "analysis.realTime")
        defaults.set(spectralAnalysisEnabled, forKey: "analysis.spectral")
        defaults.set(tempoDetectionEnabled, forKey: "analysis.tempo")
        
        defaults.set(maxProcessingLatency, forKey: "performance.maxLatency")
        defaults.set(targetFPS, forKey: "performance.targetFPS")
        
        defaults.set(moodConfidenceThreshold, forKey: "mood.confidenceThreshold")
        defaults.set(moodUpdateInterval, forKey: "mood.updateInterval")
        defaults.set(useCoreMLForMoodDetection, forKey: "mood.useCoreML")
    }
}

// MARK: - Supporting Types

public enum AudioProcessingPreset {
    case lowLatency
    case highQuality 
    case balanced
    case powerSaving
}