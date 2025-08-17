// filepath: Tests/AIMixtapesTests/AppIntentsSmokeTests.swift
import XCTest
@testable import App

final class AppIntentsSmokeTests: XCTestCase {
    func testStartMixIntentPerform() async throws {
        if #available(iOS 16.0, *) {
            let intent = StartMixIntent(mood: "Happy")
            _ = try await intent.perform()
        }
    }

    func testSwivelIntentPerform() async throws {
        if #available(iOS 16.0, *) {
            let intent = SwivelPodcastIntent(crossfade: 1.0)
            _ = try await intent.perform()
        }
    }
}
