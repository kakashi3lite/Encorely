//
//  MixTape+CoreDataClass.swift
//  AI-Mixtapes
//
//  Created by AI Assistant on 05/17/25.
//

import Foundation
import CoreData

@objc(MixTape)
public class MixTape: NSManagedObject {
    // MARK: - Properties
    
    @NSManaged public var title: String
    @NSManaged public var numberOfSongs: Int16
    @NSManaged public var urlData: Data?
    @NSManaged public var aiGenerated: Bool
    @NSManaged public var moodTags: String?
    @NSManaged public var lastPlayedDate: Date?
    @NSManaged public var playCount: Int32
    @NSManaged public var createdDate: Date
    @NSManaged public var songs: NSOrderedSet?
    
    // MARK: - Computed Properties
    
    var songsArray: [Song] {
        let set = songs ?? NSOrderedSet()
        return set.array as? [Song] ?? []
    }
    
    var moodTagsArray: [String] {
        return moodTags?.components(separatedBy: ", ") ?? []
    }
    
    var wrappedTitle: String {
        title
    }
    
    var wrappedUrl: URL {
        if let data = urlData {
            do {
                var isStale = false
                return try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
            } catch {
                print("Error resolving URL: \(error)")
                return URL(fileURLWithPath: "")
            }
        }
        return URL(fileURLWithPath: "")
    }
    
    // MARK: - Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        createdDate = Date()
        aiGenerated = false
        playCount = 0
    }
    
    // MARK: - Methods
    
    func trackPlay() {
        playCount += 1
        lastPlayedDate = Date()
    }
    
    func addSong(_ song: Song) {
        var currentSongs = songsArray
        currentSongs.append(song)
        songs = NSOrderedSet(array: currentSongs)
        numberOfSongs = Int16(currentSongs.count)
    }
    
    func removeSong(_ song: Song) {
        var currentSongs = songsArray
        if let index = currentSongs.firstIndex(of: song) {
            currentSongs.remove(at: index)
            songs = NSOrderedSet(array: currentSongs)
            numberOfSongs = Int16(currentSongs.count)
        }
    }
}
