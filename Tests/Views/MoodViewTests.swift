import XCTest
import SwiftUI
import ViewInspector
@testable import App

class MoodViewTests: XCTestCase {
    var moodEngine: MoodEngine!
    var colorManager: ColorTransitionManager!
    
    override func setUp() {
        super.setUp()
        moodEngine = MoodEngine()
        colorManager = ColorTransitionManager()
    }
    
    override func tearDown() {
        moodEngine = nil
        colorManager = nil
        super.tearDown()
    }
    
    func testMoodViewInitialState() throws {
        let view = MoodView(moodEngine: moodEngine)
        
        let inspectedView = try view.inspect()
        XCTAssertTrue(try inspectedView.find(text: "Current Mood").isVisible())
        XCTAssertFalse(try inspectedView.find(viewWithId: "loadingIndicator").isVisible())
    }
    
    func testMoodSelection() throws {
        let view = MoodView(moodEngine: moodEngine)
        
        // Find and tap mood button
        let happyButton = try view.inspect().find(button: "Happy")
        try happyButton.tap()
        
        // Verify mood update
        let currentMood = moodEngine.currentMood
        XCTAssertEqual(currentMood, .happy)
        
        // Verify color transition
        waitForUIUpdate()
        let backgroundColor = try view.inspect().find(ViewType.Shape.self).fillStyle().foregroundColor
        XCTAssertEqual(backgroundColor, Asset.MoodColor.happy.color)
    }
    
    func testMoodAnalysis() throws {
        let view = MoodView(moodEngine: moodEngine)
        
        try assertLoadingState(in: view) {
            try await moodEngine.analyzeMood(from: "test_audio.mp3")
        }
    }
    
    func testErrorHandling() throws {
        let view = MoodView(moodEngine: moodEngine)
        
        try assertErrorState(in: view) {
            try await moodEngine.analyzeMood(from: "nonexistent.mp3")
        }
    }
    
    func testAccessibility() throws {
        let view = MoodView(moodEngine: moodEngine)
        
        // Test mood buttons accessibility
        for mood in Asset.MoodColor.allCases {
            try assertAccessibility(
                of: view,
                label: mood.rawValue,
                hint: "Select \(mood.rawValue) mood"
            )
        }
        
        // Test current mood label accessibility
        try assertAccessibility(
            of: view,
            label: "Current Mood",
            hint: "Shows your current mood"
        )
    }
    
    func testPerformance() throws {
        let view = MoodView(moodEngine: moodEngine)
        measureViewPerformance(of: view)
    }
    
    func testAnimations() throws {
        let view = MoodView(moodEngine: moodEngine)
        
        try assertColorTransition(
            from: .happy,
            to: .energetic,
            in: view
        )
    }
    
    func testDynamicTypeSupport() throws {
        let view = MoodView(moodEngine: moodEngine)
        
        // Test different content size categories
        let contentSizes: [ContentSizeCategory] = [.small, .medium, .large, .extraLarge]
        
        for size in contentSizes {
            let environment = ViewInspector.Environment(\.sizeCategory, size)
            let sizedView = try view.inspect().environment(environment)
            
            // Verify text scales appropriately
            let titleText = try sizedView.find(text: "Current Mood")
            XCTAssertTrue(titleText.isVisible())
        }
    }
    
    func testColorSchemeAdaptation() throws {
        let view = MoodView(moodEngine: moodEngine)
        
        // Test light mode
        let lightEnv = ViewInspector.Environment(\.colorScheme, .light)
        let lightView = try view.inspect().environment(lightEnv)
        let lightBackground = try lightView.find(ViewType.Shape.self).fillStyle().foregroundColor
        
        // Test dark mode
        let darkEnv = ViewInspector.Environment(\.colorScheme, .dark)
        let darkView = try view.inspect().environment(darkEnv)
        let darkBackground = try darkView.find(ViewType.Shape.self).fillStyle().foregroundColor
        
        XCTAssertNotEqual(lightBackground, darkBackground)
    }
}
