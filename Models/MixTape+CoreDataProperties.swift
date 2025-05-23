import Foundation
import CoreData

extension MixTape {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<MixTape> {
        return NSFetchRequest<MixTape>(entityName: "MixTape")
    }

    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var createdAt: Date?
    @NSManaged public var moodLabel: String?
    @NSManaged public var songs: Set<Song>
    @NSManaged public var songs: Set<Song>
    
    public var songsArray: [Song] {
        Array(songs).sorted { $0.title < $1.title }
    }
    
    // Convenience computed properties
    public var wrappedTitle: String {
        title 
    }
    
    public var wrappedMoodLabel: String {
        moodLabel ?? "neutral"
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
