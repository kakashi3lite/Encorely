import Foundation

/// Represents the persistent state of audio analysis
struct AudioAnalysisState: Codable {
    let isAnalyzing: Bool
    let progress: Double
    let currentFeatures: AudioFeatures?
    let analysisHistory: [URL: AudioFeatures]

    // Optional metadata for recovery
    var lastUpdateTime: Date
    var analysisConfiguration: AnalysisConfiguration?

    init(isAnalyzing: Bool, progress: Double, currentFeatures: AudioFeatures?, analysisHistory: [URL: AudioFeatures]) {
        self.isAnalyzing = isAnalyzing
        self.progress = progress
        self.currentFeatures = currentFeatures
        self.analysisHistory = analysisHistory
        lastUpdateTime = Date()
    }
}

/// Configuration parameters for analysis
struct AnalysisConfiguration: Codable {
    let sampleRate: Double
    let bufferSize: Int
    let useBackgroundProcessing: Bool
    let moodDetectionEnabled: Bool
    let tempoDetectionEnabled: Bool

    static var `default`: AnalysisConfiguration {
        AnalysisConfiguration(
            sampleRate: 44100.0,
            bufferSize: 4096,
            useBackgroundProcessing: true,
            moodDetectionEnabled: true,
            tempoDetectionEnabled: true
        )
    }
}
