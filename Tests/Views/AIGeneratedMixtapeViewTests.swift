import XCTest
import SwiftUI
import ViewInspector
@testable import App

class AIGeneratedMixtapeViewTests: XCTestCase {
    var aiService: AIIntegrationService!
    var moodEngine: MoodEngine!
    var personalityEngine: PersonalityEngine!
    
    override func setUp() {
        super.setUp()
        aiService = AIIntegrationService()
        moodEngine = MoodEngine()
        personalityEngine = PersonalityEngine()
    }
    
    override func tearDown() {
        aiService = nil
        moodEngine = nil
        personalityEngine = nil
        super.tearDown()
    }
    
    func testInitialState() throws {
        let view = AIGeneratedMixtapeView(
            aiService: aiService,
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        let inspectedView = try view.inspect()
        XCTAssertTrue(try inspectedView.find(text: "AI-Generated Mixtape").isVisible())
        XCTAssertFalse(try inspectedView.find(viewWithId: "loadingIndicator").isVisible())
    }
    
    func testMixtapeGeneration() throws {
        let view = AIGeneratedMixtapeView(
            aiService: aiService,
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        try assertLoadingState(in: view) {
            try await aiService.generateMixtape(mood: .happy, length: 10)
        }
        
        // Verify mixtape content
        let songList = try view.inspect().find(viewWithId: "songList")
        XCTAssertTrue(songList.isVisible())
        XCTAssertEqual(try songList.count, 10)
    }
    
    func testMoodSelection() throws {
        let view = AIGeneratedMixtapeView(
            aiService: aiService,
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        // Test mood picker
        let moodPicker = try view.inspect().find(viewWithId: "moodPicker")
        XCTAssertTrue(moodPicker.isVisible())
        
        // Select different moods
        for mood in Asset.MoodColor.allCases {
            try moodPicker.view(Picker<Text, Asset.MoodColor, ForEach>.self).select(value: mood)
            waitForUIUpdate()
            
            // Verify mood update
            XCTAssertEqual(moodEngine.currentMood, mood)
        }
    }
    
    func testProgressIndicators() throws {
        let view = AIGeneratedMixtapeView(
            aiService: aiService,
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        // Start generation
        let generateButton = try view.inspect().find(button: "Generate")
        try generateButton.tap()
        
        // Verify progress indicators
        let progress = try view.inspect().find(viewWithId: "generationProgress")
        XCTAssertTrue(progress.isVisible())
        
        // Test progress updates
        for step in ["Analyzing Mood", "Personalizing", "Generating"] {
            let stepText = try view.inspect().find(text: step)
            XCTAssertTrue(stepText.isVisible())
        }
    }
    
    func testErrorHandling() throws {
        let view = AIGeneratedMixtapeView(
            aiService: aiService,
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        try assertErrorState(in: view) {
            throw AppError.generationError(message: "Failed to generate mixtape")
        }
        
        // Verify retry button
        let retryButton = try view.inspect().find(button: "Try Again")
        XCTAssertTrue(retryButton.isVisible())
    }
    
    func testAccessibility() throws {
        let view = AIGeneratedMixtapeView(
            aiService: aiService,
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        // Test main controls accessibility
        try assertAccessibility(
            of: view,
            label: "Generate Mixtape",
            hint: "Create a new AI-generated mixtape"
        )
        
        try assertAccessibility(
            of: view.inspect().find(viewWithId: "moodPicker"),
            label: "Select Mood",
            hint: "Choose the mood for your mixtape"
        )
        
        try assertAccessibility(
            of: view.inspect().find(viewWithId: "lengthPicker"),
            label: "Mixtape Length",
            hint: "Choose how many songs to include"
        )
    }
    
    func testPerformance() throws {
        let view = AIGeneratedMixtapeView(
            aiService: aiService,
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        // Test generation performance
        measure {
            let expectation = XCTestExpectation(description: "Mixtape Generation")
            
            Task {
                try await aiService.generateMixtape(mood: .happy, length: 5)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testSaveAndShare() throws {
        let view = AIGeneratedMixtapeView(
            aiService: aiService,
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        // Generate mixtape
        try await aiService.generateMixtape(mood: .happy, length: 5)
        
        // Test save button
        let saveButton = try view.inspect().find(button: "Save Mixtape")
        XCTAssertTrue(saveButton.isVisible())
        try saveButton.tap()
        
        // Verify save confirmation
        let confirmation = try view.inspect().find(text: "Mixtape Saved!")
        XCTAssertTrue(confirmation.isVisible())
        
        // Test share button
        let shareButton = try view.inspect().find(button: "Share")
        XCTAssertTrue(shareButton.isVisible())
        try shareButton.tap()
        
        // Verify share sheet
        let shareSheet = try view.inspect().find(viewWithId: "shareSheet")
        XCTAssertTrue(shareSheet.isVisible())
    }
    
    func testPersonalizationOptions() throws {
        let view = AIGeneratedMixtapeView(
            aiService: aiService,
            moodEngine: moodEngine,
            personalityEngine: personalityEngine
        )
        
        // Test personalization settings
        let settingsButton = try view.inspect().find(button: "Personalization Settings")
        XCTAssertTrue(settingsButton.isVisible())
        try settingsButton.tap()
        
        // Verify settings panel
        let settingsPanel = try view.inspect().find(viewWithId: "personalizationPanel")
        XCTAssertTrue(settingsPanel.isVisible())
        
        // Test settings controls
        let genreToggle = try settingsPanel.find(toggle: "Consider Genre Preferences")
        XCTAssertTrue(genreToggle.isVisible())
        
        let energySlider = try settingsPanel.find(slider: "Energy Level")
        XCTAssertTrue(energySlider.isVisible())
    }
}
