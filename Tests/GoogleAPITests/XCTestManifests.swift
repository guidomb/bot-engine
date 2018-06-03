import XCTest

extension SpreadSheetRangeTest {
    static let __allTests = [
        ("testSpreadSheetRangeWithEmptySheetName", testSpreadSheetRangeWithEmptySheetName),
        ("testSpreadSheetRangeWithoutSheetName", testSpreadSheetRangeWithoutSheetName),
        ("testSpreadSheetRangeWithSheetName", testSpreadSheetRangeWithSheetName),
        ("testSpreadSheetRangeWithSheetNameAndAllCells", testSpreadSheetRangeWithSheetNameAndAllCells),
        ("testSpreadSheetRangeWithSheetNameAndAllCellsInColumn", testSpreadSheetRangeWithSheetNameAndAllCellsInColumn),
        ("testSpreadSheetRangeWithSheetNameAndAllCellsInColumnFromSpecificRow", testSpreadSheetRangeWithSheetNameAndAllCellsInColumnFromSpecificRow),
        ("testSpreadSheetRangeWithSheetNameAndAllCellsInRows", testSpreadSheetRangeWithSheetNameAndAllCellsInRows),
    ]
}

extension SpreadSheetsTest {
    static let __allTests = [
        ("testSpreadSheetValuesBatchGetResource", testSpreadSheetValuesBatchGetResource),
        ("testSpreadSheetValuesGetResource", testSpreadSheetValuesGetResource),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SpreadSheetRangeTest.__allTests),
        testCase(SpreadSheetsTest.__allTests),
    ]
}
#endif
