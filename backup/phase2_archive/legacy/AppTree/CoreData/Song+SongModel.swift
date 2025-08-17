import CoreData
import Foundation

extension Song: SongModel {
    public var name: String {
        wrappedName
    }

    public var duration: TimeInterval {
        // This would be implemented based on actual audio duration
        0
    }

    public var url: URL {
        wrappedUrl
    }

    public var audioFeatures: AudioFeatures? {
        getAudioFeatures()
    }

    public var moodTag: String? {
        self.moodTag
    }
}
