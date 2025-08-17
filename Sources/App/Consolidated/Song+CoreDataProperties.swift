//
//  Song+CoreDataProperties.swift
//  AI-Mixtapes
//
//  Created by Kakashi3lite on 1/1/25.
//
//

import CoreData
import Foundation

public extension Song {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Song> {
        NSFetchRequest<Song>(entityName: "Song")
    }

    // Required attributes
    @NSManaged var name: String
    @NSManaged var positionInTape: Int16

    // Optional attributes
    @NSManaged var artist: String?
    @NSManaged var albumName: String?
    @NSManaged var genre: String?
    @NSManaged var mood: String?
    @NSManaged var duration: Double
    @NSManaged var playCount: Int32
    @NSManaged var urlData: Data?
    @NSManaged var audioFeatures: Data?
    @NSManaged var thumbnailData: Data?

    // Relationships
    @NSManaged var mixTape: MixTape?

    // Convenience computed properties
    // Note: wrappedName is defined in Song+CoreDataClass.swift

    var wrappedArtist: String {
        artist ?? "Unknown Artist"
    }

    var detectedMood: Mood {
        get {
            Mood(rawValue: mood ?? "neutral") ?? .neutral
        }
        set {
            mood = newValue.rawValue
        }
    }

    var features: AudioFeatures? {
        get {
            guard let data = audioFeatures else { return nil }
            return try? JSONDecoder().decode(AudioFeatures.self, from: data)
        }
        set {
            audioFeatures = try? JSONEncoder().encode(newValue)
        }
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var displayName: String {
        "\(wrappedName) - \(wrappedArtist)"
    }
}
