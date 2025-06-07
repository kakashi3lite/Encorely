import Foundation
import CoreData

// MARK: - Model Definitions
enum Mood: String, CaseIterable, Codable {
    case energetic, relaxed, happy, melancholic, focused, romantic, angry, neutral
    
    var keywords: [String] {
        switch self {
        case .energetic: return ["upbeat", "energetic", "fast", "party"]
        case .relaxed: return ["chill", "calm", "peaceful", "relax"]
        case .happy: return ["happy", "joy", "fun", "cheerful"]
        case .melancholic: return ["sad", "blue", "melancholy", "lonely"]
        case .focused: return ["focus", "study", "concentrate", "work"]
        case .romantic: return ["love", "romance", "slow", "intimate"]
        case .angry: return ["angry", "rage", "intense", "heavy"]
        case .neutral: return ["neutral", "balanced", "moderate"]
        }
    }
}

// MARK: - Core Data Models
@objc(MixTapeEntity)
public class MixTape: NSManagedObject {
    @NSManaged public var title: String?
    @NSManaged public var numberOfSongs: Int16
    @NSManaged public var urlData: Data?
    @NSManaged public var songs: NSOrderedSet?
    @NSManaged public var moodTags: String?
    @NSManaged public var aiGenerated: Bool
    @NSManaged public var lastPlayedDate: Date?
    @NSManaged public var playCount: Int32
}

@objc(SongEntity)
public class Song: NSManagedObject {
    @NSManaged public var title: String?
    @NSManaged public var artist: String?
    @NSManaged public var duration: Double
    @NSManaged public var positionInTape: Int16
    @NSManaged public var mixtape: MixTape?
    @NSManaged public var audioFeatures: Data?
    @NSManaged public var moodTag: String?
    @NSManaged public var playCount: Int32
}

// MARK: - Audio Features Model
struct AudioFeatures: Codable {
    let tempo: Float
    let energy: Float
    let valence: Float
}