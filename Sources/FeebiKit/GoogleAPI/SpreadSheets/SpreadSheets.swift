//
//  Spreadsheets.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 3/30/18.
//

import Foundation
import ReactiveSwift
import Result

enum SpreadSheetsResource: GoogleAPIResourceEndpoint {
    
    case values(spreadSheetId: String, method: Values)
    
    var name: String {
        return "spreadsheets"
    }
    
    var urlPath: String {
        switch self {
        case .values(let spreadSheetId, let method):
            return "\(spreadSheetId)/values/\(method.urlPath)"
        }
    }
    
    var httpMethod: String {
        switch self {
        case .values(_, let method):
            return method.httpMethod
        }
    }
    
    enum Values {
        
        case get(range: SpreadSheetRange, options: GetValuesOptions)
        
        var urlPath: String {
            switch self {
            case .get(let range, let options):
                let escapedRange = range.description
                    .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? range.description
                return "\(escapedRange)?\(options.asQueryString)"
            }
        }
        
        var httpMethod: String {
            switch self {
            case .get:
                return "GET"
            }
        }
        
    }
    
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

extension GetValuesOptions {
    
    var asQueryString: String {
        return  "majorDimension=\(majorDimension)"              +
                "&valueRenderOption=\(valueRenderOption.rawValue)" +
                "&dateTimeRenderOption=\(dateTimeRenderOption.rawValue)"
    }
    
}

