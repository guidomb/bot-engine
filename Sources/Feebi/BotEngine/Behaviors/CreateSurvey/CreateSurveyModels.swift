//
//  CreateSurveyModels.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation
import ReactiveSwift
import Result

struct Survey: Codable {
    
    enum Destinatary: CustomStringConvertible, Codable {
        
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
        
        init(from decoder: Decoder) throws {
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
        
        func encode(to encoder: Encoder) throws {
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
        
        var description: String {
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
    
}
