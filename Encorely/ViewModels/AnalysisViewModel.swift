import Foundation
import Observation

/// Bridges between the AudioAnalyzer and the Analysis views.
@Observable
final class AnalysisViewModel {
    private let analyzer: AudioAnalyzer
    private let moodEngine: MoodEngine

    var isAnalyzing: Bool { analyzer.isAnalyzing }
    var spectrumData: [Float] { analyzer.spectrumData }
    var latestFeatures: AudioFeatures? { analyzer.latestFeatures }

    init(analyzer: AudioAnalyzer, moodEngine: MoodEngine) {
        self.analyzer = analyzer
        self.moodEngine = moodEngine
    }

    /// Analyzes an audio file and updates mood detection.
    func analyzeFile(at url: URL) async throws -> Mood {
        let features = try await analyzer.analyze(url: url)
        let result = moodEngine.detectMood(from: features)
        return result.mood
    }
}
