//
//  FirestoreEncoderTests.swift
//  GoogleAPITests
//
//  Created by Guido Marucci Blas on 10/1/18.
//

import Foundation
import XCTest
import GoogleAPI
import TestKit

class FirestoreCoderTests: XCTestCase {

    class RootContainer: Codable, Equatable {
        
        static func == (lhs: FirestoreCoderTests.RootContainer, rhs: FirestoreCoderTests.RootContainer) -> Bool {
            return
                lhs.intValue == rhs.intValue                    &&
                lhs.int8Value == rhs.int8Value                  &&
                lhs.int16Value == rhs.int16Value                &&
                lhs.int32Value == rhs.int32Value                &&
                lhs.int64Value == rhs.int64Value                &&
                lhs.uint8Value == rhs.uint8Value                &&
                lhs.uint16Value == rhs.uint16Value              &&
                lhs.uint32Value == rhs.uint32Value              &&
                lhs.uint64Value == rhs.uint64Value              &&
                lhs.boolValue == rhs.boolValue                  &&
                lhs.doubleValue == rhs.doubleValue              &&
                lhs.stringValue == rhs.stringValue              &&
                lhs.arrayValue == rhs.arrayValue                &&
                lhs.mapValue == rhs.mapValue                    &&
                lhs.optionalValue == rhs.optionalValue          &&
                lhs.simpleArrayValue == rhs.simpleArrayValue    &&
                FirestoreDocument.serialize(date: lhs.dateValue)  == FirestoreDocument.serialize(date: rhs.dateValue)
        }
        
        
        var intValue: Int = 10
        var int8Value: Int8 = Int8.max - 1
        var int16Value: Int16 = Int16.max - 1
        var int32Value: Int32 = Int32.max - 1
        var int64Value: Int64 = Int64.max - 1
        var uint8Value: UInt8 = UInt8.max - 1
        var uint16Value: UInt16 = UInt16.max - 1
        var uint32Value: UInt32 = UInt32.max - 1
        var uint64Value: UInt64 = UInt64.max - 1
        var boolValue: Bool = false
        var doubleValue: Double = .pi
        var dateValue: Date = Date(timeIntervalSinceReferenceDate: 560143254.966205)
        var stringValue: String = "This is a sample text"
        var dataValue: Data = "This is another sample text".data(using: .utf8)!
        var arrayValue: [RootContainer] = []
        var mapValue: [String : RootContainer] = [:]
        var optionalValue: RootContainer? = .none
        var simpleArrayValue: [Int] = []
        
    }
    
    var fixtureManager: FixtureManager!
    
    override func setUp() {
        fixtureManager = createFixtureManager()
    }
    
    func testSingleNodeEncoding() {
        let value = RootContainer()
        
        let document = try! FirestoreEncoder().encode(value, name: "RootContainerTestValue")
        let jsonData = try! JSONEncoder().encode(document)
        let json = try! JSONSerialization.jsonObject(with: jsonData, options: []) as! NSDictionary
        
        let expectedJsonData = try! fixtureManager.loadFixture(in: "SingleNodeEncoding.json")
        let expectedJson = try! JSONSerialization.jsonObject(with: expectedJsonData, options: []) as! NSDictionary
        XCTAssertEqual(json, expectedJson)
    }
    
    func testComplexNodeEncoding() {
        let value = RootContainer()
        value.simpleArrayValue = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        value.mapValue["foo"] = RootContainer()
        value.mapValue["bar"] = RootContainer()
        value.arrayValue = [RootContainer(), RootContainer(), RootContainer()]
        
        let document = try! FirestoreEncoder().encode(value, name: "RootContainerTestValue")
        let jsonData = try! JSONEncoder().encode(document)
        let json = try! JSONSerialization.jsonObject(with: jsonData, options: []) as! NSDictionary
        
        let expectedJsonData = try! fixtureManager.loadFixture(in: "ComplexNodeEncoding.json")
        let expectedJson = try! JSONSerialization.jsonObject(with: expectedJsonData, options: []) as! NSDictionary
        XCTAssertEqual(json, expectedJson)
    }
    
    func testEncodingAndDecodingSimpleNode() {
        let value = RootContainer()
        
        let document = try! FirestoreEncoder().encode(value, name: "RootContainerTestValue")
        let jsonData = try! JSONEncoder().encode(document)
        let decodedValue = try! FirestoreDecoder().decode(RootContainer.self, from: jsonData)
        
        XCTAssertEqual(value, decodedValue)
    }
    
    func testEncodingAndDecodingComplexNode() {
        let value = RootContainer()
        value.simpleArrayValue = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        value.mapValue["foo"] = RootContainer()
        value.mapValue["bar"] = RootContainer()
        value.arrayValue = [RootContainer(), RootContainer(), RootContainer()]
        
        let document = try! FirestoreEncoder().encode(value, name: "RootContainerTestValue")
        let jsonData = try! JSONEncoder().encode(document)
        let decodedValue = try! FirestoreDecoder().decode(RootContainer.self, from: jsonData)
        
        XCTAssertEqual(value, decodedValue)
    }
    
}



