//
//  Performace.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation
import ReactiveSwift
import Result

public struct AbilityScraper {
    
    public typealias AbilityProducer = SignalProducer<[Ability], ScraperError>
    public typealias AbilityBatchResult = Result<[Ability], ScraperError>
    public typealias AbilityResult = Result<Ability, ScraperError>
    
    public indirect enum ScraperError: Error {
        
        case parsingError(message: String, cells: [[String]])
        case missingCellRanges(ranges: [ValueRange], expectedCount: UInt)
        case requestError(GoogleAPI.RequestError)
        
    }
    
    public struct RangeMapper {
        
        static var ranges: [KeyPath<RangeMapper, SpreadSheetRange>] {
            return [\RangeMapper.title, \RangeMapper.description, \RangeMapper.attributes]
        }
        
        let title: SpreadSheetRange
        let description: SpreadSheetRange
        let attributes: SpreadSheetRange
        
        public init(title: SpreadSheetRange, description: SpreadSheetRange, attributes: SpreadSheetRange) {
            self.title = title
            self.description = description
            self.attributes = attributes
        }
        
        var ranges: [SpreadSheetRange] {
            return RangeMapper.ranges.map { self[keyPath: $0] }
        }
    
    }
    
    let mappers: [RangeMapper]
    let executor: GoogleAPIResourceExecutor
    
    public init(mapper: RangeMapper, executor: GoogleAPIResourceExecutor = GoogleAPI.shared) {
        self.init(mappers: [mapper], executor: executor)
    }
    
    public init(mappers: [RangeMapper], executor: GoogleAPIResourceExecutor = GoogleAPI.shared) {
        self.mappers = mappers
        self.executor = executor
    }
    
    public func scrap(spreadSheetId: String, token: GoogleAPI.Token) -> AbilityProducer {
        return GoogleAPI.spreadSheets
            .values(spreadSheetId: spreadSheetId)
            .batchGet(ranges: cellRanges, majorDimension: .rows)
            .execute(using: token, with: executor)
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
            AbilityResult.lift(batchResponse.mapableCellRanges().map(Ability.from))
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

fileprivate extension BatchValueRange {
    
    func mapableCellRanges() -> [[ValueRange]] {
        let chunkSize = AbilityScraper.RangeMapper.ranges.count
        return stride(from: 0, to: valueRanges.count, by: chunkSize).map {
            Array(valueRanges[$0..<Swift.min($0 + chunkSize, valueRanges.count)])
        }
    }
    
}

fileprivate func parseAbilityAttributes(_ cells: [[String]])
    -> Result<[Ability.Attribute], AbilityScraper.ScraperError> {
        var attributes: [Ability.Attribute] = []
        for attributeCells in cells {
            guard attributeCells.count >= 7 else {
                return .failure(.parsingError(message: "Invalid attribute cells", cells: cells))
            }
            guard let level = UInt(attributeCells[5]).flatMap(Ability.Attribute.Level.init) else {
                return .failure(.parsingError(message: "Invalid attribute level '\(attributeCells[2])'", cells: cells))
            }
            guard let frequency = Ability.Attribute.Frequency(rawValue: attributeCells[6].lowercased()) else {
                return .failure(.parsingError(message: "Invalid attribute frecuency '\(attributeCells[6])'", cells: cells))
            }
            let attribute = Ability.Attribute(
                name: String(attributeCells[0].dropFirst(3)),
                level: level,
                levelDescriptions: Array(attributeCells[1 ... 4]),
                frequency: frequency,
                comment: attributeCells.count == 8 ? attributeCells[7] : nil
            )
            
            attributes.append(attribute)
        }
        
        return .success(attributes)
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
