// Generated using Sourcery 0.12.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT




extension UniversalAbilityGroupMapper {

  public var rangeMappers: [AbilityScraper.RangeMapper] {
    return [
       abilityU1,
       abilityU2,
       abilityU3,
       abilityU4,
       abilityU5,
       abilityU6,
       abilityU7,
       abilityU8,
       abilityU9,
       abilityU10
    ]
  }

}


extension AbilityScraper.RangeMapper {

  
  static let rangesCount = 3
  
}



extension AbilityScraper.RangeMapper {

  
  var ranges: [SpreadSheetRange] {
    return [
          title,
          description,
          attributes,
    
    ]
  }
  
}

