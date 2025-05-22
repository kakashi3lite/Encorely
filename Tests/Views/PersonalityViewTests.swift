import XCTest
import SwiftUI
import ViewInspector
@testable import AIMixtapes

class PersonalityViewTests: XCTestCase {
    var personalityEngine: PersonalityEngine!
    
    override func setUp() {
        super.setUp()
        personalityEngine = PersonalityEngine()
    }
    
    override func tearDown() {
        personalityEngine = nil
        super.tearDown()
    }
    
    func testPersonalityViewInitialState() throws {
        let view = PersonalityView(personalityEngine: personalityEngine)
        
        let inspectedView = try view.inspect()
        XCTAssertTrue(try inspectedView.find(text: "Your Music Personality").isVisible())
        XCTAssertFalse(try inspectedView.find(viewWithId: "loadingIndicator").isVisible())
    }
    
    func testPersonalityAnalysis() throws {
        let view = PersonalityView(personalityEngine: personalityEngine)
        
        try assertLoadingState(in: view) {
            let listeningHistory = MockData.createListeningHistory()
            _ = try await personalityEngine.analyzePersonality(from: listeningHistory)
        }
    }
    
    func testPersonalityTraits() throws {
        let view = PersonalityView(personalityEngine: personalityEngine)
        
        // Simulate personality analysis
        let listeningHistory = MockData.createListeningHistory()
        let personality = personalityEngine.predictPersonality(from: listeningHistory)
        
        waitForUIUpdate()
        
        // Verify traits display
        let traitsList = try view.inspect().find(viewWithId: "personalityTraits")
        XCTAssertTrue(traitsList.isVisible())
        
        // Verify trait details
        for trait in personality.traits {
            let traitView = try traitsList.find(text: trait.name)
            XCTAssertTrue(traitView.isVisible())
        }
    }
    
    func testErrorHandling() throws {
        let view = PersonalityView(personalityEngine: personalityEngine)
        
        try assertErrorState(in: view) {
            throw AppError.analysisError(message: "Test error")
        }
    }
    
    func testAccessibility() throws {
        let view = PersonalityView(personalityEngine: personalityEngine)
        
        // Test main heading accessibility
        try assertAccessibility(
            of: view,
            label: "Your Music Personality",
            hint: "Shows your music personality analysis"
        )
        
        // Test traits accessibility
        let traits = personalityEngine.traits
        for trait in traits {
            try assertAccessibility(
                of: view,
                label: trait.name,
                hint: "Personality trait: \(trait.description)"
            )
        }
    }
    
    func testPerformance() throws {
        let view = PersonalityView(personalityEngine: personalityEngine)
        measureViewPerformance(of: view)
    }
    
    func testDataRefresh() throws {
        let view = PersonalityView(personalityEngine: personalityEngine)
        
        let refreshButton = try view.inspect().find(button: "Refresh")
        XCTAssertNotNil(refreshButton)
        
        try assertLoadingState(in: view) {
            try refreshButton.tap()
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    
    func testPersonalityColorTheme() throws {
        let view = PersonalityView(personalityEngine: personalityEngine)
        
        // Test color theme changes based on personality
        let personalities: [PersonalityType] = [.enthusiast, .curator, .explorer]
        
        for personality in personalities {
            personalityEngine.currentPersonality = personality
            waitForUIUpdate()
            
            let backgroundColor = try view.inspect().find(ViewType.Shape.self).fillStyle().foregroundColor
            XCTAssertEqual(backgroundColor, Asset.PersonalityColor(personality).color)
        }
    }
    
    func testChartAnimations() throws {
        let view = PersonalityView(personalityEngine: personalityEngine)
        
        // Test chart value animations
        let chart = try view.inspect().find(viewWithId: "personalityChart")
        XCTAssertNotNil(chart)
        
        // Simulate data update
        personalityEngine.updateTraits(MockData.createTraits())
        
        waitForUIUpdate()
        let updatedChart = try view.inspect().find(viewWithId: "personalityChart")
        XCTAssertNotEqual(chart, updatedChart)
    }
    
    func testInsightsDisplay() throws {
        let view = PersonalityView(personalityEngine: personalityEngine)
        
        // Get personality insights
        let insights = personalityEngine.getInsights()
        
        // Verify insights display
        let insightsView = try view.inspect().find(viewWithId: "personalityInsights")
        XCTAssertTrue(insightsView.isVisible())
        
        for insight in insights {
            let insightText = try insightsView.find(text: insight.title)
            XCTAssertTrue(insightText.isVisible())
        }
    }
}
