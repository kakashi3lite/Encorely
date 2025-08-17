// filepath: Tests/AIMixtapesTests/BigFiveProfileTests.swift
import XCTest
@testable import App

final class BigFiveProfileTests: XCTestCase {
    func testMappingAndWeights() throws {
        let profile = BigFiveProfile(openness: 0.8, conscientiousness: 0.4, extraversion: 0.7, agreeableness: 0.6, neuroticism: 0.2)
        // Mapping
        let persona = profile.mappedPersonalityType
        XCTAssertEqual(persona, .explorer)
        // Weights in range
        let w = profile.audioPreferenceWeights
        for v in [w.energy, w.complexity, w.tempo, w.acousticness] {
            XCTAssertGreaterThanOrEqual(v, 0.0)
            XCTAssertLessThanOrEqual(v, 1.0)
        }
    }
}
