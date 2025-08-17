//
//  MixTapeModels.swift
//  Mixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import AppKit
import CoreData
import Foundation

// Import the CoreData class definitions
// Note: MixTape and Song classes are defined in their respective +CoreDataClass.swift files

/// Extension for MixTape that adds AI-related functionality
extension MixTape {
    // Additional computed properties for AI features
    // Note: wrappedTitle, wrappedUrl, songsArray, and moodTagsArray are defined in MixTape+CoreDataClass.swift

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

    // Note: trackPlay() method is defined in MixTape+CoreDataClass.swift

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

// MARK: - Song Extension

extension Song {
    // Core Data properties are defined in Song+CoreDataProperties.swift

    // Note: wrappedName and wrappedUrl are defined in Song+CoreDataClass.swift

    var wrappedUrlFromData: URL {
        guard let data = urlData else {
            return URL(fileURLWithPath: "")
        }
        do {
            var isStale = false
            return try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
        } catch {
            print("Error resolving URL: \(error)")
            return URL(fileURLWithPath: "")
        }
    }

    // Note: trackPlay() method is defined in Song+CoreDataClass.swift
    // Note: setAudioFeatures() and getAudioFeatures() methods are defined in Song+CoreDataClass.swift

    // Determine mood based on audio features
    func determineMood() -> Mood {
        // If we have a mood tag, use it
        if let tag = mood, let moodValue = Mood(rawValue: tag) {
            return moodValue
        }

        // Use audio features to determine mood
        if let features = getAudioFeatures() {
            if features.energy > 0.7 {
                return features.valence > 0.6 ? .energetic : .angry
            } else if features.energy < 0.4 {
                return features.valence > 0.5 ? .relaxed : .melancholic
            } else {
                if features.valence > 0.7 {
                    return .happy
                } else if features.valence < 0.3 {
                    return .melancholic
                }
                return .neutral
            }
        }

        return .neutral
    }

    // Get mood keywords for search
    func getMoodKeywords() -> [String] {
        let mood = determineMood()
        return mood.keywords
    }

    // Check if song matches a specific mood
    func matchesMood(_ targetMood: Mood) -> Bool {
        let songMood = determineMood()
        return songMood == targetMood
    }

    // Get mood compatibility score with another song
    func moodCompatibility(with otherSong: Song) -> Double {
        let thisMood = determineMood()
        let otherMood = otherSong.determineMood()

        // Simple compatibility matrix
        let compatibilityMatrix: [Mood: [Mood: Double]] = [
            .energetic: [
                .energetic: 1.0,
                .happy: 0.8,
                .focused: 0.6,
                .neutral: 0.4,
                .romantic: 0.2,
                .relaxed: 0.1,
                .melancholic: 0.0,
                .angry: 0.3,
            ],
            .happy: [
                .energetic: 0.8,
                .happy: 1.0,
                .focused: 0.5,
                .neutral: 0.6,
                .romantic: 0.7,
                .relaxed: 0.4,
                .melancholic: 0.1,
                .angry: 0.0,
            ],
            .focused: [
                .energetic: 0.6,
                .happy: 0.5,
                .focused: 1.0,
                .neutral: 0.8,
                .romantic: 0.3,
                .relaxed: 0.7,
                .melancholic: 0.4,
                .angry: 0.2,
            ],
            .neutral: [
                .energetic: 0.4,
                .happy: 0.6,
                .focused: 0.8,
                .neutral: 1.0,
                .romantic: 0.5,
                .relaxed: 0.6,
                .melancholic: 0.5,
                .angry: 0.3,
            ],
            .romantic: [
                .energetic: 0.2,
                .happy: 0.7,
                .focused: 0.3,
                .neutral: 0.5,
                .romantic: 1.0,
                .relaxed: 0.8,
                .melancholic: 0.6,
                .angry: 0.0,
            ],
            .relaxed: [
                .energetic: 0.1,
                .happy: 0.4,
                .focused: 0.7,
                .neutral: 0.6,
                .romantic: 0.8,
                .relaxed: 1.0,
                .melancholic: 0.7,
                .angry: 0.0,
            ],
            .melancholic: [
                .energetic: 0.0,
                .happy: 0.1,
                .focused: 0.4,
                .neutral: 0.5,
                .romantic: 0.6,
                .relaxed: 0.7,
                .melancholic: 1.0,
                .angry: 0.3,
            ],
            .angry: [
                .energetic: 0.3,
                .happy: 0.0,
                .focused: 0.2,
                .neutral: 0.3,
                .romantic: 0.0,
                .relaxed: 0.0,
                .melancholic: 0.3,
                .angry: 1.0,
            ],
        ]

        return compatibilityMatrix[thisMood]?[otherMood] ?? 0.5
    }

    // Get energy level for mood progression
    func getEnergyLevel() -> Double {
        if let features = getAudioFeatures() {
            return Double(features.energy)
        }

        // Fallback based on mood
        let mood = determineMood()
        switch mood {
        case .energetic, .angry:
            return 0.8
        case .happy, .focused:
            return 0.7
        case .neutral:
            return 0.5
        case .romantic:
            return 0.4
        case .relaxed, .melancholic:
            return 0.3
        }
    }

    // Get valence level for mood progression
    func getValenceLevel() -> Double {
        if let features = getAudioFeatures() {
            return Double(features.valence)
        }

        // Fallback based on mood
        let mood = determineMood()
        switch mood {
        case .happy, .energetic:
            return 0.8
        case .relaxed:
            return 0.6
        case .neutral, .focused:
            return 0.5
        case .romantic:
            return 0.4
        case .melancholic:
            return 0.3
        case .angry:
            return 0.2
        }
    }

    // Calculate mood transition score to another song
    func moodTransitionScore(to nextSong: Song) -> Double {
        let currentEnergy = getEnergyLevel()
        let nextEnergy = nextSong.getEnergyLevel()
        let currentValence = getValenceLevel()
        let nextValence = nextSong.getValenceLevel()

        // Prefer gradual transitions
        let energyDiff = abs(currentEnergy - nextEnergy)
        let valenceDiff = abs(currentValence - nextValence)

        // Score is higher for smaller differences (smoother transitions)
        let energyScore = max(0, 1.0 - energyDiff)
        let valenceScore = max(0, 1.0 - valenceDiff)

        return (energyScore + valenceScore) / 2.0
    }
}

struct PersonalityProfile: Codable {
    let openness: Double
    let conscientiousness: Double
    let extraversion: Double
    let agreeableness: Double
    let neuroticism: Double
}

// PersonalityType and Mood are now defined in SharedTypes.swift
