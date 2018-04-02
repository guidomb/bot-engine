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
    
    public typealias AbilityProducer = SignalProducer<Ability, ScraperError>
 
    public enum ScraperError: Error {
        
        case parsingError(message: String, cells: [[String]])
        case missingCellRanges(ranges: [ValueRange], expectedCount: UInt)
        case requestError(GoogleAPI.RequestError)

    }
    
    public struct RangeMapper {
        
        let title: SpreadSheetRange
        let description: SpreadSheetRange
        let attributes: SpreadSheetRange
        
        public init(title: SpreadSheetRange, description: SpreadSheetRange, attributes: SpreadSheetRange) {
            self.title = title
            self.description = description
            self.attributes = attributes
        }
        
        var ranges: [SpreadSheetRange] {
            return [title, description, attributes]
        }
    
    }
    
    let mapper: RangeMapper
    let executor: GoogleAPIResourceExecutor
    
    public init(mapper: RangeMapper, executor: GoogleAPIResourceExecutor = GoogleAPI.shared) {
        self.mapper = mapper
        self.executor = executor
    }
    
    public func scrap(spreadSheetId: String, token: GoogleAPI.Token) -> AbilityProducer {
        return GoogleAPI.spreadSheets
            .values(spreadSheetId: spreadSheetId)
            .batchGet(ranges: mapper.ranges, majorDimension: .rows)
            .execute(using: token, with: executor)
            .mapError { ScraperError.requestError($0) }
            .flatMap(.concat, parseAbility(from:))
    }
    
}

fileprivate func parseAbility(from batchResponse: BatchValueRange) -> AbilityScraper.AbilityProducer {
    guard batchResponse.count == 3 else {
        return AbilityScraper.AbilityProducer(error: .missingCellRanges(
            ranges: batchResponse.valueRanges,
            expectedCount: 3)
        )
    }
    return AbilityScraper.AbilityProducer {
        parseAbilityTitle(batchResponse[0])
        .fanout(parseAbilityDescription(batchResponse[1]))
        .fanout(parseAbilityAttributes(batchResponse[2]))
        .map(Ability.fromParseResult)
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

fileprivate extension Ability {
    
    typealias AbilityParseResult = (((identifier: String, name: String), description: String), attributes: [Ability.Attribute])
    
    static func fromParseResult(_ result: AbilityParseResult) -> Ability {
        return Ability(
            name: result.0.0.name,
            identifier: result.0.0.identifier,
            description: result.0.description,
            attributes: result.attributes
        )
    }
    
}
