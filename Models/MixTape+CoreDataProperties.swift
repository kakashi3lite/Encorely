import Foundation
import CoreData

extension MixTape {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MixTape> {
        return NSFetchRequest<MixTape>(entityName: "MixTape")
    }

    @NSManaged public var title: String
    @NSManaged public var createdDate: Date?
    @NSManaged public var lastPlayedDate: Date?
    @NSManaged public var moodTags: String?
    @NSManaged public var numberOfSongs: Int16
    @NSManaged public var playCount: Int32
    @NSManaged public var aiGenerated: Bool
    @NSManaged public var urlData: Data?
    @NSManaged public var songs: Set<Song>
    @NSManaged public var personalityType: String?
    @NSManaged public var moodLabel: String?
    @NSManaged public var isPublic: Bool
    @NSManaged public var note: String?
    @NSManaged public var totalDuration: Double
    @NSManaged public var coverImageData: Data?
    
    public var songsArray: [Song] {
        Array(songs).sorted { $0.title < $1.title }
    }
    
    // Convenience computed properties
    public var wrappedTitle: String {
        title 
    }
    
    public var personality: PersonalityType {
        get {
            PersonalityType(rawValue: personalityType ?? "balanced") ?? .balanced
        }
        set {
            personalityType = newValue.rawValue
        }
    }
    
    public var dominantMood: Mood {
        get {
            Mood(rawValue: moodLabel ?? "neutral") ?? .neutral
        }
        set {
            moodLabel = newValue.rawValue
        }
    }
}

// MARK: Generated accessors for songs
extension MixTape {
    @objc(addSongsObject:)
    @NSManaged public func addToSongs(_ value: Song)

    @objc(removeSongsObject:)
    @NSManaged public func removeFromSongs(_ value: Song)

    @objc(addSongs:)
    @NSManaged public func addToSongs(_ values: NSSet)

    @objc(removeSongs:)
    @NSManaged public func removeFromSongs(_ values: NSSet)
}
