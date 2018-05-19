// Generated using Sourcery 0.13.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



extension CreateSurveyBehavior.JobMessage {

    enum CodingKeys: String, CodingKey {
        case sayBye
        case sayHello
        case byeText
        case helloText
    }

    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.allKeys.contains(.sayBye), try container.decodeNil(forKey: .sayBye) == false {
            let associatedValues = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .sayBye)
            let byeText = try associatedValues.decode(String.self, forKey: .byeText)
            self = .sayBye(byeText: byeText)
            return
        }
        if container.allKeys.contains(.sayHello), try container.decodeNil(forKey: .sayHello) == false {
            let associatedValues = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .sayHello)
            let helloText = try associatedValues.decode(String.self, forKey: .helloText)
            self = .sayHello(helloText: helloText)
            return
        }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown enum case"))
    }

    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .sayBye(byeText):
            var associatedValues = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .sayBye)
            try associatedValues.encode(byeText, forKey: .byeText)
        case let .sayHello(helloText):
            var associatedValues = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .sayHello)
            try associatedValues.encode(helloText, forKey: .helloText)
        }
    }

}
