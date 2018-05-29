//
//  SpreadSheetsTests.swift
//  FeebiKitTests
//
//  Created by Guido Marucci Blas on 3/31/18.
//

import Foundation
import XCTest
@testable import GoogleAPI

class SpreadSheetsTest: XCTestCase {
    
    func testSpreadSheetValuesGetResource() {
        let range = SpreadSheetRange(from: "'Sheet1'!B25:K26")!
        
        let resource = GoogleAPI.spreadSheets
            .values(spreadSheetId: "somespreadsheetid123456")
            .get(range: range, majorDimension: .rows)
        
        XCTAssertEqual(resource.urlPath, "https://sheets.googleapis.com/v4/spreadsheets/somespreadsheetid123456/values/'Sheet1'!B25%3AK26?majorDimension=rows&valueRenderOption=FORMATTED_VALUE&dateTimeRenderOption=SERIAL_NUMBER")
    }
    
    func testSpreadSheetValuesBatchGetResource() {
        let ranges = [
            SpreadSheetRange(from: "'Universales-1-18'!B2:B2")!,
            SpreadSheetRange(from: "'Universales-1-18'!B3:B3")!,
            SpreadSheetRange(from: "'Universales-1-18'!B6:I9")!
        ]
        
        let resource = GoogleAPI.spreadSheets
            .values(spreadSheetId: "somespreadsheetid123456")
            .batchGet(ranges: ranges, majorDimension: .rows)
        
        XCTAssertEqual(resource.urlPath, "https://sheets.googleapis.com/v4/spreadsheets/somespreadsheetid123456/values:batchGet?ranges='Universales-1-18'!B2%3AB2&ranges='Universales-1-18'!B3%3AB3&ranges='Universales-1-18'!B6%3AI9&majorDimension=rows&valueRenderOption=FORMATTED_VALUE&dateTimeRenderOption=SERIAL_NUMBER")
    }
    
}
