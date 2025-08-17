import XCTest

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        [
            testCase(AssetTests.allTests),
            testCase(AITests.allTests),
        ]
    }
#endif
