//
//  SpreadSheetRange.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 3/31/18.
//

import Foundation

public enum SpreadSheetRange: CustomStringConvertible, Equatable {
    
    public enum CellRange: CustomStringConvertible, Equatable {
        
        case allCellsInRows(fromRow: UInt, toRow: UInt)
        case allCellsInColumn(columnName: String)
        case allCellsInColumnFromRow(columnName: String, fromRow: UInt)
        case range(from: String, to: String)
        
        public var description: String {
            switch self {
            case .allCellsInRows(let fromRow, let toRow):
                return "\(fromRow):\(toRow)"
            case .allCellsInColumn(let columnName):
                return "\(columnName):\(columnName)"
            case .allCellsInColumnFromRow(let columnName, let fromRow):
                return "\(columnName)\(fromRow):\(columnName)"
            case .range(let from, let to):
                return "\(from):\(to)"
            }
        }
        
        init?(from string: String) {
            let parts = string.split(separator: ":").map { String($0) }
            guard parts.count == 2 else {
                return nil
            }
            
            let (from, to) = (parts[0].uppercased(), parts[1].uppercased())
            
            if let fromRow = UInt(from) {
                if let toRow = UInt(to) {
                    self = .allCellsInRows(fromRow: fromRow, toRow: toRow)
                } else {
                    return nil
                }
            } else if from == to && (try! from.isMatched(by: "[A-Z]+")) {
                self = .allCellsInColumn(columnName: from)
            } else if (try! from.isMatched(by: "[A-Z]+\\d+")) {
                let fromRow = String(from.drop { CharacterSet.uppercaseLetters.contains($0.unicodeScalars.first!) })
                let columnName = String(from.dropLast(fromRow.count))
                if columnName == to {
                    self = .allCellsInColumnFromRow(columnName: columnName, fromRow: UInt(fromRow)!)
                } else if (try! to.isMatched(by: "[A-Z]+\\d+")) {
                    self = .range(from: from, to: to)
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
    }
    
    case allCellsInSheet(sheetName: String)
    case cellRange(sheetName: String?, cellRange: CellRange)
    
    public var description: String {
        switch self {
        case .allCellsInSheet(let sheetName):
            return sheetName
        case .cellRange(let sheetName?, let cellRange):
            return "\(sheetName)!\(cellRange)"
        case .cellRange(.none, let cellRange):
            return cellRange.description
        }
    }

    public init?(from string: String) {
        guard string.contains(":") else {
            self = .allCellsInSheet(sheetName: string)
            return
        }
        
        guard let (sheetName, range) = extractSheetNameAndRange(from: string) else {
            return nil
        }
        guard let cellRange = CellRange(from: range) else {
            return nil
        }
        
        self = .cellRange(sheetName: sheetName, cellRange: cellRange)
    }
    
}

fileprivate func extractSheetNameAndRange(from string: String) -> (sheetName: String?, range: String)? {
    guard !string.starts(with: "!") else { return nil }
    let parts = string.split(separator: "!").map { String($0) }
    
    switch parts.count {
    case 1:
        return (.none, parts[0])
    case 2:
        return (parts[0], parts[1])
    default:
        return .none
    }
}

fileprivate func parseRange(_ cellRange: String) -> (from: String, to: String)? {
    guard let matches = try? cellRange.matches(for: "([A-Z]*\\d+):([A-Z]*\\d+)", options: .caseInsensitive),
        matches.count == 1,
        matches[0].numberOfRanges == 3,
        let from = cellRange.substring(with: matches[0].range(at: 1)),
        let to = cellRange.substring(with: matches[0].range(at: 2)) else {
        return .none
    }
    return (from.uppercased(), to.uppercased())
}

fileprivate extension String {
    
    var nsrange: NSRange {
        return NSRange(location: 0, length: self.count)
    }
    
    func matches(for pattern: String, options: NSRegularExpression.Options = []) throws -> [NSTextCheckingResult] {
        let regex = try NSRegularExpression(pattern: pattern, options: options)
        let range = NSRange(location: 0, length: self.count)
        return regex.matches(in: self, options: [], range: range)
    }
    
    func isMatched(
        by pattern: String,
        options: NSRegularExpression.Options = [],
        matchingOptions: NSRegularExpression.MatchingOptions = []) throws -> Bool {
        let regex = try NSRegularExpression(pattern: pattern, options: options)
        let range = NSRange(location: 0, length: self.count)
        return regex.numberOfMatches(in: self, options: matchingOptions, range: range) > 0
    }
    
    func substring(with nsrange: NSRange) -> String? {
        guard let range = Range(nsrange, in: self) else { return nil }
        return String(self[range])
    }
    
}
