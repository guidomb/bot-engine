//
//  Message.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation

public struct UserEntityInfo: Codable {
    
    public let id: String
    public let name: String?
    public let email: String?
    public let firstName: String?
    public let lastName: String?
    
    public init(
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

public struct BehaviorMessage {
    
    public struct Context {
        
        public var userEntitiesInfo: [String : UserEntityInfo]
        
        public init(userEntitiesInfo: [UserEntityInfo] = []) {
            self.userEntitiesInfo = Dictionary(userEntitiesInfo.map { ($0.id, $0) }) { a, _  in a }
        }
        
    }
    
    public enum Entity {
        
        case slackChannel(id: String, name: String)
        case slackUserId(String)
        
    }
    
    public let channel: ChannelId
    public let text: String
    public let senderId: BotEngine.UserId
    public let entities: [Entity]
    public let originalSenderId: BotEngine.UserId
    
    public var isCancelMessage: Bool {
        return text == "cancel"
    }
    
    init(channel: ChannelId, senderId: BotEngine.UserId, text: String, originalSenderId: BotEngine.UserId? = .none) {
        self.channel = channel
        self.senderId = senderId
        self.text = text
        self.entities = BehaviorMessage.parseSlackEntities(from: text)
        self.originalSenderId = originalSenderId ?? senderId
    }
    
}

extension BehaviorMessage {
    
    var slackUserIdEntities: [String] {
        return entities.map { $0.slackUserId ?? "" }.filter { !$0.isEmpty }
    }
    
    func impersonate(user: BotEngine.UserId) -> BehaviorMessage {
        return .init(channel: channel, senderId: user, text: text, originalSenderId: senderId)
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
