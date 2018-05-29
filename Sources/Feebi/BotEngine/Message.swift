//
//  Message.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation

struct UserEntityInfo: Codable {
    
    let id: String
    let name: String?
    let email: String?
    let firstName: String?
    let lastName: String?
    
    init(
        id: String,
        name: String? = .none,
        email: String? = .none,
        firstName: String? = .none,
        lastName: String? = .none) {
        self.id = id
        self.name = name
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
    }
}

struct BehaviorMessage {
    
    struct Context {
        
        var userEntitiesInfo: [String : UserEntityInfo]
        
        init(userEntitiesInfo: [UserEntityInfo] = []) {
            self.userEntitiesInfo = Dictionary(userEntitiesInfo.map { ($0.id, $0) }) { a, _  in a }
        }
        
    }
    
    enum Entity {
        
        case slackChannel(id: String, name: String)
        case slackUserId(String)
        
    }
    
    enum Source {
        
        case slack
        case console
        
    }
    
    let channel: ChannelId
    let text: String
    let senderId: String
    let entities: [Entity]
    
    var isCancelMessage: Bool {
        return text == "cancel"
    }
    
    init(channel: ChannelId, senderId: String, text: String) {
        self.channel = channel
        self.senderId = senderId
        self.text = text
        self.entities = BehaviorMessage.parseSlackEntities(from: text)
    }
    
}

extension BehaviorMessage {
    
    var slackUserIdEntities: [String] {
        return entities.map { $0.slackUserId ?? "" }.filter { !$0.isEmpty }
    }
    
}

fileprivate extension BehaviorMessage.Entity {
    
    var slackUserId: String? {
        if case .slackUserId(let userId) = self {
            return userId
        } else {
            return .none
        }
    }
    
}

fileprivate extension BehaviorMessage {
    
    static func parseSlackEntities(from text: String) -> [Entity] {
        return text.split(separator: " ")
            .filter {
                // <#U234AFG|channelName> or <@U2345AD>
                $0.last == ">" && ($0.starts(with: "<@") || ($0.starts(with: "<#") && $0.contains("|")))
            }
            .map { word in
                let reference = word.dropLast().dropFirst() // removes '<' '>'
                if reference.starts(with: "@") {
                    return .slackUserId(String(reference.dropFirst()))
                } else {
                    let result = reference.dropFirst().split(separator: "|").map(String.init)
                    return .slackChannel(id: result[0], name: result[1])
                }
        }
    }
    
}
