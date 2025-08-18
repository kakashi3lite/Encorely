//
//  MixTape+CoreDataClass.swift
//  AI-Mixtapes
//
//  Created by AI Assistant on 05/17/25.
//

import CoreData
import Foundation

@objc(MixTape)
public class MixTape: NSManagedObject {
    // MARK: - Properties

    // Note: All @NSManaged properties are defined in MixTape+CoreDataProperties.swift

    // MARK: - Computed Properties

    var moodTagsArray: [String] {
        moodTags?.components(separatedBy: ", ") ?? []
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

    override public func awakeFromInsert() {
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
