import XCTest

class AIMixtapesUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Main Screen Tests

    func testMainScreenElements() {
        // Test main screen UI elements exist
        XCTAssertTrue(app.navigationBars["AI Mixtapes"].exists)
        XCTAssertTrue(app.buttons["Create Mixtape"].exists)
        XCTAssertTrue(app.buttons["Your Library"].exists)
    }

    func testCreateMixtapeFlow() {
        // Start mixtape creation
        app.buttons["Create Mixtape"].tap()

        // Test mood selection view
        let moodView = app.otherElements["MoodSelectionView"]
        XCTAssertTrue(moodView.exists)

        // Test mood buttons exist
        XCTAssertTrue(moodView.buttons["Happy"].exists)
        XCTAssertTrue(moodView.buttons["Energetic"].exists)
        XCTAssertTrue(moodView.buttons["Melancholic"].exists)

        // Select a mood
        moodView.buttons["Happy"].tap()

        // Test loading state
        XCTAssertTrue(app.activityIndicators["Creating Mixtape"].exists)

        // Wait for mixtape creation (timeout after 30 seconds)
        let mixtapeCreated = app.staticTexts["Your Mixtape is Ready!"].waitForExistence(timeout: 30)
        XCTAssertTrue(mixtapeCreated)
    }

    func testLibraryNavigation() {
        // Open library
        app.buttons["Your Library"].tap()

        // Test library view exists
        let libraryView = app.otherElements["LibraryView"]
        XCTAssertTrue(libraryView.exists)

        // Test sorting options
        XCTAssertTrue(app.buttons["Sort"].exists)
        app.buttons["Sort"].tap()

        // Test sort menu options
        let sortMenu = app.sheets["Sort Options"]
        XCTAssertTrue(sortMenu.exists)
        XCTAssertTrue(sortMenu.buttons["Date Created"].exists)
        XCTAssertTrue(sortMenu.buttons["Mood"].exists)
    }

    // MARK: - Player Tests

    func testPlayerControls() {
        // Navigate to library and play a mixtape
        app.buttons["Your Library"].tap()

        // Assuming there's at least one mixtape in the library
        let firstMixtape = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstMixtape.exists)
        firstMixtape.tap()

        // Test player controls
        let player = app.otherElements["PlayerView"]
        XCTAssertTrue(player.exists)

        XCTAssertTrue(player.buttons["Play"].exists)
        XCTAssertTrue(player.buttons["Next"].exists)
        XCTAssertTrue(player.buttons["Previous"].exists)

        // Test play/pause
        player.buttons["Play"].tap()
        XCTAssertTrue(player.buttons["Pause"].exists)

        // Test progress bar
        let progressBar = player.sliders["Progress"]
        XCTAssertTrue(progressBar.exists)
    }

    // MARK: - Performance Tests

    func testPerformanceMainScreenLoad() {
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            app.terminate()
            app.launch()

            // Verify main screen loaded
            XCTAssertTrue(app.navigationBars["AI Mixtapes"].waitForExistence(timeout: 5))
        }
    }

    func testPerformanceMixtapeCreation() {
        measure(metrics: [XCTCPUMetric(), XCTMemoryMetric()]) {
            // Start mixtape creation
            app.buttons["Create Mixtape"].tap()

            // Select mood
            app.otherElements["MoodSelectionView"].buttons["Happy"].tap()

            // Wait for completion
            XCTAssertTrue(app.staticTexts["Your Mixtape is Ready!"].waitForExistence(timeout: 30))
        }
    }

    // MARK: - Error Handling Tests

    func testErrorStates() {
        // Test network error state
        app.launchEnvironment = ["SIMULATE_NETWORK_ERROR": "1"]
        app.buttons["Create Mixtape"].tap()
        app.otherElements["MoodSelectionView"].buttons["Happy"].tap()

        // Verify error alert appears
        XCTAssertTrue(app.alerts["Network Error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["Network Error"].buttons["Retry"].exists)

        // Test retry functionality
        app.alerts["Network Error"].buttons["Retry"].tap()
        XCTAssertTrue(app.staticTexts["Your Mixtape is Ready!"].waitForExistence(timeout: 30))
    }

    func testOfflineMode() {
        // Enable offline mode
        app.launchEnvironment = ["OFFLINE_MODE": "1"]
        app.launch()

        // Verify offline indicator
        XCTAssertTrue(app.staticTexts["Offline Mode"].exists)

        // Test offline library access
        app.buttons["Your Library"].tap()
        XCTAssertTrue(app.otherElements["LibraryView"].exists)

        // Verify offline mixtapes are available
        XCTAssertTrue(app.cells.firstMatch.exists)
    }

    // MARK: - Accessibility Tests

    func testAccessibility() {
        // Test voice over labels
        XCTAssertTrue(app.buttons["Create Mixtape"].isAccessibilityElement)
        XCTAssertNotNil(app.buttons["Create Mixtape"].value)

        // Test dynamic type
        let contentSize = app.launchEnvironment["UIContentSizeCategory"] ?? "UICTContentSizeCategoryL"
        XCTAssertTrue(app.staticTexts.element(matching: .any, identifier: contentSize).exists)

        // Test color contrast
        app.buttons["Create Mixtape"].tap()
        let moodButtons = app.otherElements["MoodSelectionView"].buttons
        for button in moodButtons.allElementsBoundByIndex {
            XCTAssertTrue(button.isAccessibilityElement)
        }
    }
}
