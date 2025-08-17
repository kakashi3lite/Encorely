import CoreData
import Foundation

// MARK: - Model Definitions

enum Mood: String, CaseIterable, Codable {
    case energetic, relaxed, happy, melancholic, focused, romantic, angry, neutral

    var keywords: [String] {
        switch self {
        case .energetic: ["upbeat", "energetic", "fast", "party"]
        case .relaxed: ["chill", "calm", "peaceful", "relax"]
        case .happy: ["happy", "joy", "fun", "cheerful"]
        case .melancholic: ["sad", "blue", "melancholy", "lonely"]
        case .focused: ["focus", "study", "concentrate", "work"]
        case .romantic: ["love", "romance", "slow", "intimate"]
        case .angry: ["angry", "rage", "intense", "heavy"]
        case .neutral: ["neutral", "balanced", "moderate"]
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
// AudioFeatures moved to App/Consolidated/AudioFeatures.swift to avoid duplication
