//
//  Song+CoreDataClass.swift
//  AI-Mixtapes
//
//  Created by AI Assistant on 05/17/25.
//

import Foundation
import CoreData

@objc(Song)
public class Song: NSManagedObject {
    
    // MARK: - Core Data Properties
    @NSManaged public var title: String?
    @NSManaged public var artist: String?
    @NSManaged public var duration: Double
    @NSManaged public var mixTape: MixTape?
    
    // MARK: - Computed Properties
    public var wrappedTitle: String {
        title ?? "Unknown Song"
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
        return "\(wrappedTitle) - \(wrappedArtist)"
    }
    
    // MARK: - Methods
    public func setMixTape(_ mixtape: MixTape?) {
        // Remove from current mixtape if exists
        if let currentMixTape = self.mixTape {
            currentMixTape.removeFromSongs(self)
        }
        
        // Set new mixtape
        self.mixTape = mixtape
        
        // Add to new mixtape if exists
        if let newMixTape = mixtape {
            newMixTape.addToSongs(self)
        }
    }
}
