import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AssetTests.allTests),
        testCase(AITests.allTests)
    ]
}
#endif
