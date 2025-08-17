import SwiftUI
import ViewInspector
import XCTest
@testable import App

class StateManagementTests: XCTestCase {
    var playerManager: PlayerManager!
    var aiService: AIIntegrationService!
    var networkManager: NetworkStateManager!

    override func setUp() {
        super.setUp()
        playerManager = PlayerManager()
        aiService = AIIntegrationService()
        networkManager = NetworkStateManager.shared
        networkManager.reset()
    }

    override func tearDown() {
        playerManager = nil
        aiService = nil
        networkManager.reset()
        super.tearDown()
    }

    // MARK: - Offline Mode Tests

    func testOfflineModePlayback() throws {
        // Set up offline mode
        networkManager.setOfflineMode(true)

        // Create a mixtape view
        let mixtape = TestSupport.createMockMixTape(in: TestSupport.createInMemoryContainer().viewContext)
        let view = MixTapeView(mixtape: mixtape, playerManager: playerManager)

        // Verify offline indicator is visible
        let offlineIndicator = try view.inspect().find(viewWithId: "offlineIndicator")
        XCTAssertTrue(offlineIndicator.isVisible())

        // Test playback in offline mode
        let playButton = try view.inspect().find(button: "Play")
        try playButton.tap()

        // Verify playback works with cached content
        XCTAssertTrue(playerManager.isPlaying)
        XCTAssertNotNil(playerManager.currentSong)
    }

    func testOfflineModeDataPersistence() throws {
        // Generate and cache some data
        let personalityEngine = PersonalityEngine()
        let initialPreferences = personalityEngine.getPreferences()

        // Enable offline mode
        networkManager.setOfflineMode(true)

        // Verify data is still accessible
        let persistedPreferences = personalityEngine.getPreferences()
        XCTAssertEqual(initialPreferences, persistedPreferences)
    }

    func testOfflineSyncQueue() async throws {
        // Set up offline changes
        networkManager.setOfflineMode(true)

        let mixtape = TestSupport.createMockMixTape(in: TestSupport.createInMemoryContainer().viewContext)
        mixtape.title = "Updated Offline"

        // Queue changes for sync
        aiService.queueForSync(mixtape)

        // Return to online mode
        networkManager.setOfflineMode(false)

        // Verify changes are synced
        let syncExpectation = expectation(description: "Sync completed")

        Task {
            try await aiService.syncQueuedChanges()
            syncExpectation.fulfill()
        }

        await fulfillment(of: [syncExpectation], timeout: 5.0)

        // Verify changes persisted
        XCTAssertEqual(mixtape.title, "Updated Offline")
    }

    // MARK: - Error State Tests

    func testNetworkErrorRecovery() async throws {
        // Simulate network error
        networkManager.simulateNetworkError(
            for: "generateMixtape",
            error: AppError.networkError(message: "Connection failed"))

        let view = AIGeneratedMixtapeView(
            aiService: aiService,
            moodEngine: MoodEngine(),
            personalityEngine: PersonalityEngine())

        // Attempt operation
        let generateButton = try view.inspect().find(button: "Generate")
        try generateButton.tap()

        // Verify error state
        let errorView = try view.inspect().find(viewWithId: "errorView")
        XCTAssertTrue(errorView.isVisible())

        // Clear error and retry
        networkManager.clearNetworkErrors()
        let retryButton = try errorView.find(button: "Retry")
        try retryButton.tap()

        // Verify recovery
        waitForUIUpdate(2.0)
        XCTAssertFalse(try view.inspect().find(viewWithId: "errorView").isVisible())
    }

    func testErrorStateUI() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)

        // Simulate error
        let error = AppError.analysisError(message: "Analysis failed")

        let errorView = try view.inspect().find(viewWithId: "errorView")
        XCTAssertTrue(try errorView.find(text: error.localizedDescription).isVisible())
        XCTAssertTrue(try errorView.find(button: "Retry").isVisible())
    }

    func testErrorRecoveryFlow() async throws {
        let view = MixTapeView(
            mixtape: TestSupport.createMockMixTape(in: TestSupport.createInMemoryContainer().viewContext),
            playerManager: playerManager)

        // Simulate playback error
        networkManager.simulateNetworkError(
            for: "playback",
            error: AppError.playbackError(message: "Stream failed"))

        // Start playback
        try view.inspect().find(button: "Play").tap()

        // Verify error state
        let errorView = try view.inspect().find(viewWithId: "errorView")
        XCTAssertTrue(errorView.isVisible())

        // Test automatic retry
        networkManager.clearNetworkErrors()
        try errorView.find(button: "Retry").tap()

        waitForUIUpdate()
        XCTAssertTrue(playerManager.isPlaying)
    }

    // MARK: - State Management Tests

    func testStatePreservationAcrossViews() throws {
        let moodEngine = MoodEngine()
        let personalityEngine = PersonalityEngine()

        // Set initial state
        moodEngine.setMood(.happy, confidence: 0.9)
        personalityEngine.updatePersonality(.enthusiast)

        // Create views
        let moodView = MoodView(moodEngine: moodEngine)
        let personalityView = PersonalityView(personalityEngine: personalityEngine)

        // Navigate between views
        let tabView = MainTabView()
        try tabView.inspect().tabView().select(0) // Mood tab
        try tabView.inspect().tabView().select(2) // Personality tab

        // Verify state is preserved
        XCTAssertEqual(moodEngine.currentMood, .happy)
        XCTAssertEqual(personalityEngine.currentPersonality, .enthusiast)
    }

    func testStateRestoration() throws {
        // Save state
        let initialState = PlayerManager.State(
            isPlaying: true,
            currentSong: TestSupport.createMockSong(in: TestSupport.createInMemoryContainer().viewContext),
            volume: 0.8)
        playerManager.saveState(initialState)

        // Simulate app restart
        playerManager = PlayerManager()

        // Verify state restoration
        let restoredState = playerManager.currentState
        XCTAssertEqual(restoredState.isPlaying, initialState.isPlaying)
        XCTAssertEqual(restoredState.currentSong?.id, initialState.currentSong?.id)
        XCTAssertEqual(restoredState.volume, initialState.volume)
    }

    func testConcurrentStateModification() async throws {
        let mixtape = TestSupport.createMockMixTape(in: TestSupport.createInMemoryContainer().viewContext)
        let view = MixTapeView(mixtape: mixtape, playerManager: playerManager)

        // Simulate concurrent modifications
        async let task1 = playerManager.play(mixtape.songs?.first as? Song)
        async let task2 = playerManager.updateVolume(0.5)
        async let task3 = playerManager.seekTo(0.3)

        // Wait for all tasks
        _ = try await [task1, task2, task3]

        // Verify state consistency
        XCTAssertTrue(playerManager.isPlaying)
        XCTAssertEqual(playerManager.volume, 0.5)
        XCTAssertEqual(playerManager.currentProgress, 0.3)
    }
}
