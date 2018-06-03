import XCTest

extension AbilityScraperTests {
    static let __allTests = [
        ("testScrapWithValidAbilities", testScrapWithValidAbilities),
        ("testScrapWithValidAbility", testScrapWithValidAbility),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(AbilityScraperTests.__allTests),
    ]
}
#endif
