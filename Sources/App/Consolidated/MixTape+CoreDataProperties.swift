import CoreData
import Foundation

public extension MixTape {
    @nonobjc class func fetchRequest() -> NSFetchRequest<MixTape> {
        NSFetchRequest<MixTape>(entityName: "MixTape")
    }

    // Required attributes
    @NSManaged var title: String
    @NSManaged var numberOfSongs: Int16

    // Optional attributes
    @NSManaged var createdDate: Date?
    @NSManaged var lastPlayedDate: Date?
    @NSManaged var moodTags: String?
    @NSManaged var playCount: Int32
    @NSManaged var aiGenerated: Bool
    @NSManaged var urlData: Data?
    @NSManaged var personalityType: String?
    @NSManaged var isPublic: Bool
    @NSManaged var note: String?
    @NSManaged var totalDuration: Double
    @NSManaged var coverImageData: Data?

    // Relationships
    @NSManaged var songs: NSOrderedSet?

    var songsArray: [Song] {
        let set = songs ?? NSOrderedSet()
        return set.array.compactMap { $0 as? Song }.sorted { $0.positionInTape < $1.positionInTape }
    }

    // Convenience computed properties
    var wrappedTitle: String {
        title
    }

    var personality: PersonalityType {
        get {
            PersonalityType(rawValue: personalityType ?? "balanced") ?? .balanced
        }
        set {
            personalityType = newValue.rawValue
        }
    }

    var dominantMood: Mood {
        get {
            // Extract the first mood tag if available
            if let tags = moodTags?.split(separator: ",").first {
                let tag = String(tags.trimmingCharacters(in: .whitespaces))
                return Mood(rawValue: tag) ?? .neutral
            }
            return .neutral
        }
        set {
            // Set the first mood tag
            moodTags = newValue.rawValue
        }
    }
}

// MARK: Generated accessors for songs

public extension MixTape {
    @objc(addSongsObject:)
    @NSManaged func addToSongs(_ value: Song)

    @objc(removeSongsObject:)
    @NSManaged func removeFromSongs(_ value: Song)

    @objc(addSongs:)
    @NSManaged func addToSongs(_ values: NSSet)

    @objc(removeSongs:)
    @NSManaged func removeFromSongs(_ values: NSSet)
}
