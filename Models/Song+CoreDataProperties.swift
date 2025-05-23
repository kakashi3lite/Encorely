import Foundation
import CoreData

extension Song {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Song> {
        return NSFetchRequest<Song>(entityName: "Song")
    }

    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var artist: String?
    @NSManaged public var duration: Double
    @NSManaged public var url: URL?
    @NSManaged public var mixtape: MixTape?
    
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
