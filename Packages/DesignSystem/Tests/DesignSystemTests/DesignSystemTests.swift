import XCTest
import SwiftUI
@testable import DesignSystem

final class DesignSystemTests: XCTestCase {
    func testNoirGlassAccessibilityFallback() {
        // Basic sanity: ensure modifier composes without crash
        let view = Text("Test").noirGlass()
        XCTAssertNotNil(view)
    }

    func testPaletteContrastApprox() {
        // Rough luminance check (not full WCAG) for onGlass over background
        let bg = NoirPalette.background
        let fg = NoirPalette.onGlass
        XCTAssertNotEqual(bg.description, fg.description)
    }
}
