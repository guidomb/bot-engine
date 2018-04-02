//
//  RangeMappers.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation

public extension AbilityScraper.RangeMapper {
    
    static let abilityU1 = AbilityScraper.RangeMapper(
        title: SpreadSheetRange(from: "'Universales-1-18'!B2:B2")!,
        description: SpreadSheetRange(from: "'Universales-1-18'!B3:B3")!,
        attributes: SpreadSheetRange(from: "'Universales-1-18'!B6:I9")!
    )
    
}
