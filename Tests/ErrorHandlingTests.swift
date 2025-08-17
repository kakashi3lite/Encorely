import SwiftUI
import XCTest
@testable import App

class ErrorHandlingTests: XCTestCase {
    var aiService: AIIntegrationService!
    var networkManager: NetworkStateManager!

    override func setUp() {
        super.setUp()
        aiService = AIIntegrationService()
        networkManager = NetworkStateManager.shared
        networkManager.reset()
    }

    override func tearDown() {
        aiService = nil
        networkManager.reset()
        super.tearDown()
    }

    // MARK: - Network Error Tests

    func testNetworkErrorHandling() async throws {
        // Simulate network error
        let expectedError = AppError.networkError(message: "Connection timeout")
        networkManager.simulateNetworkError(for: "apiCall", error: expectedError)

        do {
            _ = try await aiService.generateMixtape(mood: .happy, length: 10)
            XCTFail("Should throw network error")
        } catch let error as AppError {
            XCTAssertEqual(error.localizedDescription, expectedError.localizedDescription)
        }
    }

    func testRetryMechanism() async throws {
        let retryExpectation = expectation(description: "Retry mechanism")
        var retryCount = 0

        // Simulate intermittent failure
        networkManager.simulateNetworkError(
            for: "apiCall",
            error: AppError.networkError(message: "Temporary failure"))

        do {
            try await withRetries(maxAttempts: 3) {
                retryCount += 1
                if retryCount < 3 {
                    throw AppError.networkError(message: "Temporary failure")
                }
                retryExpectation.fulfill()
            }
        } catch {
            XCTFail("Should succeed after retries")
        }

        await fulfillment(of: [retryExpectation], timeout: 5.0)
        XCTAssertEqual(retryCount, 3)
    }

    // MARK: - Error Recovery Tests

    func testErrorRecoveryStrategy() async throws {
        let mixtape = TestSupport.createMockMixTape(in: TestSupport.createInMemoryContainer().viewContext)

        // Simulate cascading errors
        var recoveryPath: [ErrorRecoveryStep] = []

        do {
            try await withErrorRecovery(mixtape) { step in
                recoveryPath.append(step)
                switch step {
                    case .retryOperation:
                        throw AppError.playbackError(message: "Stream failed")
                    case .useLocalCache:
                        throw AppError.cacheError(message: "Cache empty")
                    case .degradedMode:
                        // Success in degraded mode
                        return
                }
            }
        } catch {
            XCTFail("Should recover in degraded mode")
        }

        XCTAssertEqual(recoveryPath.count, 3)
        XCTAssertEqual(recoveryPath.last, .degradedMode)
    }

    func testGracefulDegradation() async throws {
        // Test progressive feature degradation
        let features: [Feature] = [.aiRecommendations, .audioAnalysis, .moodDetection]
        var availableFeatures = Set(features)

        // Simulate system under stress
        for feature in features {
            do {
                try await aiService.validateFeature(feature)
            } catch {
                availableFeatures.remove(feature)
                // Verify core functionality remains
                XCTAssertTrue(aiService.isCorePlaybackAvailable())
            }
        }

        // Verify some features are still available
        XCTAssertFalse(availableFeatures.isEmpty)
    }

    // MARK: - Error State UI Tests

    func testErrorStateTransitions() throws {
        let view = AIGeneratedMixtapeView(
            aiService: aiService,
            moodEngine: MoodEngine(),
            personalityEngine: PersonalityEngine())

        // Test error state entry
        let error = AppError.analysisError(message: "Analysis failed")
        try view.processError(error)

        let errorView = try view.inspect().find(viewWithId: "errorView")
        XCTAssertTrue(errorView.isVisible())

        // Test error state exit
        try view.clearError()
        XCTAssertFalse(try view.inspect().find(viewWithId: "errorView").isVisible())
    }

    func testConcurrentErrorHandling() async throws {
        // Simulate multiple concurrent errors
        let errorGroup = DispatchGroup()
        var encounteredErrors: [AppError] = []

        let operations = [
            ("operation1", AppError.networkError(message: "Error 1")),
            ("operation2", AppError.analysisError(message: "Error 2")),
            ("operation3", AppError.playbackError(message: "Error 3")),
        ]

        for (operation, error) in operations {
            errorGroup.enter()
            Task {
                networkManager.simulateNetworkError(for: operation, error: error)
                do {
                    _ = try await aiService.executeOperation(operation)
                } catch let error as AppError {
                    encounteredErrors.append(error)
                }
                errorGroup.leave()
            }
        }

        // Wait for all operations
        errorGroup.wait()

        // Verify error handling
        XCTAssertEqual(encounteredErrors.count, operations.count)
        XCTAssertEqual(
            Set(encounteredErrors.map(\.localizedDescription)),
            Set(operations.map(\.1.localizedDescription)))
    }

    // MARK: - Resource Cleanup Tests

    func testResourceCleanupOnError() async throws {
        let tempResources = Set(["temp1", "temp2", "temp3"])
        var cleanedResources = Set<String>()

        do {
            try await withResourceCleanup(tempResources) { resource in
                cleanedResources.insert(resource)
                throw AppError.resourceError(message: "Resource error")
            }
            XCTFail("Should throw error")
        } catch {
            // Verify all resources were cleaned up
            XCTAssertEqual(cleanedResources, tempResources)
        }
    }
}
