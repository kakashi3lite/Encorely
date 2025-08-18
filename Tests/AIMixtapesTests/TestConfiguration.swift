import XCTest

class TestConfiguration {
    static let shared = TestConfiguration()

    // Test resources
    let testAudioURL = Bundle.module.url(
        forResource: "test_audio",
        withExtension: "mp3",
        subdirectory: "TestResources"
    )!
    let testImageURL = Bundle.module.url(
        forResource: "test_image",
        withExtension: "jpg",
        subdirectory: "TestResources"
    )!

    // Test parameters
    let timeout: TimeInterval = 5.0
    let bufferSize = 2048
    let sampleRate: Double = 44100

    // Mock data
    func createMockAudioFeatures() -> AudioFeatures {
        AudioFeatures(
            energy: 0.7,
            valence: 0.8,
            intensity: 0.6,
            complexity: 0.5,
            brightness: 0.7,
            warmth: 0.4
        )
    }

    func createMockListeningHistory() -> [String: Any] {
        [
            "genres": ["rock": 0.6, "jazz": 0.3, "classical": 0.1],
            "timeOfDay": ["morning": 0.3, "afternoon": 0.4, "evening": 0.3],
            "tempo": ["slow": 0.2, "medium": 0.5, "fast": 0.3],
        ]
    }
}
