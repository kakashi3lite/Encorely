import Combine
import Foundation

/// Processes voice commands and converts them into app actions
class VoiceCommandProcessor {
    // MARK: - Properties

    private let commandPublisher = PassthroughSubject<VoiceCommand, Never>()
    var commandStream: AnyPublisher<VoiceCommand, Never> {
        commandPublisher.eraseToAnyPublisher()
    }

    // Confidence thresholds
    private let minimumCommandConfidence: Float = 0.7
    private let minimumMoodConfidence: Float = 0.6
    private let minimumGenreConfidence: Float = 0.65

    // MARK: - Command Keywords

    private let moodKeywords: [Mood: Set<String>] = [
        .energetic: ["energetic", "upbeat", "pumped", "high energy", "workout"],
        .relaxed: ["relaxed", "chill", "calm", "peaceful", "mellow"],
        .happy: ["happy", "joyful", "cheerful", "positive", "uplifting"],
        .melancholic: ["sad", "melancholic", "emotional", "moody", "blue"],
        .focused: ["focused", "concentrate", "study", "work", "productive"],
        .romantic: ["romantic", "love", "intimate", "sensual", "passion"],
        .angry: ["angry", "intense", "aggressive", "powerful", "strong"],
        .neutral: ["neutral", "balanced", "normal", "default"],
    ]

    private let commandTriggers: Set<String> = [
        "play", "switch to", "change to", "set mood to",
        "make it", "give me", "i want", "i need",
    ]

    // MARK: - Public Methods

    func processCommand(transcript: String, segments: [VoiceSegment]) {
        let normalizedTranscript = transcript.lowercased()

        // First check for command trigger words
        guard segments.contains(where: { segment in
            commandTriggers.contains { trigger in
                segment.text.lowercased().contains(trigger)
            }
        }) else {
            return // No command trigger found
        }

        // Process for mood commands
        if let (mood, confidence) = detectMood(in: normalizedTranscript, segments: segments) {
            if confidence >= minimumMoodConfidence {
                commandPublisher.send(.setMood(mood))
            }
        }

        // Process for genre commands (to be implemented)
        if let (genre, confidence) = detectGenre(in: normalizedTranscript) {
            if confidence >= minimumGenreConfidence {
                commandPublisher.send(.setGenre(genre))
            }
        }

        // Process complex commands that might combine mood and activity
        processComplexCommand(transcript: normalizedTranscript, segments: segments)
    }

    // MARK: - Private Methods

    private func detectMood(in _: String, segments: [VoiceSegment]) -> (Mood, Float)? {
        var bestMatch: (mood: Mood, confidence: Float) = (.neutral, 0)

        for (mood, keywords) in moodKeywords {
            let matches = segments.filter { segment in
                keywords.contains { keyword in
                    segment.text.lowercased().contains(keyword)
                }
            }

            if let bestMatchInMood = matches.max(by: { $0.confidence < $1.confidence }) {
                if bestMatchInMood.confidence > bestMatch.confidence {
                    bestMatch = (mood, bestMatchInMood.confidence)
                }
            }
        }

        return bestMatch.confidence > 0 ? bestMatch : nil
    }

    private func detectGenre(in _: String) -> (String, Float)? {
        // To be implemented - will use genre mapping similar to mood mapping
        nil
    }

    private func processComplexCommand(transcript: String, segments _: [VoiceSegment]) {
        // Look for combinations of mood and activity
        // e.g. "play something energetic for working out"
        // or "I need focusing music for studying"

        if transcript.contains("workout") || transcript.contains("exercise") {
            commandPublisher.send(.setMood(.energetic))
        } else if transcript.contains("study") || transcript.contains("focus") {
            commandPublisher.send(.setMood(.focused))
        } else if transcript.contains("sleep") || transcript.contains("relax") {
            commandPublisher.send(.setMood(.relaxed))
        }
    }
}

// MARK: - Supporting Types

enum VoiceCommand {
    case setMood(Mood)
    case setGenre(String)
    case adjustTempo(Float)
    case adjustEnergy(Float)
}
