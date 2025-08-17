// filepath: Tests/AIMixtapesTests/PerceptionFusionTests.swift
import XCTest
@testable import App

final class PerceptionFusionTests: XCTestCase {
    func testFusionResponds() throws {
        let face = FaceAffectAnalyzer()
        let sound = SoundEnvironmentAnalyzer()
        let fusion = MoodFusionEngine(face: face, sound: sound)

        let exp = expectation(description: "fusion update")
        var received: MoodFusionEngine.MoodState?
        let cancellable = fusion.publisher.sink { state in
            received = state
            if state.source == "fusion" { exp.fulfill() }
        }

        face.update(blendShapes: ["mouthSmile_L": 0.6, "mouthSmile_R": 0.6])
        sound.update(.music)

        wait(for: [exp], timeout: 1.0)
        XCTAssertNotNil(received)
        XCTAssertGreaterThan(received!.valence, 0.5)
        _ = cancellable
    }
}
