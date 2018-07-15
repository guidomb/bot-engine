import Foundation
import GoogleAPI
// Generated using Sourcery 0.13.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



// swiftlint:disable file_length
fileprivate func compareOptionals<T>(lhs: T?, rhs: T?, compare: (_ lhs: T, _ rhs: T) -> Bool) -> Bool {
    switch (lhs, rhs) {
    case let (lValue?, rValue?):
        return compare(lValue, rValue)
    case (nil, nil):
        return true
    default:
        return false
    }
}

fileprivate func compareArrays<T>(lhs: [T], rhs: [T], compare: (_ lhs: T, _ rhs: T) -> Bool) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (idx, lhsItem) in lhs.enumerated() {
        guard compare(lhsItem, rhs[idx]) else { return false }
    }

    return true
}


// MARK: - AutoEquatable for classes, protocols, structs
// MARK: - FirestoreDocument AutoEquatable
extension FirestoreDocument: Equatable {}
public func == (lhs: FirestoreDocument, rhs: FirestoreDocument) -> Bool {
    guard compareOptionals(lhs: lhs.name, rhs: rhs.name, compare: ==) else { return false }
    guard lhs.fields == rhs.fields else { return false }
    guard lhs.createTime == rhs.createTime else { return false }
    guard lhs.updateTime == rhs.updateTime else { return false }
    return true
}
// MARK: - FirestoreDocument.ArrayValue AutoEquatable
extension FirestoreDocument.ArrayValue: Equatable {}
public func == (lhs: FirestoreDocument.ArrayValue, rhs: FirestoreDocument.ArrayValue) -> Bool {
    guard compareOptionals(lhs: lhs.values, rhs: rhs.values, compare: ==) else { return false }
    return true
}
// MARK: - FirestoreDocument.LatLng AutoEquatable
extension FirestoreDocument.LatLng: Equatable {}
public func == (lhs: FirestoreDocument.LatLng, rhs: FirestoreDocument.LatLng) -> Bool {
    guard lhs.latitude == rhs.latitude else { return false }
    guard lhs.longitude == rhs.longitude else { return false }
    return true
}
// MARK: - FirestoreDocument.MapValue AutoEquatable
extension FirestoreDocument.MapValue: Equatable {}
public func == (lhs: FirestoreDocument.MapValue, rhs: FirestoreDocument.MapValue) -> Bool {
    guard compareOptionals(lhs: lhs.fields, rhs: rhs.fields, compare: ==) else { return false }
    return true
}

// MARK: - AutoEquatable for Enums
// MARK: - FirestoreDocument.Value AutoEquatable
extension FirestoreDocument.Value: Equatable {}
public func == (lhs: FirestoreDocument.Value, rhs: FirestoreDocument.Value) -> Bool {
    switch (lhs, rhs) {
    case (.nullValue, .nullValue):
        return true
    case (.booleanValue(let lhs), .booleanValue(let rhs)):
        return lhs == rhs
    case (.integerValue(let lhs), .integerValue(let rhs)):
        return lhs == rhs
    case (.doubleValue(let lhs), .doubleValue(let rhs)):
        return lhs == rhs
    case (.timestampValue(let lhs), .timestampValue(let rhs)):
        return lhs == rhs
    case (.stringValue(let lhs), .stringValue(let rhs)):
        return lhs == rhs
    case (.bytesValue(let lhs), .bytesValue(let rhs)):
        return lhs == rhs
    case (.referenceValue(let lhs), .referenceValue(let rhs)):
        return lhs == rhs
    case (.geoPointValue(let lhs), .geoPointValue(let rhs)):
        return lhs == rhs
    case (.arrayValue(let lhs), .arrayValue(let rhs)):
        return lhs == rhs
    case (.mapValue(let lhs), .mapValue(let rhs)):
        return lhs == rhs
    default: return false
    }
}

// swiftlint:disable file_length
// swiftlint:disable line_length

fileprivate func combineHashes(_ hashes: [Int]) -> Int {
    return hashes.reduce(0, combineHashValues)
}

fileprivate func combineHashValues(_ initial: Int, _ other: Int) -> Int {
    #if arch(x86_64) || arch(arm64)
        let magic: UInt = 0x9e3779b97f4a7c15
    #elseif arch(i386) || arch(arm)
        let magic: UInt = 0x9e3779b9
    #endif
    var lhs = UInt(bitPattern: initial)
    let rhs = UInt(bitPattern: other)
    lhs ^= rhs &+ magic &+ (lhs << 6) &+ (lhs >> 2)
    return Int(bitPattern: lhs)
}

fileprivate func hashArray<T: Hashable>(_ array: [T]?) -> Int {
    guard let array = array else {
        return 0
    }
    return array.reduce(5381) {
        ($0 << 5) &+ $0 &+ $1.hashValue
    }
}

#if swift(>=4.0)
fileprivate func hashDictionary<T, U: Hashable>(_ dictionary: [T: U]?) -> Int {
    guard let dictionary = dictionary else {
        return 0
    }
    return dictionary.reduce(5381) {
        combineHashValues($0, combineHashValues($1.key.hashValue, $1.value.hashValue))
    }
}
#else
fileprivate func hashDictionary<T: Hashable, U: Hashable>(_ dictionary: [T: U]?) -> Int {
    guard let dictionary = dictionary else {
        return 0
    }
    return dictionary.reduce(5381) {
        combineHashValues($0, combineHashValues($1.key.hashValue, $1.value.hashValue))
    }
}
#endif








// MARK: - AutoHashable for classes, protocols, structs

// MARK: - AutoHashable for Enums



extension MailChimp.Lists.Member {

  enum CodingKeys: String, CodingKey {
    case emailAddress = "email_address"
    case status = "status"
    case mergeFields = "merge_fields"
  }

}

extension MailChimp.Lists.UpdateMembersRequestParameters {

  enum CodingKeys: String, CodingKey {
    case members = "members"
    case updateExisting = "update_existing"
  }

}

extension MailChimp.Lists.UpdateMembersResponse {

  enum CodingKeys: String, CodingKey {
    case newMembers = "new_members"
    case updatedMembers = "updated_members"
    case errors = "errors"
    case totalCreated = "total_created"
    case totalUpdated = "total_updated"
    case errorCount = "error_count"
  }

}



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
