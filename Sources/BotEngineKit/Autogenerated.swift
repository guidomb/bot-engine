import Foundation
// Generated using Sourcery 0.13.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



extension CreateSurveyBehavior.JobMessage {

    enum CodingKeys: String, CodingKey {
        case monitorSurvey
        case surveyId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.allKeys.contains(.monitorSurvey), try container.decodeNil(forKey: .monitorSurvey) == false {
            let associatedValues = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .monitorSurvey)
            let surveyId = try associatedValues.decode(Identifier<ActiveSurvey>.self, forKey: .surveyId)
            self = .monitorSurvey(surveyId: surveyId)
            return
        }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown enum case"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .monitorSurvey(surveyId):
            var associatedValues = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .monitorSurvey)
            try associatedValues.encode(surveyId, forKey: .surveyId)
        }
    }

}

extension SchedulerInterval {

    enum CodingKeys: String, CodingKey {
        case every
        case everyDay
        case seconds
        case at
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.allKeys.contains(.every), try container.decodeNil(forKey: .every) == false {
            let associatedValues = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .every)
            let seconds = try associatedValues.decode(TimeInterval.self, forKey: .seconds)
            self = .every(seconds: seconds)
            return
        }
        if container.allKeys.contains(.everyDay), try container.decodeNil(forKey: .everyDay) == false {
            let associatedValues = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .everyDay)
            let at = try associatedValues.decode(DayTime.self, forKey: .at)
            self = .everyDay(at: at)
            return
        }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown enum case"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .every(seconds):
            var associatedValues = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .every)
            try associatedValues.encode(seconds, forKey: .seconds)
        case let .everyDay(at):
            var associatedValues = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .everyDay)
            try associatedValues.encode(at, forKey: .at)
        }
    }

}

extension UserConfiguration.Property {

    enum CodingKeys: String, CodingKey {
        case string
        case integer
        case double
        case bool
        case stringValue
        case integerValue
        case doubleValue
        case boolValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.allKeys.contains(.string), try container.decodeNil(forKey: .string) == false {
            let associatedValues = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .string)
            let stringValue = try associatedValues.decode(String.self, forKey: .stringValue)
            self = .string(stringValue: stringValue)
            return
        }
        if container.allKeys.contains(.integer), try container.decodeNil(forKey: .integer) == false {
            let associatedValues = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .integer)
            let integerValue = try associatedValues.decode(Int.self, forKey: .integerValue)
            self = .integer(integerValue: integerValue)
            return
        }
        if container.allKeys.contains(.double), try container.decodeNil(forKey: .double) == false {
            let associatedValues = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .double)
            let doubleValue = try associatedValues.decode(Double.self, forKey: .doubleValue)
            self = .double(doubleValue: doubleValue)
            return
        }
        if container.allKeys.contains(.bool), try container.decodeNil(forKey: .bool) == false {
            let associatedValues = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .bool)
            let boolValue = try associatedValues.decode(Bool.self, forKey: .boolValue)
            self = .bool(boolValue: boolValue)
            return
        }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown enum case"))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .string(stringValue):
            var associatedValues = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .string)
            try associatedValues.encode(stringValue, forKey: .stringValue)
        case let .integer(integerValue):
            var associatedValues = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .integer)
            try associatedValues.encode(integerValue, forKey: .integerValue)
        case let .double(doubleValue):
            var associatedValues = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .double)
            try associatedValues.encode(doubleValue, forKey: .doubleValue)
        case let .bool(boolValue):
            var associatedValues = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .bool)
            try associatedValues.encode(boolValue, forKey: .boolValue)
        }
    }

}

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
// MARK: - DayTime AutoEquatable
extension DayTime: Equatable {}
public func == (lhs: DayTime, rhs: DayTime) -> Bool {
    guard lhs.hours == rhs.hours else { return false }
    guard lhs.minutes == rhs.minutes else { return false }
    guard lhs.timeZone == rhs.timeZone else { return false }
    return true
}

// MARK: - AutoEquatable for Enums

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



extension SlackInteractiveMessage {

  enum CodingKeys: String, CodingKey {
    case type = "type"
    case token = "token"
    case callbackId = "callback_id"
    case actions = "actions"
  }

}
