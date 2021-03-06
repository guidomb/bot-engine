//
//  ListMailGroups.swift
//  Async
//
//  Created by Guido Marucci Blas on 8/2/18.
//

import Foundation
import WoloxKit
import BotEngineKit
import ReactiveSwift
import Result
import GoogleAPI

struct ListEveryoneMailGroups: BotEngineCommand {
    
    let commandUsage = "list everyone mail groups"
    
    var permission: BotEngine.ExecutionPermission {
        return .all
    }
    
    func parseInput(_ input: String) -> Optional<()> {
        return input == commandUsage ? () : nil
    }
    
    func execute(using services: BotEngine.Services, parameters: (), senderId: BotEngine.UserId) -> BotEngine.CommandOutputProducer {
        guard let slackService = services.slackService else {
            fatalError("ERROR - Slack service not available.")
        }
        
        let mailGroupService = MailGroupService(executor: services.googleAPIResourceExecutor)
        return fetchUserInfo(userId: senderId, using: slackService)
            |> asMember
            |> fetchMemberSubscriptions(using: mailGroupService)
            |> renderSubscriptions
            
    }
    
}

fileprivate func renderSubscriptions(_ member: EveryoneMember) -> BotEngine.CommandOutput {
    guard member.hasSubscriptions() else {
        return "You are not subscribed to any everyone mail group. That's weird."
    }
    
    let subscriptions = member.subscriptions.map { "- \($0.email)" }.sorted().joined(separator: "\n")
    return .init(message: "You are subscribed to:\n\(subscriptions)")
}

