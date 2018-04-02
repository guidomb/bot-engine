//
//  Spreadsheets.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 3/30/18.
//

import Foundation
import ReactiveSwift
import Result

public extension GoogleAPI {
    
    public struct SpreadSheets {
        
        static let rootPath = "spreadsheets"
        
        static let shared = SpreadSheets()
        
        private init() {}
        
        public struct Values {
            
            private let basePath: String
            
            fileprivate init(spreadSheetId: String) {
                self.basePath = "\(SpreadSheets.rootPath)/\(spreadSheetId)/values"
            }
            
            // https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets.values/get
            public func get(range: SpreadSheetRange, options: GetValuesOptions) -> Resource<ValueRange> {
                return Resource(path: "\(basePath)/\(range.urlEncoded)", queryParameters: options, method: .get)
            }
            
            public func get(range: SpreadSheetRange, majorDimension: SpreadSheetDimension) -> Resource<ValueRange> {
                return get(range: range, options: GetValuesOptions(majorDimension: majorDimension))
            }
            
            // https://developers.google.com/sheets/api/reference/rest/v4/spreadsheets.values/batchGet
            public func batchGet(ranges: [SpreadSheetRange], options: GetValuesOptions) -> Resource<BatchValueRange> {
                return Resource(
                    path: "\(basePath):batchGet",
                    queryParameters: "\(ranges.makeQueryString(withKey: "ranges"))&\(options.asQueryString)",
                    method: .get
                )
            }
            
            public func batchGet(ranges: [SpreadSheetRange], majorDimension: SpreadSheetDimension) -> Resource<BatchValueRange>{
                return batchGet(ranges: ranges, options: GetValuesOptions(majorDimension: majorDimension))
            }
            
        }
        
        public func values(spreadSheetId: String) -> Values {
            return Values(spreadSheetId: spreadSheetId)
        }
        
    }
    
    public static var spreadSheets: SpreadSheets { return .shared }
    
}

public enum SpreadSheetDimension: String, Decodable {
    
    case rows = "ROWS"
    case columns = "COLUMNS"
    case unspecified = "DIMENSION_UNSPECIFIED"
    
}

public enum ValueRenderOption: String {
    
    case formattedValue = "FORMATTED_VALUE"
    case unformattedValue = "UNFORMATTED_VALUE"
    case formula = "FORMULA"
    
}

public enum DateTimeRenderOption: String {
    
    case serialNumber = "SERIAL_NUMBER"
    case formattedString = "FORMATTED_STRING"
    
}

public struct ValueRange: Decodable {
    
    public let range: String
    public let majorDimension: SpreadSheetDimension
    public let values: [[String]]
}

public struct BatchValueRange: Decodable {
    
    public let spreadsheetId: String
    public let valueRanges: [ValueRange]
    
    var count: Int {
        return valueRanges.count
    }
    
    subscript(index: Int) -> [[String]] {
        return self.valueRanges[index].values
    }
    
}

public struct GetValuesOptions {
    
    public let majorDimension: SpreadSheetDimension
    public let valueRenderOption: ValueRenderOption
    public let dateTimeRenderOption: DateTimeRenderOption
    
    public init(
        majorDimension: SpreadSheetDimension,
        valueRenderOption: ValueRenderOption = .formattedValue,
        dateTimeRenderOption: DateTimeRenderOption = .serialNumber) {
        self.majorDimension = majorDimension
        self.valueRenderOption = valueRenderOption
        self.dateTimeRenderOption = dateTimeRenderOption
    }
    
}

extension GetValuesOptions: QueryStringConvertible {
    
    public var asQueryString: String {
        return  "majorDimension=\(majorDimension)"              +
                "&valueRenderOption=\(valueRenderOption.rawValue)" +
                "&dateTimeRenderOption=\(dateTimeRenderOption.rawValue)"
    }
    
}

extension SpreadSheetRange {
    
    var urlEncoded: String {
        return self.description.urlEncoded
    }
    
}
