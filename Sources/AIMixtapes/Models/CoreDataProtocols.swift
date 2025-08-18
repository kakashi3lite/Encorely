//
//  CoreDataProtocols.swift
//  AIMixtapes
//
//  Created by Claude AI on 05/16/25.
//  Copyright © 2025 Swanand Tanavade. All rights reserved.
//

import CoreData
import Domain
import Foundation
import SharedTypes

// MARK: - Protocols for Core Data Models

// Protocol for MixTape model
public protocol MixTapeProtocol {
    var name: String? { get set }
    var creationDate: Date? { get set }
    var lastPlayed: Date? { get set }
    var playCount: Int32 { get set }
    var moodTags: String? { get set }
    var songs: NSSet? { get set }
    var objectID: NSManagedObjectID { get }

    // Methods
    func trackPlay()
    func reorderSongsForMoodProgression(startMood: Domain.Mood, endMood: Domain.Mood, context: NSManagedObjectContext)
        -> Bool
}

// Protocol for Song model
public protocol SongProtocol {
    var name: String? { get set }
    var artist: String? { get set }
    var album: String? { get set }
    var url: URL? { get set }
    var urlData: Data? { get set }
    var mood: String? { get set }
    var positionInTape: Int16 { get set }
    var mixtape: MixTapeProtocol? { get set }
    var audioFeatures: Data? { get set }
    var duration: Double { get set }

    // Methods
    func trackPlay()
    func setAudioFeatures(_ features: AudioFeatures)
    func getAudioFeatures() -> AudioFeatures?
}

// MARK: - Extension helpers

// Extension for MixTape protocol
public extension MixTapeProtocol {
    // Computed properties
    var wrappedName: String {
        name ?? "Untitled Mixtape"
    }

    var wrappedCreationDate: Date {
        creationDate ?? Date()
    }

    var wrappedLastPlayed: Date {
        lastPlayed ?? Date()
    }

    var moodTagsArray: [String] {
        moodTags?.components(separatedBy: ", ") ?? []
    }

    var songsArray: [SongProtocol] {
        let songObjects = songs?.allObjects as? [SongProtocol] ?? []
        return songObjects.sorted { $0.wrappedName < $1.wrappedName }
    }

    // Add a mood tag to this mixtape
    mutating func addMoodTag(_ tag: String) {
        var tags = moodTagsArray
        if !tags.contains(tag) {
            tags.append(tag)
            moodTags = tags.joined(separator: ", ")
        }
    }

    // Remove a mood tag from this mixtape
    mutating func removeMoodTag(_ tag: String) {
        var tags = moodTagsArray
        if let index = tags.firstIndex(of: tag) {
            tags.remove(at: index)
            moodTags = tags.joined(separator: ", ")
        }
    }

    // Determine dominant mood based on tags and audio analysis
    func getDominantMood() -> Domain.Mood {
        // In a real app, this would be based on audio analysis and tags
        // For now, we'll check tags and fall back to a basic determination

        // Check if any mood tags match directly with our Mood enum
        for tag in moodTagsArray {
            if let mood = Domain.Mood(rawValue: tag) {
                return mood
            }

            // Check keywords for each mood
            for mood in Domain.Mood.allCases {
                if mood.keywords.contains(tag.lowercased()) {
                    return mood
                }
            }
        }

        // Fall back to checking song titles
        let songTitles = songsArray.map { $0.wrappedName.lowercased() }
        var moodCounts: [Domain.Mood: Int] = [:]

        for mood in Domain.Mood.allCases {
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

    // Default implementation for trackPlay
    func trackPlay() {
        // This is a protocol so we can't directly set the property
        // Implementations will need to handle this
        // playCount += 1
        // lastPlayed = Date()
    }

    // AI-specific functionality
    func reorderSongsForMoodProgression(startMood: Domain.Mood, endMood: Domain.Mood,
                                        context: NSManagedObjectContext) -> Bool
    {
        // In a real implementation, this would use audio analysis to determine
        // song moods and create a smooth progression from start to end mood

        // This is a simplified implementation for demonstration purposes
        guard songsArray.count > 3 else { return false }

        // Create a copy of songs array to reorder
        var songsToReorder = songsArray

        // Simplified sorting logic:
        // 1. If going from energetic to relaxed, sort by descending tempo/energy
        // 2. If going from relaxed to energetic, sort by ascending tempo/energy
        // 3. For other progressions, shuffle with bias towards the target mood

        if startMood == .energetic, endMood == .relaxed {
            // Simple simulation: sort by name length as proxy for tempo/energy
            songsToReorder.sort { s1, s2 -> Bool in
                return s1.wrappedName.count > s2.wrappedName.count
            }
        } else if startMood == .relaxed, endMood == .energetic {
            // Simple simulation: sort by name length as proxy for tempo/energy
            songsToReorder.sort { s1, s2 -> Bool in
                return s1.wrappedName.count < s2.wrappedName.count
            }
        } else {
            // Shuffle with mild bias (just a demonstration)
            songsToReorder.shuffle()
        }

        // In a real implementation, we would update the Core Data model
        // This is just a simulation for now
        return true
    }

    // Analyze the mixtape for mood consistency
    func analyzeMoodConsistency() -> Float {
        // This would use audio features and ML in a real app
        // For now, just return a random value between 0 and 1
        Float.random(in: 0 ... 1)
    }
}

// Extension for Song protocol
public extension SongProtocol {
    // Computed properties
    var wrappedName: String {
        name ?? "Unknown Song"
    }

    var wrappedArtist: String {
        artist ?? "Unknown Artist"
    }

    var wrappedAlbum: String {
        album ?? "Unknown Album"
    }

    var wrappedUrl: URL {
        url ?? URL(fileURLWithPath: "")
    }

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

    // Default implementation for getAudioFeatures
    func getAudioFeatures() -> AudioFeatures? {
        guard let featuresData = audioFeatures else { return nil }

        do {
            return try JSONDecoder().decode(AudioFeatures.self, from: featuresData)
        } catch {
            print("Error decoding audio features: \(error)")
            return nil
        }
    }

    // Default implementation for setAudioFeatures
    func setAudioFeatures(_ features: AudioFeatures) {
        do {
            _ = try JSONEncoder().encode(features)
            // This is a protocol so we can't directly set the property
            // Implementations will need to handle this
        } catch {
            print("Error encoding audio features: \(error)")
        }
    }

    // Determine mood based on audio features
    func determineMood() -> Domain.Mood {
        // If we have a mood tag, use it
        if let tag = mood, let moodValue = Domain.Mood(rawValue: tag) {
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
    func matchesMood(_ targetMood: Domain.Mood) -> Bool {
        let songMood = determineMood()
        return songMood == targetMood
    }

    // AI-specific functionality
    func compatibilityScore(with targetMood: Domain.Mood) -> Float {
        // In a real app, this would use audio features and ML
        // For now, just return a random value between 0 and 1
        Float.random(in: 0 ... 1)
    }

    // Predict if this song would be a good transition between two other songs
    func transitionScore(from: SongProtocol, to: SongProtocol) -> Float {
        // In a real app, this would use audio features and ML
        // For now, just return a random value between 0 and 1
        Float.random(in: 0 ... 1)
    }
}
