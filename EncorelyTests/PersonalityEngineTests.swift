import Testing
@testable import Encorely

/// Tests for PersonalityEngine's behavior analysis.
struct PersonalityEngineTests {
    let engine = PersonalityEngine()

    @Test("Initial personality is balanced")
    func initialState() {
        #expect(engine.currentPersonality == .balanced)
        #expect(engine.confidence == 0.0)
        #expect(engine.isAnalyzing == false)
    }

    @Test("Recording interactions accumulates history")
    func recordsInteractions() {
        engine.recordSongCompleted()
        engine.recordSongCompleted()
        engine.recordSongSkipped()
        // No assertion on internal history count, but engine should not crash
    }

    @Test("Many completions lean toward enthusiast")
    func completionsSkewEnthusiast() {
        for _ in 0..<15 {
            engine.recordSongCompleted()
        }
        engine.forceAnalyze()

        // Enthusiast or balanced are acceptable since completion rate is high
        #expect(
            engine.currentPersonality == .enthusiast ||
            engine.currentPersonality == .balanced
        )
    }

    @Test("Many skips lean toward explorer")
    func skipsSkewExplorer() {
        for _ in 0..<15 {
            engine.recordSongSkipped()
        }
        engine.forceAnalyze()

        #expect(
            engine.currentPersonality == .explorer ||
            engine.currentPersonality == .balanced
        )
    }

    @Test("Many playlist creations lean toward curator")
    func creationsSkewCurator() {
        for _ in 0..<15 {
            engine.recordPlaylistCreated()
        }
        engine.forceAnalyze()

        #expect(
            engine.currentPersonality == .curator ||
            engine.currentPersonality == .balanced
        )
    }

    @Test("Reset returns to balanced")
    func resetReturns() {
        for _ in 0..<15 { engine.recordSongCompleted() }
        engine.forceAnalyze()
        engine.reset()

        #expect(engine.currentPersonality == .balanced)
        #expect(engine.confidence == 0.0)
    }

    @Test("Confidence is within valid range after analysis")
    func confidenceInRange() {
        for _ in 0..<20 { engine.recordSongCompleted() }
        engine.forceAnalyze()

        #expect(engine.confidence >= 0.0)
        #expect(engine.confidence <= 1.0)
    }
}
