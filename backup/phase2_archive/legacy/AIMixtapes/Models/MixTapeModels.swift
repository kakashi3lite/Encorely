//
//  MixTapeModels.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import CoreData

import AppKit
import Foundation

/// Extension for MixTape that adds AI-related functionality
class MixTape: NSManagedObject {
    @NSManaged var title: String?
    @NSManaged var numberOfSongs: Int16
    @NSManaged var urlData: Data?
    @NSManaged var songs: NSOrderedSet?

    // New fields for AI features
    @NSManaged var moodTags: String? // Comma-separated mood tags
    @NSManaged var aiGenerated: Bool // Whether this was AI-generated
    @NSManaged var lastPlayedDate: Date? // Used for recommendation algorithms
    @NSManaged var playCount: Int32 // Track popularity

    var wrappedTitle: String {
        title ?? "Unknown Title"
    }

    var wrappedUrl: URL {
        if let data = urlData {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                return url
            } catch {
                print(error)
                return URL(fileURLWithPath: "")
            }
        } else {
            return URL(fileURLWithPath: "")
        }
    }

    var songsArray: [Song] {
        let set = songs ?? []
        return set.map { $0 as! Song }.sorted {
            $0.positionInTape < $1.positionInTape
        }
    }

    // Get an array of mood tags associated with this mixtape
    var moodTagsArray: [String] {
        if let tags = moodTags?.split(separator: ",") {
            return tags.map { String($0.trimmingCharacters(in: .whitespaces)) }
        }
        return []
    }

    // Add a mood tag to this mixtape
    func addMoodTag(_ tag: String) {
        var tags = moodTagsArray
        if !tags.contains(tag) {
            tags.append(tag)
            moodTags = tags.joined(separator: ", ")
        }
    }

    // Remove a mood tag from this mixtape
    func removeMoodTag(_ tag: String) {
        var tags = moodTagsArray
        if let index = tags.firstIndex(of: tag) {
            tags.remove(at: index)
            moodTags = tags.joined(separator: ", ")
        }
    }

    // Track that this mixtape was played
    func trackPlay() {
        playCount += 1
        lastPlayedDate = Date()
    }

    // Determine dominant mood based on tags and audio analysis
    func getDominantMood() -> Mood {
        // In a real app, this would be based on audio analysis and tags
        // For now, we'll check tags and fall back to a basic determination

        // Check if any mood tags match directly with our Mood enum
        for tag in moodTagsArray {
            if let mood = Mood(rawValue: tag) {
                return mood
            }

            // Check keywords for each mood
            for mood in Mood.allCases {
                if mood.keywords.contains(tag.lowercased()) {
                    return mood
                }
            }
        }

        // Fall back to checking song titles
        let songTitles = songsArray.map { $0.wrappedName.lowercased() }
        var moodCounts: [Mood: Int] = [:]

        for mood in Mood.allCases {
            var count = 0
            for keyword in mood.keywords {
                for title in songTitles {
                    if title.contains(keyword) {
                        count += 1
                    }
                }
            }
            moodCounts[mood] = count
        }

        // Return mood with highest count or neutral if none
        if let highestMood = moodCounts.max(by: { $0.value < $1.value }),
           highestMood.value > 0
        {
            return highestMood.key
        }

        return .neutral
    }

    // Reorder songs based on mood progression
    func reorderSongsForMoodProgression(startMood: Mood, endMood: Mood, context: NSManagedObjectContext) -> Bool {
        // In a real implementation, this would use audio analysis to determine
        // song moods and create a smooth progression from start to end mood

        // This is a simplified implementation for demonstration purposes
        guard songs?.count ?? 0 > 3 else { return false }

        // Create a copy of songs array to reorder
        var songsToReorder = songsArray

        // Simplified sorting logic:
        // 1. If going from energetic to relaxed, sort by descending tempo/energy
        // 2. If going from relaxed to energetic, sort by ascending tempo/energy
        // 3. For other progressions, shuffle with bias towards the target mood

        if startMood == .energetic, endMood == .relaxed {
            // Simple simulation: sort by name length as proxy for tempo/energy
            songsToReorder.sort { $0.wrappedName.count > $1.wrappedName.count }
        } else if startMood == .relaxed, endMood == .energetic {
            // Simple simulation: sort by name length as proxy for tempo/energy
            songsToReorder.sort { $0.wrappedName.count < $1.wrappedName.count }
        } else {
            // Shuffle with mild bias (just a demonstration)
            songsToReorder.shuffle()
        }

        // Update song positions
        var position: Int16 = 0
        for song in songsToReorder {
            song.positionInTape = position
            position += 1
        }

        // Save changes
        do {
            try context.save()
            return true
        } catch {
            print("Failed to save reordered songs: \(error)")
            return false
        }
    }
}

