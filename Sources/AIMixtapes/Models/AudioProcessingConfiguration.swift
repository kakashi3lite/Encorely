import Foundation
import AVFoundation
import Combine

final class AudioProcessingConfiguration: ObservableObject {
    static let shared = AudioProcessingConfiguration()
    
    // MARK: - Platform-specific defaults
    
    private static let defaultMemoryUsage: UInt64 = {
        #if os(macOS)
        return min(100 * 1024 * 1024, ProcessInfo.processInfo.physicalMemory / 20) // 5% of RAM or 100MB
        #else
        return min(50 * 1024 * 1024, ProcessInfo.processInfo.physicalMemory / 40) // 2.5% of RAM or 50MB
        #endif
    }()
    
    private static let defaultBufferSize: UInt32 = {
        let processorCount = ProcessInfo.processInfo.processorCount
        #if os(macOS)
        return UInt32(min(8192, max(2048, processorCount * 512)))
        #else
        return UInt32(min(4096, max(1024, processorCount * 256)))
        #endif
    }()
    
    private static let defaultLatency: TimeInterval = {
        #if os(macOS)
        return 0.15 // 150ms for macOS
        #else 
        return 0.10 // 100ms for iOS
        #endif
    }()
    private static let defaultMaxLatency: TimeInterval = {
        #if os(macOS)
        return 0.15  // 150ms for macOS
        #else
        return 0.10  // 100ms for iOS
        #endif
    }()
    
    // Default frame size per platform
    private static let defaultFrameSize: UInt32 = {
        #if os(macOS)
        return 8192  // Larger frames for macOS
        #else
        return 4096  // Smaller frames for iOS
        #endif
    }()
    
    // MARK: - Published Properties
    
    // Core Settings
    @Published var sampleRate: Double = MLConfig.FeatureExtraction.sampleRate
    @Published var bufferSize: UInt32 = defaultBufferSize
    @Published var hopSize: UInt32
    @Published var frameSize: UInt32
    @Published var maxMemoryUsage: UInt64 = defaultMemoryUsage
    @Published var targetFPS: Double
    
    // Performance Settings
    @Published var optimizationPreset: OptimizationPreset = .balanced {
        didSet { applyPresetSettings() }
    }
    @Published var adaptiveProcessingEnabled: Bool = true
    @Published var autoAdjustQuality: Bool = true
    
    // New adaptive thresholds
    private var memoryPressureThresholds: [MemoryPressureLevel: Double] = [
        .low: 0.6,
        .moderate: 0.75,
        .high: 0.85,
        .critical: 0.95
    ]
    
    enum MemoryPressureLevel: Int {
        case low, moderate, high, critical
    }
    
    enum OptimizationPreset {
        case ultraLowLatency
        case balanced
        case highQuality
        case powerSaving
        case custom
    }
    
    // MARK: - Private Properties
    private let configurationChanged = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        self.hopSize = Self.defaultBufferSize / 2
        self.frameSize = Self.defaultBufferSize
        self.targetFPS = Self.defaultTargetFPS()
        setupAdaptiveConfiguration()
    }
    
    // MARK: - Configuration Methods
    
    private func setupAdaptiveConfiguration() {
        // Monitor system conditions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Start periodic optimization checks
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateAdaptiveSettings()
        }
    }
    
    private func updateAdaptiveSettings() {
        guard adaptiveProcessingEnabled else { return }
        
        // Check system conditions
        let memoryUsage = getCurrentMemoryUsage()
        let thermalState = ProcessInfo.processInfo.thermalState
        let batteryLevel = getBatteryLevel()
        
        // Adjust settings based on conditions
        adjustForMemoryPressure(memoryUsage)
        adjustForThermalState(thermalState)
        adjustForBatteryLevel(batteryLevel)
    }
    
    private func adjustForMemoryPressure(_ usage: Double) {
        var newPreset = optimizationPreset
        
        switch usage {
        case memoryPressureThresholds[.critical]!...:
            newPreset = .ultraLowLatency
            performEmergencyCleanup()
        case memoryPressureThresholds[.high]!...:
            newPreset = .powerSaving
        case memoryPressureThresholds[.moderate]!...:
            newPreset = .balanced
        default:
            // Maintain current preset if memory usage is low
            break
        }
        
        if newPreset != optimizationPreset {
            optimizationPreset = newPreset
        }
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        return Double(info.resident_size) / Double(maxMemoryUsage)
    }
    
    private static func defaultTargetFPS() -> Double {
        #if os(macOS)
        return 60.0
        #else
        return ProcessInfo.processInfo.processorCount >= 4 ? 30.0 : 20.0
        #endif
    }
    
    private func performEmergencyCleanup() {
        // Notify observers of critical memory situation
        NotificationCenter.default.post(
            name: Notification.Name("AudioProcessingEmergencyCleanup"),
            object: nil
        )
        
        // Reset to minimum settings
        bufferSize = 1024
        hopSize = 512
        targetFPS = 15.0
    }
    
    // Battery level monitoring
    private func getBatteryLevel() -> Float {
        #if os(iOS)
        return UIDevice.current.batteryLevel
        #else
        return 1.0 // Always plugged in on macOS
        #endif
    }
    
    private func adjustForBatteryLevel(_ level: Float) {
        guard autoAdjustQuality else { return }
        
        if level < 0.2 {
            optimizationPreset = .powerSaving
        } else if level < 0.5 && optimizationPreset == .highQuality {
            optimizationPreset = .balanced
        }
    }
    
    private func adjustForThermalState(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .critical:
            optimizationPreset = .ultraLowLatency
        case .serious:
            optimizationPreset = .powerSaving
        case .fair:
            if optimizationPreset == .highQuality {
                optimizationPreset = .balanced
            }
        default:
            break
        }
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