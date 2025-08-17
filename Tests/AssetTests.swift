import XCTest
@testable import App

class AssetTests: XCTestCase {
    // MARK: - Mood Color Tests

    func testMoodColors() {
        // Test all mood colors
        for mood in Asset.MoodColor.allCases {
            XCTAssertNotNil(mood.uiColor, "Mood color \(mood.rawValue) should exist")
            XCTAssertNotNil(mood.color, "SwiftUI mood color \(mood.rawValue) should exist")
        }

        // Test opacity modification
        let opaqueColor = Asset.MoodColor.happy.withOpacity(0.5)
        XCTAssertNotNil(opaqueColor)
    }

    func testMoodColorFailure() {
        // Test non-existent mood color
        let nonExistentColor = UIColor(named: "Mood/NonExistent")
        XCTAssertNil(nonExistentColor)
    }

    // MARK: - Personality Color Tests

    func testPersonalityColors() {
        // Test all personality colors
        for personality in Asset.PersonalityColor.allCases {
            XCTAssertNotNil(personality.uiColor, "Personality color \(personality.rawValue) should exist")
            XCTAssertNotNil(personality.color, "SwiftUI personality color \(personality.rawValue) should exist")
        }

        // Test opacity modification
        let opaqueColor = Asset.PersonalityColor.curator.withOpacity(0.5)
        XCTAssertNotNil(opaqueColor)
    }

    func testPersonalityColorFailure() {
        // Test non-existent personality color
        let nonExistentColor = UIColor(named: "Personality/NonExistent")
        XCTAssertNil(nonExistentColor)
    }

    // MARK: - Base Color Tests

    func testBaseColors() {
        // Test all base colors
        for color in Asset.Color.allCases {
            XCTAssertNotNil(color.uiColor, "Base color \(color.rawValue) should exist")
            XCTAssertNotNil(color.color, "SwiftUI base color \(color.rawValue) should exist")
        }
    }

    // MARK: - Image Tests

    func testImages() {
        // Test all images
        for image in Asset.Image.allCases {
            XCTAssertNotNil(image.uiImage, "Image \(image.rawValue) should exist")
            XCTAssertNotNil(image.image, "SwiftUI image \(image.rawValue) should exist")
        }
    }

    // MARK: - Asset Loading Tests

    func testAssetLoading() {
        // Test successful image loading
        XCTAssertNoThrow(try Asset.image(name: "LaunchIcon"))

        // Test successful color loading
        XCTAssertNoThrow(try Asset.color(name: "appPrimary"))

        // Test failed image loading
        XCTAssertThrowsError(try Asset.image(name: "NonExistentImage")) { error in
            guard case let AssetError.missingImage(name) = error else {
                XCTFail("Wrong error type")
                return
            }
            XCTAssertEqual(name, "NonExistentImage")
        }

        // Test failed color loading
        XCTAssertThrowsError(try Asset.color(name: "NonExistentColor")) { error in
            guard case let AssetError.missingColor(name) = error else {
                XCTFail("Wrong error type")
                return
            }
            XCTAssertEqual(name, "NonExistentColor")
        }
    }

    // MARK: - Asset Validation Tests

    func testAssetValidation() {
        // Test overall asset validation
        XCTAssertTrue(Asset.validateAssets(), "All required assets should be available")
    }
}
