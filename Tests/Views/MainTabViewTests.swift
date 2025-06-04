import XCTest
import SwiftUI
import ViewInspector
@testable import App

class MainTabViewTests: XCTestCase {
    var tabView: MainTabView!
    
    override func setUp() {
        super.setUp()
        tabView = MainTabView()
    }
    
    override func tearDown() {
        tabView = nil
        super.tearDown()
    }
    
    func testTabBarInitialState() throws {
        let view = try tabView.inspect()
        
        // Verify all tabs exist
        XCTAssertTrue(try view.tabView().label(0).text().string().contains("Mood"))
        XCTAssertTrue(try view.tabView().label(1).text().string().contains("Mixtapes"))
        XCTAssertTrue(try view.tabView().label(2).text().string().contains("Personality"))
        XCTAssertTrue(try view.tabView().label(3).text().string().contains("Insights"))
        
        // Verify initial selection
        XCTAssertEqual(try view.tabView().selection().int(), 0)
    }
    
    func testTabNavigation() throws {
        let view = try tabView.inspect()
        let tabView = try view.tabView()
        
        // Test navigation to each tab
        for index in 0...3 {
            try tabView.select(index)
            XCTAssertEqual(try tabView.selection().int(), index)
        }
    }
    
    func testTabContentLoading() throws {
        let view = try tabView.inspect()
        let tabView = try view.tabView()
        
        // Test content of each tab
        try tabView.select(0)
        XCTAssertTrue(try view.find(MoodView.self).isVisible())
        
        try tabView.select(1)
        XCTAssertTrue(try view.find(MixTapeView.self).isVisible())
        
        try tabView.select(2)
        XCTAssertTrue(try view.find(PersonalityView.self).isVisible())
        
        try tabView.select(3)
        XCTAssertTrue(try view.find(InsightsDashboardView.self).isVisible())
    }
    
    func testTabBarAccessibility() throws {
        let view = try tabView.inspect()
        
        // Test tab accessibility labels
        try assertAccessibility(
            of: view.tabView().label(0),
            label: "Mood Tab",
            hint: "View and set your current mood"
        )
        
        try assertAccessibility(
            of: view.tabView().label(1),
            label: "Mixtapes Tab",
            hint: "View your AI-generated mixtapes"
        )
        
        try assertAccessibility(
            of: view.tabView().label(2),
            label: "Personality Tab",
            hint: "View your music personality"
        )
        
        try assertAccessibility(
            of: view.tabView().label(3),
            label: "Insights Tab",
            hint: "View your music insights"
        )
    }
    
    func testPerformance() throws {
        // Measure tab switching performance
        measure {
            for _ in 0...10 {
                for index in 0...3 {
                    try? tabView.inspect().tabView().select(index)
                }
            }
        }
    }
    
    func testStatePreservation() throws {
        let view = try tabView.inspect()
        let tabView = try view.tabView()
        
        // Select a tab
        try tabView.select(2)
        
        // Simulate background/foreground transition
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Verify selection is preserved
        XCTAssertEqual(try tabView.selection().int(), 2)
    }
    
    func testTabBarBadges() throws {
        let view = try tabView.inspect()
        
        // Test badge appearance
        let mixtapesTab = try view.tabView().label(1)
        XCTAssertTrue(try mixtapesTab.find(ViewType.Text.self).string().contains("New"))
    }
}
