import CoreData
import Foundation

extension MixTape: MixTapeModel {
    public var title: String {
        wrappedTitle
    }

    public var numberOfSongs: Int {
        Int(numberOfSongs)
    }

    public var moodTags: [String] {
        moodTagsArray
    }

    public var audioFeatures: [String: AudioFeatures] {
        // Get audio features for each song
        var features: [String: AudioFeatures] = [:]
        for song in songsArray {
            if let audioFeature = song.getAudioFeatures() {
                features[song.wrappedName] = audioFeature
            }
        }
        return features
    }

    public var songs: [SongModel] {
        songsArray
    }
}
