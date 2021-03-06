//
//  Performace.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation
import ReactiveSwift
import Result
import GoogleAPI

public struct AbilityScraper {
    
    public typealias AbilityProducer = SignalProducer<[Ability], ScraperError>
    public typealias AbilityBatchResult = Result<[Ability], ScraperError>
    public typealias AbilityResult = Result<Ability, ScraperError>
    
    public indirect enum ScraperError: Error {
        
        case parsingError(message: String, cells: [[String]])
        case missingCellRanges(ranges: [ValueRange], expectedCount: UInt)
        case requestError(GoogleAPI.RequestError)
        
    }
    
    // sourcery: instanceVariablesCounterType = "SpreadSheetRange"
    // sourcery: instanceVariablesCounterName = "rangesCount"
    // sourcery: instanceVariablesEnumeratorName = "ranges"
    // sourcery: instanceVariablesEnumeratorType = "SpreadSheetRange"
    public struct RangeMapper: AutoInstanceVariableCounter, AutoInstanceVariableEnumerator {
        
        public let title: SpreadSheetRange
        public let description: SpreadSheetRange
        public let attributes: SpreadSheetRange
        
        public init(title: SpreadSheetRange, description: SpreadSheetRange, attributes: SpreadSheetRange) {
            self.title = title
            self.description = description
            self.attributes = attributes
        }
    
    }
    
    let mappers: [RangeMapper]
    let executor: GoogleAPIResourceExecutor
    
    public init(abilityGroupMapper: AbilityGroupMapper, executor: GoogleAPIResourceExecutor) {
        self.init(mappers: abilityGroupMapper.rangeMappers, executor: executor)
    }
    
    public init(mapper: RangeMapper, executor: GoogleAPIResourceExecutor) {
        self.init(mappers: [mapper], executor: executor)
    }
    
    public init(mappers: [RangeMapper], executor: GoogleAPIResourceExecutor) {
        self.mappers = mappers
        self.executor = executor
    }
    
    public func scrap(spreadSheetId: String) -> AbilityProducer {
        return GoogleAPI.spreadSheets
            .values(spreadSheetId: spreadSheetId)
            .batchGet(ranges: cellRanges, majorDimension: .rows)
            .execute(with: executor)
            .mapError(ScraperError.requestError)
            .flatMap(.concat, abilityParser)
    }
    
}

fileprivate extension AbilityScraper {
    
    var cellRanges: [SpreadSheetRange] {
        return mappers.flatMap { $0.ranges }
    }
    
    func abilityParser(batchResponse: BatchValueRange) -> AbilityScraper.AbilityProducer {
        let expectedRangesCount = UInt(cellRanges.count)
        guard batchResponse.count == expectedRangesCount else {
            return missingCellRanges(batchResponse, expectedRangesCount)
        }
        
        return AbilityProducer {
            AbilityResult.sequence(batchResponse.splitByAbilityCells().map(Ability.from))
        }
    }

}

fileprivate extension Ability {
    
    static func create(identifier: String, name: String) -> (String) -> ([Ability.Attribute]) -> Ability {
        return { description in
            return { attributes in
                return Ability(name: name, identifier: identifier, description: description, attributes: attributes)
            }
        }
    }
    
    static func from(_ batchResponse: [ValueRange]) -> AbilityScraper.AbilityResult {
        return Ability.create
            <^> parseAbilityTitle(batchResponse[0].values)
            <*> parseAbilityDescription(batchResponse[1].values)
            <*> parseAbilityAttributes(batchResponse[2].values)
    }
    
    
}

fileprivate extension Ability.Attribute {
    
    static func create(attributeCells: [String]) -> (Level?) -> (Frequency?) -> Ability.Attribute {
        return { level in
            return { frequency in
                Ability.Attribute(
                    name: String(attributeCells[0].dropFirst(3)),
                    level: level,
                    levelDescriptions: Array(attributeCells[1 ... 4]),
                    frequency: frequency,
                    comment: attributeCells.count == 8 ? attributeCells[7] : nil
                )
            }
        }
    }
    
}

fileprivate extension BatchValueRange {
    
    // Splits batch cells response in groups of rows where each group of cells correspond to
    // a particular ability in the same order as the request list of ranges.
    func splitByAbilityCells() -> [[ValueRange]] {
        let chunkSize = AbilityScraper.RangeMapper.rangesCount
        return stride(from: 0, to: valueRanges.count, by: chunkSize).map {
            Array(valueRanges[$0..<Swift.min($0 + chunkSize, valueRanges.count)])
        }
    }
    
}

fileprivate func parseAbilityAttributes(_ cells: [[String]])
    -> Result<[Ability.Attribute], AbilityScraper.ScraperError> {
    return .sequence(cells.map(parseAbilityAttribute(cells)))
}

fileprivate func parseAbilityAttribute(_ cells: [[String]]) -> ([String])
    -> Result<Ability.Attribute, AbilityScraper.ScraperError> {
    return { attributeCells in
        // When cells are blank SpreadSheet API does not return the cells.
        // Level, frequency and comments can be blank.
        guard attributeCells.count >= 5 else {
            return .failure(.parsingError(message: "Invalid attribute cells", cells: cells))
        }
        
        return Ability.Attribute.create(attributeCells: attributeCells)
            <^> parseLevel(attributeCells, cells)
            <*> parseFrequency(attributeCells, cells)
    }
}

fileprivate func parseLevel(_ attributeCells: [String], _ cells: [[String]])
    -> Result<Ability.Attribute.Level?, AbilityScraper.ScraperError> {
    guard attributeCells.count >= 6 else {
        return .success(.none)
    }
    
    if let level = UInt(attributeCells[5]).flatMap(Ability.Attribute.Level.init) {
        return .success(level)
    } else {
        return .failure(.parsingError(message: "Invalid attribute level '\(attributeCells[5])'", cells: cells))
    }
}

fileprivate func parseFrequency(_ attributeCells: [String], _ cells: [[String]])
    -> Result<Ability.Attribute.Frequency?, AbilityScraper.ScraperError> {
    guard attributeCells.count >= 7 else {
        return .success(.none)
    }
    
    if let frequency = Ability.Attribute.Frequency(rawValue: attributeCells[6].lowercased()) {
        return .success(frequency)
    } else {
        return .failure(.parsingError(message: "Invalid attribute frecuency '\(attributeCells[6])'", cells: cells))
    }
}

fileprivate func parseAbilityDescription(_ cells: [[String]])
    -> Result<String, AbilityScraper.ScraperError> {
        guard let description = cells.first?.first else {
            return .failure(.parsingError(message: "Cannot extract ability description", cells: cells))
        }
        return .success(description)
}

fileprivate func parseAbilityTitle(_ cells: [[String]])
    -> Result<(identifier: String, name: String), AbilityScraper.ScraperError> {
        guard let value = cells.first?.first else {
            return .failure(.parsingError(message: "Cannot extract ability title", cells: cells))
        }
        let parts = value.split(separator: ":").map {
            String($0.trimmingCharacters(in: CharacterSet.whitespaces))
        }
        guard parts.count == 2 else {
            return .failure(.parsingError(message: "Invalind title format '\(value)'", cells: cells))
        }
        return .success((parts[0], parts[1]))
}

fileprivate func missingCellRanges(_ batchResponse: BatchValueRange,
                                   _ expectedRangesCount: UInt) -> AbilityScraper.AbilityProducer {
    return AbilityScraper.AbilityProducer(error: .missingCellRanges(
        ranges: batchResponse.valueRanges,
        expectedCount: expectedRangesCount)
    )
}
