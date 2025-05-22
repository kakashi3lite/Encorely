import XCTest
import SwiftUI
import ViewInspector
@testable import AIMixtapes

extension View {
    func inspect() throws -> InspectableView<ViewType.ViewHosting> {
        try ViewHosting.host(view: self)
    }
}

extension XCTestCase {
    /// Helper to wait for async UI updates
    func waitForUIUpdate(_ timeout: TimeInterval = 1.0) {
        let expectation = expectation(description: "UI Update")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout + 0.5)
    }
    
    /// Helper to test color transitions
    func assertColorTransition(from: Asset.MoodColor, to: Asset.MoodColor, in view: some View, timeout: TimeInterval = 0.5) throws {
        let initialColor = try view.inspect().find(ViewType.Shape.self).fillStyle().foregroundColor
        
        // Trigger color change
        ColorTransitionManager.shared.transition(to: to)
        
        // Wait for transition
        waitForUIUpdate(timeout)
        
        let finalColor = try view.inspect().find(ViewType.Shape.self).fillStyle().foregroundColor
        XCTAssertNotEqual(initialColor, finalColor)
    }
    
    /// Helper to test loading states
    func assertLoadingState<V: View>(in view: V, during operation: () async throws -> Void) throws {
        let expectation = expectation(description: "Loading state")
        
        // Check initial state
        var isLoading = try view.inspect().find(viewWithId: "loadingIndicator").isVisible()
        XCTAssertFalse(isLoading)
        
        // Start operation
        Task {
            do {
                try await operation()
                expectation.fulfill()
            } catch {
                XCTFail("Operation failed: \(error)")
            }
        }
        
        // Check loading state
        isLoading = try view.inspect().find(viewWithId: "loadingIndicator").isVisible()
        XCTAssertTrue(isLoading)
        
        // Wait for completion
        wait(for: [expectation], timeout: 5.0)
        
        // Check final state
        isLoading = try view.inspect().find(viewWithId: "loadingIndicator").isVisible()
        XCTAssertFalse(isLoading)
    }
    
    /// Helper to test error states
    func assertErrorState<V: View>(in view: V, during operation: () async throws -> Void) throws {
        let expectation = expectation(description: "Error state")
        
        // Check initial state
        var hasError = try view.inspect().find(viewWithId: "errorView").isVisible()
        XCTAssertFalse(hasError)
        
        // Start operation that should fail
        Task {
            do {
                try await operation()
                XCTFail("Operation should have failed")
            } catch {
                hasError = try view.inspect().find(viewWithId: "errorView").isVisible()
                XCTAssertTrue(hasError)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    /// Helper to test accessibility
    func assertAccessibility<V: View>(of view: V, label: String, hint: String? = nil) throws {
        let element = try view.inspect().find(viewWithAccessibilityLabel: label)
        XCTAssertNotNil(element)
        
        if let hint = hint {
            let elementHint = try element.accessibilityHint()
            XCTAssertEqual(elementHint, hint)
        }
    }
    
    /// Helper to test performance
    func measureViewPerformance<V: View>(of view: V, iterations: Int = 10) {
        measure {
            for _ in 0..<iterations {
                let _ = try? view.inspect()
            }
        }
    }
}
