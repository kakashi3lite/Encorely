import XCTest
@testable import AI_Mixtapes

enum TestSupport {
    // MARK: - Core Data Support

    static func createInMemoryContainer() -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "AI_Mixtapes")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to create in-memory Core Data stack: \(error)")
            }
        }

        return container
    }

    // MARK: - Mock Data Generation

    static func createMockMixTape(in context: NSManagedObjectContext) -> MixTape {
        let mixtape = MixTape(context: context)
        mixtape.title = "Test Mixtape"
        mixtape.numberOfSongs = 0
        mixtape.createdDate = Date()
        mixtape.moodTags = "happy,energetic"
        mixtape.aiGenerated = true
        return mixtape
    }

    static func createMockSong(in context: NSManagedObjectContext) -> Song {
        let song = Song(context: context)
        song.name = "Test Song"
        song.positionInTape = 0
        song.moodTag = "happy"
        return song
    }

    // MARK: - Mock Audio Data

    static func createMockAudioFeatures() -> AudioFeatures {
        AudioFeatures(
            tempo: 120.0,
            energy: 0.8,
            spectralCentroid: 0.6,
            valence: 0.7,
            danceability: 0.9,
            acousticness: 0.3,
            instrumentalness: 0.4,
            speechiness: 0.1,
            liveness: 0.2)
    }

    // MARK: - Mock Network Data

    static func mockAnthropicResponse(content: String) -> Data {
        let response = [
            "model": "claude-3-7-sonnet-20250219",
            "messages": [
                ["role": "assistant", "content": content],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: response)
    }
}
