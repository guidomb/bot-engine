import Foundation
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
