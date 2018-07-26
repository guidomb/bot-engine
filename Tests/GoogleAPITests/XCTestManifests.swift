import XCTest

extension QueryStringConvertibleTest {
    static let __allTests = [
        ("testAllParametersAvailable", testAllParametersAvailable),
        ("testEmptyParamters", testEmptyParamters),
        ("testOptionalParameterAvailable", testOptionalParameterAvailable),
    ]
}

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
        testCase(QueryStringConvertibleTest.__allTests),
        testCase(SpreadSheetRangeTest.__allTests),
        testCase(SpreadSheetsTest.__allTests),
    ]
}
#endif
