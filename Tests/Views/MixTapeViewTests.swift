import XCTest
import SwiftUI
import ViewInspector
@testable import AIMixtapes

class MixTapeViewTests: XCTestCase {
    var mixtape: MixTape!
    var playerManager: PlayerManager!
    
    override func setUp() {
        super.setUp()
        let context = TestSupport.createInMemoryContainer().viewContext
        mixtape = TestSupport.createMockMixTape(in: context)
        playerManager = PlayerManager()
    }
    
    override func tearDown() {
        mixtape = nil
        playerManager = nil
        super.tearDown()
    }
    
    func testMixTapeViewInitialState() throws {
        let view = MixTapeView(mixtape: mixtape, playerManager: playerManager)
        
        let inspectedView = try view.inspect()
        XCTAssertTrue(try inspectedView.find(text: mixtape.title ?? "").isVisible())
        XCTAssertFalse(try inspectedView.find(viewWithId: "playingIndicator").isVisible())
    }
    
    func testPlayback() throws {
        let view = MixTapeView(mixtape: mixtape, playerManager: playerManager)
        
        // Test play button
        let playButton = try view.inspect().find(button: "Play")
        try playButton.tap()
        
        waitForUIUpdate()
        XCTAssertTrue(playerManager.isPlaying)
        
        // Test pause button
        let pauseButton = try view.inspect().find(button: "Pause")
        try pauseButton.tap()
        
        waitForUIUpdate()
        XCTAssertFalse(playerManager.isPlaying)
    }
    
    func testProgressBar() throws {
        let view = MixTapeView(mixtape: mixtape, playerManager: playerManager)
        
        let progressBar = try view.inspect().find(slider: "Progress")
        XCTAssertNotNil(progressBar)
        
        // Test progress updates
        try playButton.tap()
        waitForUIUpdate(2.0) // Wait for some playback
        
        let progress = try progressBar.value().cgFloat()
        XCTAssertGreaterThan(progress, 0)
    }
    
    func testSongNavigation() throws {
        let view = MixTapeView(mixtape: mixtape, playerManager: playerManager)
        
        // Start playback
        try view.inspect().find(button: "Play").tap()
        
        // Test next button
        let nextButton = try view.inspect().find(button: "Next")
        try nextButton.tap()
        waitForUIUpdate()
        XCTAssertEqual(playerManager.currentIndex, 1)
        
        // Test previous button
        let prevButton = try view.inspect().find(button: "Previous")
        try prevButton.tap()
        waitForUIUpdate()
        XCTAssertEqual(playerManager.currentIndex, 0)
    }
    
    func testErrorHandling() throws {
        let view = MixTapeView(mixtape: mixtape, playerManager: playerManager)
        
        try assertErrorState(in: view) {
            playerManager.currentURL = URL(string: "invalid://url")
            try await playerManager.play()
        }
    }
    
    func testAccessibility() throws {
        let view = MixTapeView(mixtape: mixtape, playerManager: playerManager)
        
        // Test playback controls accessibility
        try assertAccessibility(
            of: view,
            label: "Play",
            hint: "Play mixtape"
        )
        
        try assertAccessibility(
            of: view,
            label: "Next",
            hint: "Play next song"
        )
        
        try assertAccessibility(
            of: view,
            label: "Previous",
            hint: "Play previous song"
        )
        
        // Test progress bar accessibility
        try assertAccessibility(
            of: view,
            label: "Progress",
            hint: "Adjust playback position"
        )
    }
    
    func testPerformance() throws {
        let view = MixTapeView(mixtape: mixtape, playerManager: playerManager)
        measureViewPerformance(of: view)
    }
    
    func testBackgroundPlayback() throws {
        let view = MixTapeView(mixtape: mixtape, playerManager: playerManager)
        
        // Start playback
        try view.inspect().find(button: "Play").tap()
        
        // Simulate background state
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        waitForUIUpdate()
        XCTAssertTrue(playerManager.isPlaying)
        
        // Simulate foreground state
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        
        waitForUIUpdate()
        XCTAssertTrue(playerManager.isPlaying)
    }
    
    func testVolumeControl() throws {
        let view = MixTapeView(mixtape: mixtape, playerManager: playerManager)
        
        let volumeSlider = try view.inspect().find(slider: "Volume")
        XCTAssertNotNil(volumeSlider)
        
        // Test volume adjustment
        try volumeSlider.slider.setValue(0.5)
        XCTAssertEqual(playerManager.volume, 0.5)
    }
}
