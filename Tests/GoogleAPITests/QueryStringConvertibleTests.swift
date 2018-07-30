//
//  QueryStringConvertibleTests.swift
//  GoogleAPITests
//
//  Created by Guido Marucci Blas on 7/23/18.
//

import Foundation
import XCTest
import GoogleAPI

class QueryStringConvertibleTest: XCTestCase {
    
    func testEmptyParamters() {
        let options = ListMembersOptions()
        XCTAssertTrue(options.asQueryString.isEmpty)
    }
    
    func testOptionalParameterAvailable() {
        var options = ListMembersOptions()
        options.pageToken = "foo"
        XCTAssertEqual(options.asQueryString, "pageToken=foo")
    }
    
    func testAllParametersAvailable() {
        var options = ListMembersOptions()
        options.pageToken = "foo"
        options.includeDerivedMembership = true
        options.maxResults = 10
        options.roles = .owner
        
        let queryString = options.asQueryString.split(separator: "&")
        XCTAssertTrue(queryString.count == 4)
        XCTAssertTrue(queryString.contains("pageToken=foo"))
        XCTAssertTrue(queryString.contains("includeDerivedMembership=true"))
        XCTAssertTrue(queryString.contains("maxResults=10"))
        XCTAssertTrue(queryString.contains("roles=OWNER"))
    }
    
}
