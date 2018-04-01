//
//  SpreadSheetsTests.swift
//  FeebiKitTests
//
//  Created by Guido Marucci Blas on 3/31/18.
//

import Foundation
import XCTest
@testable import FeebiKit

class SpreadSheetsTest: XCTestCase {
    
    func testSpreadSheetValuesGetResource() {
        let range = SpreadSheetRange(from: "'Sheet1'!B25:K26")!
        
        let resource = GoogleAPI.spreadSheets
            .values(spreadSheetId: "somespreadsheetid123456")
            .get(range: range, majorDimension: .rows)
        
        XCTAssertEqual(resource.urlPath, "spreadsheets/somespreadsheetid123456/values/'Sheet1'!B25%3AK26?majorDimension=rows&valueRenderOption=FORMATTED_VALUE&dateTimeRenderOption=SERIAL_NUMBER")
    }
    
}
