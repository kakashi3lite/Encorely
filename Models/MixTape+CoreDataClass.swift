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
    
    // MARK: - Core Data Properties
    @NSManaged public var title: String?
    @NSManaged public var createdDate: Date
    @NSManaged public var mood: String?
    @NSManaged public var songs: NSSet?
    
    // MARK: - Computed Properties
    public var wrappedTitle: String {
        title ?? "Untitled Mixtape"
    }
    
    public var wrappedMood: String {
        mood ?? "neutral"
    }
    
    public var songsArray: [Song] {
        let set = songs as? Set<Song> ?? []
        return set.sorted {
            $0.wrappedTitle < $1.wrappedTitle
        }
    }
    
    public var songCount: Int {
        return songs?.count ?? 0
    }
    
    // MARK: - Methods
    public func addSong(_ song: Song) {
        let songs = self.mutableSetValue(forKey: "songs")
        songs.add(song)
        song.mixTape = self
    }
    
    public func removeSong(_ song: Song) {
        let songs = self.mutableSetValue(forKey: "songs")
        songs.remove(song)
        song.mixTape = nil
    }
    
    public func addSongs(_ songs: NSSet) {
        let mutableSongs = self.mutableSetValue(forKey: "songs")
        mutableSongs.union(songs as! Set<AnyHashable>)
    }
    
    public func removeSongs(_ songs: NSSet) {
        let mutableSongs = self.mutableSetValue(forKey: "songs")
        mutableSongs.minus(songs as! Set<AnyHashable>)
    }
}

// MARK: - Generated accessors for songs
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
