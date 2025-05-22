import XCTest
import SwiftUI
import ViewInspector
@testable import AIMixtapes

class InsightsDashboardViewTests: XCTestCase {
    var aiService: AIIntegrationService!
    var playerManager: PlayerManager!
    
    override func setUp() {
        super.setUp()
        aiService = AIIntegrationService()
        playerManager = PlayerManager()
    }
    
    override func tearDown() {
        aiService = nil
        playerManager = nil
        super.tearDown()
    }
    
    func testDashboardInitialState() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)
        
        let inspectedView = try view.inspect()
        XCTAssertTrue(try inspectedView.find(text: "Your Music Insights").isVisible())
        XCTAssertFalse(try inspectedView.find(viewWithId: "loadingIndicator").isVisible())
    }
    
    func testInsightsLoading() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)
        
        try assertLoadingState(in: view) {
            try await aiService.generateInsights()
        }
    }
    
    func testInsightCategories() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)
        
        let categories = try view.inspect().find(viewWithId: "insightCategories")
        XCTAssertTrue(categories.isVisible())
        
        // Test each category
        let expectedCategories = ["Listening Habits", "Genre Preferences", "Mood Patterns", "Discovery"]
        for category in expectedCategories {
            let categoryView = try categories.find(button: category)
            XCTAssertTrue(categoryView.isVisible())
        }
    }
    
    func testChartInteractions() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)
        
        // Test chart selection
        let charts = try view.inspect().find(viewWithId: "insightCharts")
        XCTAssertTrue(charts.isVisible())
        
        let firstChart = try charts.view(ChartView.self, 0)
        try firstChart.callOnTapGesture()
        
        // Verify detail view appears
        let detailView = try view.inspect().find(viewWithId: "chartDetail")
        XCTAssertTrue(detailView.isVisible())
    }
    
    func testDataTimeRanges() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)
        
        let timeRangePicker = try view.inspect().find(viewWithId: "timeRangePicker")
        XCTAssertTrue(timeRangePicker.isVisible())
        
        // Test each time range
        let ranges = ["Week", "Month", "Year"]
        for range in ranges {
            try timeRangePicker.view(Picker<Text, String, ForEach>.self).select(value: range)
            waitForUIUpdate()
            
            // Verify data updates
            let charts = try view.inspect().find(viewWithId: "insightCharts")
            XCTAssertTrue(charts.isVisible())
        }
    }
    
    func testErrorHandling() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)
        
        try assertErrorState(in: view) {
            throw AppError.analysisError(message: "Failed to generate insights")
        }
    }
    
    func testAccessibility() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)
        
        // Test main heading accessibility
        try assertAccessibility(
            of: view,
            label: "Your Music Insights",
            hint: "Dashboard showing your music listening patterns"
        )
        
        // Test chart accessibility
        let charts = try view.inspect().find(viewWithId: "insightCharts")
        for (index, chart) in try charts.findAll(ChartView.self).enumerated() {
            try assertAccessibility(
                of: chart,
                label: "Chart \(index + 1)",
                hint: "Interactive chart showing music insights"
            )
        }
    }
    
    func testPerformance() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)
        
        // Test chart rendering performance
        measure {
            for _ in 0...5 {
                let _ = try? view.inspect().find(viewWithId: "insightCharts")
            }
        }
    }
    
    func testDataRefresh() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)
        
        // Test manual refresh
        let refreshButton = try view.inspect().find(button: "Refresh")
        try refreshButton.tap()
        
        // Verify loading state
        let loadingIndicator = try view.inspect().find(viewWithId: "loadingIndicator")
        XCTAssertTrue(loadingIndicator.isVisible())
        
        // Wait for refresh
        waitForUIUpdate(2.0)
        XCTAssertFalse(try view.inspect().find(viewWithId: "loadingIndicator").isVisible())
    }
    
    func testChartAnimations() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)
        
        // Test chart animation on data update
        let charts = try view.inspect().find(viewWithId: "insightCharts")
        let initialState = try charts.findAll(ChartView.self)
        
        // Update data
        try aiService.updateInsights()
        waitForUIUpdate()
        
        let updatedState = try charts.findAll(ChartView.self)
        XCTAssertNotEqual(initialState, updatedState)
    }
    
    func testExportFeature() throws {
        let view = InsightsDashboardView(aiService: aiService, playerManager: playerManager)
        
        // Test export button
        let exportButton = try view.inspect().find(button: "Export Insights")
        XCTAssertTrue(exportButton.isVisible())
        
        // Test export action
        try exportButton.tap()
        
        // Verify share sheet appears
        let shareSheet = try view.inspect().find(viewWithId: "shareSheet")
        XCTAssertTrue(shareSheet.isVisible())
    }
}
