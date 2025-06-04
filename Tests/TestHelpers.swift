import XCTest
import SwiftUI
@testable import App

extension XCTestCase {
    /// Helper function to verify color asset exists and loads correctly
    func assertColorExists(_ colorName: String, file: StaticString = #file, line: UInt = #line) {
        let color = UIColor(named: colorName)
        XCTAssertNotNil(color, "Color asset '\(colorName)' should exist", file: file, line: line)
    }
    
    /// Helper function to verify mood color transitions
    func assertMoodTransition(from: Asset.MoodColor, to: Asset.MoodColor, duration: Double = 0.3) {
        let expectation = XCTestExpectation(description: "Mood color transition")
        
        withAnimation(.easeInOut(duration: duration)) {
            // Verify both colors exist
            XCTAssertNotNil(from.color)
            XCTAssertNotNil(to.color)
        }
        
        // Wait for animation
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: duration + 0.1)
    }
    
    /// Helper function to verify personality theme application
    func assertPersonalityTheme(_ personality: Asset.PersonalityColor) {
        // Verify base color exists
        XCTAssertNotNil(personality.color)
        
        // Verify theme variants
        assertColorExists("Personality/\(personality.rawValue)")
    }
}
