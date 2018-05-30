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

extension SchedulableJob.Interval {

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
