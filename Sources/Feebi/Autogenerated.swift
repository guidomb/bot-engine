// Generated using Sourcery 0.13.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



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
