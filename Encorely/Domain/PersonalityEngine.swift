import Foundation
import Observation
import os.log

/// Tracks user interactions and derives a music personality type.
///
/// Records events like song completions, skips, and playlist creations,
/// then analyzes patterns to determine a PersonalityType. The result
/// influences recommendation weights and UI presentation.
@Observable
final class PersonalityEngine: @unchecked Sendable {
    // MARK: - Observable State

    /// The current derived personality type.
    private(set) var currentPersonality: PersonalityType = .balanced

    /// Confidence in the personality assessment (0.0–1.0).
    private(set) var confidence: Double = 0.0

    /// Whether an analysis is currently running.
    private(set) var isAnalyzing: Bool = false

    // MARK: - Private

    private let logger = Logger(subsystem: "com.encorely", category: "PersonalityEngine")
    private var interactionHistory: [InteractionEvent] = []
    private var lastAnalysisDate: Date?
    private let analysisCooldown: TimeInterval = 3600

    // MARK: - Public API

    /// Records a user interaction event for later analysis.
    func recordInteraction(_ event: InteractionEvent) {
        interactionHistory.append(event)
        analyzeIfNeeded()
    }

    /// Convenience for recording common events.
    func recordSongCompleted() {
        recordInteraction(InteractionEvent(type: .songComplete))
    }

    func recordSongSkipped() {
        recordInteraction(InteractionEvent(type: .songSkip))
    }

    func recordPlaylistCreated() {
        recordInteraction(InteractionEvent(type: .playlistCreation))
    }

    func recordRatingChanged(from old: Int, to new: Int) {
        recordInteraction(InteractionEvent(
            type: .ratingChange,
            oldValue: String(old),
            newValue: String(new)
        ))
    }

    /// Forces an immediate personality analysis regardless of cooldown.
    func forceAnalyze() {
        performAnalysis()
    }

    /// Resets all interaction history and returns to balanced.
    func reset() {
        interactionHistory.removeAll()
        currentPersonality = .balanced
        confidence = 0.0
        lastAnalysisDate = nil
    }

    // MARK: - Analysis

    private func analyzeIfNeeded() {
        guard shouldAnalyze() else { return }
        performAnalysis()
    }

    private func shouldAnalyze() -> Bool {
        guard interactionHistory.count >= 10 else { return false }
        guard let last = lastAnalysisDate else { return true }
        return Date().timeIntervalSince(last) > analysisCooldown
    }

    private func performAnalysis() {
        guard !interactionHistory.isEmpty else { return }
        isAnalyzing = true

        // Count interaction patterns
        let completions = interactionHistory.filter { $0.type == .songComplete }.count
        let skips = interactionHistory.filter { $0.type == .songSkip }.count
        let playlists = interactionHistory.filter { $0.type == .playlistCreation }.count
        let ratings = interactionHistory.filter { $0.type == .ratingChange }.count
        let total = Double(interactionHistory.count)

        // Derive personality scores from behavior patterns
        let completionRate = Double(completions) / max(1, Double(completions + skips))
        let curationScore = Double(playlists + ratings) / max(1, total)
        let explorationScore = Double(skips) / max(1, total)
        let engagementScore = completionRate

        // Map scores to personality types
        let scores: [PersonalityType: Double] = [
            .explorer:   explorationScore * 1.5,
            .curator:    curationScore * 2.0,
            .enthusiast: engagementScore * 1.5,
            .analyzer:   Double(ratings) / max(1, total) * 2.0,
            .balanced:   0.3,
        ]

        // Find dominant personality
        let dominant = scores.max(by: { $0.value < $1.value })
        let totalScore = scores.values.reduce(0, +)
        let newConfidence = totalScore > 0 ? (dominant?.value ?? 0) / totalScore : 0.0

        if newConfidence > 0.3 {
            currentPersonality = dominant?.key ?? .balanced
            confidence = min(1.0, newConfidence)
        }

        lastAnalysisDate = Date()
        isAnalyzing = false

        logger.info("Personality analyzed: \(self.currentPersonality.rawValue) (\(self.confidence))")
    }
}

// MARK: - Supporting Types

/// A single user interaction event.
struct InteractionEvent: Codable, Sendable {
    let type: InteractionType
    var oldValue: String?
    var newValue: String?
    let timestamp: Date

    init(type: InteractionType, oldValue: String? = nil, newValue: String? = nil) {
        self.type = type
        self.oldValue = oldValue
        self.newValue = newValue
        self.timestamp = Date()
    }
}

/// Categories of tracked user interactions.
enum InteractionType: String, Codable, Sendable {
    case songComplete
    case songSkip
    case playlistCreation
    case ratingChange
    case moodChange
}
