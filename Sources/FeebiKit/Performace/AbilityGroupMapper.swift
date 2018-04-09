//
//  RangeMappers.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation

public protocol AbilityGroupMapper {

    var rangeMappers: [AbilityScraper.RangeMapper] { get }

}

public struct UniversalAbilityGroupMapper: AbilityGroupMapper {

    private let spreadSheetName: String

    public init(spreadSheetName: String) {
        self.spreadSheetName = spreadSheetName
    }

    var abilityU1: AbilityScraper.RangeMapper {
      return AbilityScraper.RangeMapper(
        title: SpreadSheetRange(from: "'\(spreadSheetName)'!B2:B2")!,
        description: SpreadSheetRange(from: "'\(spreadSheetName)'!B3:B3")!,
        attributes: SpreadSheetRange(from: "'\(spreadSheetName)'!B6:I9")!
      )
    }

    var abilityU2: AbilityScraper.RangeMapper {
      return AbilityScraper.RangeMapper(
        title: SpreadSheetRange(from: "'\(spreadSheetName)'!B12:B12")!,
        description: SpreadSheetRange(from: "'\(spreadSheetName)'!B13:B13")!,
        attributes: SpreadSheetRange(from: "'\(spreadSheetName)'!B16:I20")!
      )
    }

    var abilityU3: AbilityScraper.RangeMapper {
      return AbilityScraper.RangeMapper(
        title: SpreadSheetRange(from: "'\(spreadSheetName)'!B23:B23")!,
        description: SpreadSheetRange(from: "'\(spreadSheetName)'!B24:B24")!,
        attributes: SpreadSheetRange(from: "'\(spreadSheetName)'!B27:I32")!
      )
    }

    var abilityU4: AbilityScraper.RangeMapper {
      return AbilityScraper.RangeMapper(
        title: SpreadSheetRange(from: "'\(spreadSheetName)'!B35:B35")!,
        description: SpreadSheetRange(from: "'\(spreadSheetName)'!B36:B36")!,
        attributes: SpreadSheetRange(from: "'\(spreadSheetName)'!B39:I42")!
      )
    }

    var abilityU5: AbilityScraper.RangeMapper {
      return AbilityScraper.RangeMapper(
        title: SpreadSheetRange(from: "'\(spreadSheetName)'!B45:B45")!,
        description: SpreadSheetRange(from: "'\(spreadSheetName)'!B46:B46")!,
        attributes: SpreadSheetRange(from: "'\(spreadSheetName)'!B49:I53")!
      )
    }

    var abilityU6: AbilityScraper.RangeMapper {
      return AbilityScraper.RangeMapper(
        title: SpreadSheetRange(from: "'\(spreadSheetName)'!B56:B56")!,
        description: SpreadSheetRange(from: "'\(spreadSheetName)'!B57:B57")!,
        attributes: SpreadSheetRange(from: "'\(spreadSheetName)'!B60:I64")!
      )
    }

    var abilityU7: AbilityScraper.RangeMapper {
      return AbilityScraper.RangeMapper(
        title: SpreadSheetRange(from: "'\(spreadSheetName)'!B67:B67")!,
        description: SpreadSheetRange(from: "'\(spreadSheetName)'!B68:B68")!,
        attributes: SpreadSheetRange(from: "'\(spreadSheetName)'!B71:I75")!
      )
    }

    var abilityU8: AbilityScraper.RangeMapper {
      return AbilityScraper.RangeMapper(
        title: SpreadSheetRange(from: "'\(spreadSheetName)'!B78:B78")!,
        description: SpreadSheetRange(from: "'\(spreadSheetName)'!B79:B79")!,
        attributes: SpreadSheetRange(from: "'\(spreadSheetName)'!B82:I85")!
      )
    }

    var abilityU9: AbilityScraper.RangeMapper {
      return AbilityScraper.RangeMapper(
        title: SpreadSheetRange(from: "'\(spreadSheetName)'!B88:B88")!,
        description: SpreadSheetRange(from: "'\(spreadSheetName)'!B89:B89")!,
        attributes: SpreadSheetRange(from: "'\(spreadSheetName)'!B92:I96")!
      )
    }

    var abilityU10: AbilityScraper.RangeMapper {
      return AbilityScraper.RangeMapper(
        title: SpreadSheetRange(from: "'\(spreadSheetName)'!B99:B99")!,
        description: SpreadSheetRange(from: "'\(spreadSheetName)'!B100:B100")!,
        attributes: SpreadSheetRange(from: "'\(spreadSheetName)'!B103:I106")!
      )
    }

}
