//
//  Song+CoreDataClass.swift
//  AI-Mixtapes
//
//  Created by AI Assistant on 05/17/25.
//

import Foundation
import CoreData
import AVFoundation

@objc(Song)
public class Song: NSManagedObject {
    // MARK: - Properties
    @NSManaged public var name: String
    @NSManaged public var positionInTape: Int16
    @NSManaged public var urlData: Data
    @NSManaged public var mixTape: MixTape?
    @NSManaged public var audioFeatures: Data?
    @NSManaged public var moodTag: String?
    @NSManaged public var playCount: Int32

    // MARK: - Computed Properties
    var wrappedName: String {
        name
    }

    var wrappedUrl: URL {
        do {
            var isStale = false
            return try URL(resolvingBookmarkData: urlData, bookmarkDataIsStale: &isStale)
        } catch {
            print("Error resolving URL: \(error)")
            return URL(fileURLWithPath: "")
        }
    }

    // MARK: - Lifecycle
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        playCount = 0
    }

    // MARK: - Methods
    func trackPlay() {
        playCount += 1
    }

    func setAudioFeatures(_ features: AudioFeatures) throws {
        let encoder = JSONEncoder()
        audioFeatures = try encoder.encode(features)
    }

    func getAudioFeatures() -> AudioFeatures? {
        guard let data = audioFeatures else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(AudioFeatures.self, from: data)
    }
}
