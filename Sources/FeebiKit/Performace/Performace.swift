//
//  Performace.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation
import ReactiveSwift
import Result

public struct Ability {
    
    public struct Attribute {
        
        public enum Frequency: UInt {
            
            case sometimes
            case regularly
            case inMostCases
            case almostAlways
        }
        
        public enum Level: UInt {
            
            case first
            case second
            case third
            case fourth
            
        }
        
        public let name: String
        public let level: Level
        public let frequency: Frequency
        public let comment: String?

    }
    
    public let name: String
    public let identifier: String
    public let description: String
    public let attributes: [Attribute]
    
}

struct AbilityScrapper {
    
    typealias AbilityProducer = SignalProducer<Ability, ScraperError>
 
    enum ScraperError: Error {
        
        case requestError(GoogleAPI.RequestError)

    }
    
    struct RangeMapper {
        
        let title: SpreadSheetRange
        let description: SpreadSheetRange
        let attributes: SpreadSheetRange
    
    }
    
    let mapper: RangeMapper
    let executor: GoogleAPIResourceExecutor
    
    func scrap(spreadSheetId: String, token: GoogleAPI.Token) -> AbilityProducer {
        return .empty
    }
    
}

fileprivate func parseAbilityAttributes(_ attributes: [[String]])
    -> Result<[Ability.Attribute], AbilityScrapper.ScraperError> {
    return .success([])
}

fileprivate func parseAbilityDescription(_ attributes: [[String]])
    -> Result<String, AbilityScrapper.ScraperError> {
        return .success("")
}

fileprivate func parseAbilityTitle(_ attributes: [[String]])
    -> Result<(String, String), AbilityScrapper.ScraperError> {
        return .success(("",""))
}