/// Extension for Song that adds AI-related functionality
class Song: NSManagedObject {
    @NSManaged var name: String?
    @NSManaged var positionInTape: Int16
    @NSManaged var urlData: Data?
    @NSManaged var mixTape: MixTape?

    // New fields for AI features
    @NSManaged var audioFeatures: Data? // Serialized audio features
    @NSManaged var moodTag: String? // Dominant mood of this song
    @NSManaged var playCount: Int32 // Track popularity

    var wrappedName: String {
        name ?? "Unknown Song"
    }

    var wrappedUrl: URL {
        if let data = urlData {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
                return url
            } catch {
                print(error)
                return URL(fileURLWithPath: "")
            }
        } else {
            return URL(fileURLWithPath: "")
        }
    }

    // Track that this song was played
    func trackPlay() {
        playCount += 1
    }

    // Store audio features for this song
    func setAudioFeatures(tempo: Float, energy: Float, valence: Float) {
        // Create AudioFeatures with basic required fields and defaults
        let features = AudioFeatures(
            tempo: tempo,
            energy: energy,
            valence: valence
        )

        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(features)
            audioFeatures = data
        } catch {
            print("Failed to encode audio features: \(error)")
        }
    }

    // Get audio features for this song
    func getAudioFeatures() -> AudioFeatures? {
        guard let data = audioFeatures else { return nil }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(AudioFeatures.self, from: data)
        } catch {
            print("Failed to decode audio features: \(error)")
            return nil
        }
    }

    // Determine dominant mood based on audio features
    func getDominantMood() -> Mood {
        // If we have a mood tag already, use it
        if let tag = moodTag, let mood = Mood(rawValue: tag) {
            return mood
        }

        // If we have audio features, use them to determine mood
        if let features = getAudioFeatures() {
            return features.estimatedMood.toMood()
        }

        // Fall back to checking song name for mood keywords
        let name = wrappedName.lowercased()
        for mood in Mood.allCases {
            for keyword in mood.keywords {
                if name.contains(keyword) {
                    return mood
                }
            }
        }

        return .neutral
    }
}

// Convert between EstimatedMood and Mood
private extension EstimatedMood {
    func toMood() -> Mood {
        switch self {
        case .energetic: .energetic
        case .relaxed: .relaxed
        case .happy: .happy
        case .melancholic: .melancholic
        case .focused: .focused
        case .neutral: .neutral
        }
    }
}

struct PersonalityProfile: Codable {
    let openness: Double
    let conscientiousness: Double
    let extraversion: Double
    let agreeableness: Double
    let neuroticism: Double
}

enum PersonalityType: String, Codable {
    case explorer
    case curator
    case enthusiast
    case social
    case ambient
    case analyzer
}

enum Mood: String, Codable, CaseIterable {
    case energetic
    case relaxed
    case happy
    case melancholic
    case focused
    case romantic
    case angry
    case neutral

    var keywords: [String] {
        switch self {
        case .energetic:
            ["upbeat", "exciting", "energetic", "dance", "party", "workout"]
        case .relaxed:
            ["calm", "chill", "peaceful", "ambient", "meditation"]
        case .happy:
            ["happy", "joyful", "uplifting", "positive", "fun"]
        case .melancholic:
            ["sad", "melancholy", "emotional", "reflective"]
        case .focused:
            ["focus", "concentration", "study", "work"]
        case .romantic:
            ["love", "romantic", "passion", "intimate"]
        case .angry:
            ["angry", "intense", "rage", "aggressive"]
        case .neutral:
            ["neutral", "balanced", "moderate"]
        }
    }

    var color: Color {
        switch self {
        case .energetic: .orange
        case .relaxed: .mint
        case .happy: .yellow
        case .melancholic: .indigo
        case .focused: .blue
        case .romantic: .pink
        case .angry: .red
        case .neutral: .gray
        }
    }

    var description: String {
        switch self {
        case .energetic: "High-energy, upbeat music"
        case .relaxed: "Calm, peaceful melodies"
        case .happy: "Positive, joyful tunes"
        case .melancholic: "Emotional, reflective songs"
        case .focused: "Music for concentration"
        case .romantic: "Love songs and intimate melodies"
        case .angry: "Intense, powerful tracks"
        case .neutral: "Balanced, versatile music"
        }
    }
}
