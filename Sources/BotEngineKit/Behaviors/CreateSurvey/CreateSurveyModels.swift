//
//  CreateSurveyModels.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation
import ReactiveSwift
import Result

public struct Survey: Codable {
    
    public enum Destinatary: CustomStringConvertible, Codable {
        
        enum CodingKeys: CodingKey {
            
            case id
            case info
            case name
            case destinataryType
            
        }
        
        enum DestinataryType: String, Codable {
            
            case slackChannel
            case slackUser
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let destinataryType = try container.decode(DestinataryType.self, forKey: .destinataryType)
            switch destinataryType {
            case .slackChannel:
                let id = try container.decode(String.self, forKey: .id)
                let name = try container.decode(String.self, forKey: .name)
                self = .slackChannel(id: id, name: name)
            case .slackUser:
                let id = try container.decode(String.self, forKey: .id)
                let info = try container.decode(Optional<UserEntityInfo>.self, forKey: .info)
                self = .slackUser(id: id, info: info)
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .slackChannel(let id, let name):
                try container.encode(DestinataryType.slackChannel, forKey: .destinataryType)
                try container.encode(id, forKey: .id)
                try container.encode(name, forKey: .name)
            case .slackUser(let id, let info):
                try container.encode(DestinataryType.slackUser, forKey: .destinataryType)
                try container.encode(id, forKey: .id)
                try container.encode(info, forKey: .info)
            }
        }
        
        
        case slackChannel(id: String, name: String)
        case slackUser(id: String, info: UserEntityInfo?)
        
        public var description: String {
            switch self {
            case .slackChannel(_, let name):
                return "#\(name)"
            case .slackUser(let userId, let info):
                if let name = info?.name {
                    return "@\(name)"
                } else {
                    return userId
                }
            }
        }
        
    }
    
    let formId: String
    let destinataries: [Destinatary]
    let deadline: Date
    let creatorId: String
    
}

public struct ActiveSurvey: Persistable {
    
    public var id: Identifier<ActiveSurvey>?
    let survey: Survey
    let destinataries: Set<String>
    let responders: Set<String>
    
    init(survey: Survey, destinataries: Set<String>) {
        self.id = .none
        self.survey = survey
        self.destinataries = destinataries
        self.responders = Set()
    }
    
    var isCompleted: Bool {
        return Date() > survey.deadline || destinataries.count == responders.count
    }
    
    var pendingResponders: Set<String> {
        return destinataries.subtracting(responders)
    }
    
}

extension Survey {
    
    var userDestinataryIds: [String] {
        return self.destinataries.compactMap { destinatary -> String? in
            if case .slackUser(let id, _ ) = destinatary {
                return id
            } else {
                return .none
            }
        }
    }
    
    var channelDestinataryIds: [String] {
        return self.destinataries.compactMap { destinatary -> String? in
            if case .slackChannel(let id, _) = destinatary {
                return id
            } else {
                return .none
            }
        }
    }
    
}
