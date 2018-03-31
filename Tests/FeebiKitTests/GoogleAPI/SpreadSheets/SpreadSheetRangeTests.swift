//
//  SpreadSheetRangeSpec.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 3/31/18.
//

//import Quick
//import Nimble

import Foundation
import XCTest
import FeebiKit

class SpreadSheetRangeTest: XCTestCase {

    func testSpreadSheetRangeWithSheetName() {
        let range = SpreadSheetRange(from: "Sheet1!A1:B2")
        XCTAssertEqual(range, .cellRange(sheetName: "Sheet1", cellRange: .range(from: "A1", to: "B2")))
    }
    
    func testSpreadSheetRangeWithSheetNameAndAllCellsInRows() {
        let range = SpreadSheetRange(from: "Sheet1!1:2")
        XCTAssertEqual(range, .cellRange(sheetName: "Sheet1", cellRange: .allCellsInRows(fromRow: 1, toRow: 2)))
    }
    
    func testSpreadSheetRangeWithoutSheetName() {
        let range = SpreadSheetRange(from: "A1:B2")
        XCTAssertEqual(range, .cellRange(sheetName: .none, cellRange: .range(from: "A1", to: "B2")))
    }
    
    func testSpreadSheetRangeWithSheetNameAndAllCellsInColumn() {
        let range = SpreadSheetRange(from: "Sheet1!A:A")
        XCTAssertEqual(range, .cellRange(sheetName: "Sheet1", cellRange: .allCellsInColumn(columnName: "A")))
    }
    
    func testSpreadSheetRangeWithSheetNameAndAllCellsInColumnFromSpecificRow() {
        let range = SpreadSheetRange(from: "Sheet1!A5:A")
        XCTAssertEqual(range, .cellRange(sheetName: "Sheet1", cellRange: .allCellsInColumnFromRow(columnName: "A", fromRow: 5)))
    }
    
    func testSpreadSheetRangeWithSheetNameAndAllCells() {
        let range = SpreadSheetRange(from: "Sheet1")
        XCTAssertEqual(range, .allCellsInSheet(sheetName: "Sheet1"))
    }
    
    func testSpreadSheetRangeWithEmptySheetName() {
        let range = SpreadSheetRange(from: "!A1:B2")
        XCTAssertNil(range)
    }
    
}


//class SpreadSheetRangeSpec: QuickSpec {
//
//    override func spec() {
//
//        describe("SpreadSheetRange#init?(from:)") {
//
//            context("when a valid spreadsheet range string in A1 notation is provided") {
//
//                it("creates a new SpreadSheetRange value") {
//                    let range = SpreadSheetRange(from: "Sheet1!A1:B2")
//                    expect(range).not.toBeNil()
//                    expect(range?.sheetName).to.equal("Sheet1")
//                    expect(range?.cellRange.from)
//                    "Sheet1!A:A"
//                    "Sheet1!1:2"
//                    "Sheet1!A5:A"
//                    "A1:B2"
////                    Sheet1
//
//                    let you = You(awesome: true)
//                    expect{you.submittedAnIssue}.toEventually(beTruthy())
//                }
//
//            }
//
//        }
//
//    }
//
//}
