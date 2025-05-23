import Foundation
import CoreData

extension Song {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Song> {
        return NSFetchRequest<Song>(entityName: "Song")
    }

    @NSManaged public var name: String
    @NSManaged public var moodTag: String?
    @NSManaged public var playCount: Int32
    @NSManaged public var positionInTape: Int16
    @NSManaged public var urlData: Data?
    @NSManaged public var audioFeatures: Data?
    @NSManaged public var mixTape: MixTape?
    
    // Convenience computed properties
    public var wrappedTitle: String {
        title
    }
    
    public var wrappedArtist: String {
        artist ?? "Unknown Artist"
    }
    
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    public var displayName: String {
        "\(wrappedTitle) - \(wrappedArtist)"
    }
}
