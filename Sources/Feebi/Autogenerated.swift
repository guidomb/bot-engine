// Generated using Sourcery 0.13.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT
import Foundation

extension CreateSurveyBehavior.JobMessage {

    enum CodingKeys: String, CodingKey {
        case monitorSurvey
        case surveyId
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.allKeys.contains(.monitorSurvey), try container.decodeNil(forKey: .monitorSurvey) == false {
            let associatedValues = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .monitorSurvey)
            let surveyId = try associatedValues.decode(Identifier<ActiveSurvey>.self, forKey: .surveyId)
            self = .monitorSurvey(surveyId: surveyId)
            return
        }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown enum case"))
    }

    internal func encode(to encoder: Encoder) throws {
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

    internal init(from decoder: Decoder) throws {
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

    internal func encode(to encoder: Encoder) throws {
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
