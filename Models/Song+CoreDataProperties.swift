import Foundation
import CoreData

extension Song {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Song> {
        return NSFetchRequest<Song>(entityName: "Song")
    }

    @NSManaged public var name: String
    @NSManaged public var artist: String?
    @NSManaged public var albumName: String?
    @NSManaged public var genre: String?
    @NSManaged public var mood: String?
    @NSManaged public var duration: Double
    @NSManaged public var playCount: Int32
    @NSManaged public var positionInTape: Int16
    @NSManaged public var urlData: Data?
    @NSManaged public var audioFeatures: Data?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var mixTape: MixTape?
    
    // Convenience computed properties
    public var wrappedName: String {
        name
    }
    
    public var wrappedArtist: String {
        artist ?? "Unknown Artist"
    }
    
    public var detectedMood: Mood {
        get {
            Mood(rawValue: mood ?? "neutral") ?? .neutral
        }
        set {
            mood = newValue.rawValue
        }
    }
    
    public var features: AudioFeatures? {
        get {
            guard let data = audioFeatures else { return nil }
            return try? JSONDecoder().decode(AudioFeatures.self, from: data)
        }
        set {
            audioFeatures = try? JSONEncoder().encode(newValue)
        }
    }
    
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    public var displayName: String {
        "\(wrappedName) - \(wrappedArtist)"
    }
}
