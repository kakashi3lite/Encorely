//  MoodEngine+Model.swift
//  Extracted model & value types for MoodEngine decomposition.

import Foundation
import SwiftUI

extension Mood {
    var color: Color {
        switch self {
        case .energetic: .orange
        case .relaxed: .blue
        case .happy: .yellow
        case .melancholic: .purple
        case .focused: .green
        case .romantic: .pink
        case .angry: .red
        case .neutral: .gray
        }
    }

    var systemIcon: String {
        switch self {
        case .energetic: "bolt.fill"
        case .relaxed: "leaf.fill"
        case .happy: "sun.max.fill"
        case .melancholic: "cloud.rain.fill"
        case .focused: "target"
        case .romantic: "heart.fill"
        case .angry: "flame.fill"
        case .neutral: "circle.fill"
        }
    }

    var keywords: [String] {
        switch self {
        case .energetic: ["energy", "power", "workout", "upbeat", "dance", "fast", "gym"]
        case .relaxed: ["calm", "chill", "peaceful", "gentle", "slow", "ambient", "sleep"]
        case .happy: ["joy", "uplifting", "cheerful", "bright", "optimistic", "fun"]
        case .melancholic: ["sad", "nostalgic", "emotional", "reflective", "sorrow", "longing"]
        case .focused: ["concentration", "study", "work", "instrumental", "productivity"]
        case .romantic: ["love", "date", "dreamy", "intimate", "passion", "evening"]
        case .angry: ["intense", "heavy", "aggressive", "powerful", "strong", "frustrated"]
        case .neutral: ["balanced", "mixed", "moderate", "versatile", "everyday"]
        }
    }
}

struct MoodAction {
    let title: String
    let action: String
    let mood: Mood
    let confidence: Float
}

enum TimeContext { case morning, afternoon, evening, night }

enum DetectionState { case inactive, active, analyzing }

class MoodClassifier {
    func prediction(energy: Float, valence: Float, tempo: Float,
                    danceability: Float, acousticness: Float) throws -> MoodPrediction
    {
        let moodString: String
        var confidence: Float = 0.7
        if energy > 0.7, valence > 0.7 { moodString = "Happy"
            confidence = 0.8
        } else if energy > 0.7, valence < 0.4 { moodString = "Angry"
            confidence = 0.75
        } else if energy > 0.7 { moodString = "Energetic"
            confidence = 0.8
        } else if energy < 0.4, valence > 0.5 { moodString = "Relaxed"
            confidence = 0.8
        } else if energy < 0.4, valence < 0.4 { moodString = "Melancholic"
            confidence = 0.75
        } else if danceability > 0.7, valence > 0.6 { moodString = "Happy" }
        else if acousticness > 0.7, valence > 0.5 { moodString = "Romantic" }
        else if tempo < 90, energy < 0.5 { moodString = "Relaxed" }
        else if tempo > 120, energy > 0.6 { moodString = "Energetic" }
        else { moodString = "Neutral"
            confidence = 0.6
        }
        return MoodPrediction(mood: moodString, confidence: confidence)
    }
}

struct MoodPrediction { let mood: String?
    let confidence: Float?
}

extension Notification.Name {
    static let audioFeaturesUpdated = Notification.Name("audioFeaturesUpdated")
    static let moodDetectionStateChanged = Notification.Name("moodDetectionStateChanged")
}
