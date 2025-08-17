@testable import MusicKitModule
import XCTest

final class MusicKitModuleTests: XCTestCase {
    func testMusicAuthorization() async {
        let service = MusicKitService()
        let authorized = await service.requestMusicAuthorization()
        XCTAssertTrue(authorized, "Music authorization should be granted in test environment")
    }

    static var allTests = [
        ("testMusicAuthorization", testMusicAuthorization),
    ]
}
