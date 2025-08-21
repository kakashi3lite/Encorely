import XCTest
import SwiftUI
@testable import GlassUI

final class GlassCardTests: XCTestCase {
    func testGlassCardInitialization() {
        let card = GlassCard {
            Text("Test Content")
        }
        
        // Verify the card can be instantiated
        XCTAssertNotNil(card)
    }
    
    func testGlassCardWithCustomParameters() {
        let cornerRadius: CGFloat = 20
        let tint = Color.blue.opacity(0.3)
        
        let card = GlassCard(cornerRadius: cornerRadius, tint: tint) {
            Text("Custom Test Content")
        }
        
        // Verify the card can be instantiated with custom parameters
        XCTAssertNotNil(card)
    }
}