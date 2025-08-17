//
//  Song+CoreDataClass.swift
//  AI-Mixtapes
//
//  Created by AI Assistant on 05/17/25.
//

import AVFoundation
import CoreData
import Foundation

@objc(Song)
public class Song: NSManagedObject {
    // MARK: - Properties

    // Note: All @NSManaged properties (name, positionInTape, urlData, mixTape, audioFeatures, moodTag, playCount) are
    // defined in Song+CoreDataProperties.swift

    // MARK: - Computed Properties

    var wrappedName: String {
        name
    }

    var wrappedUrl: URL {
        guard let data = urlData else {
            return URL(fileURLWithPath: "")
        }
        do {
            var isStale = false
            return try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
        } catch {
            print("Error resolving URL: \(error)")
            return URL(fileURLWithPath: "")
        }
    }
    
    var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Lifecycle

    override public func awakeFromInsert() {
        super.awakeFromInsert()
        playCount = 0
    }

    // MARK: - Methods

    func trackPlay() {
        playCount += 1
    }

    func setAudioFeatures(_ features: AudioFeatures) {
        let encoder = JSONEncoder()
        do {
            audioFeatures = try encoder.encode(features)
        } catch {
            print("Failed to encode audio features: \(error)")
            audioFeatures = nil
        }
    }

    func getAudioFeatures() -> AudioFeatures? {
        guard let data = audioFeatures else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(AudioFeatures.self, from: data)
    }
}
