//
//  UnsubscribeMeFromMailGroup.swift
//  WotServer
//
//  Created by Guido Marucci Blas on 7/31/18.
//

import Foundation
import WoloxKit
import BotEngineKit
import ReactiveSwift
import Result
import GoogleAPI

struct UnsubscribeMeFromMailGroup: BotEngineCommand {
    
    private let inputRegex: NSRegularExpression
    
    let commandUsage: String
    
    var permission: BotEngine.ExecutionPermission {
        return .all
    }
    
    init() {
        let subscribables = MailGroupService.EveryOne
            .subscribables
            .map { $0.rawValue }
            .joined(separator: "|")
        self.commandUsage = "unsubscribe me from (\(subscribables)) mail group"
        self.inputRegex = try! NSRegularExpression(
            pattern: "^\(commandUsage)$",
            options: .caseInsensitive
        )
    }
    
    func parseInput(_ input: String) -> MailGroupService.EveryOne? {
        return input.firstMatch(regex: inputRegex).flatMap { result in
            extractMailGroup(from: input, using: result)
        }
    }
    
    func execute(using services: BotEngine.Services, parameters: MailGroupService.EveryOne, senderId: String)
        -> BotEngine.Producer<String> {
        guard let slackService = services.slackService else {
            fatalError("ERROR - Slack service not available.")
        }
        
        let mailGroup = parameters
        let mailGroupService = MailGroupService(executor: services.googleAPIResourceExecutor)
        return fetchUserInfo(userId: senderId, using: slackService)
            |> asMember
            |> fetchMemberSubscriptions(using: mailGroupService)
            |> unsubscribe(from: mailGroup, using: mailGroupService)

    }
    
}

fileprivate func extractMailGroup(from input: String, using result: NSTextCheckingResult) -> MailGroupService.EveryOne? {
    return result.substring(from: input, at: 1).flatMap(MailGroupService.EveryOne.init(rawValue:))
}

fileprivate func unsubscribe(from mailGroup: MailGroupService.EveryOne, using service: MailGroupService)
    -> (MemberWithSubscriptions) -> BotEngine.Producer<String> {
    return { input in
        
        guard input.subscriptions.contains(mailGroup) else {
            return .init(value: "You are not subscribed to '\(mailGroup.email)'.")
        }
        let canUnsubscribeFromBuenosAires = { input.subscriptions.contains(.azurduy) || input.subscriptions.contains(.guemes) }
        guard mailGroup != .buenosAires || canUnsubscribeFromBuenosAires() else {
            return .init(value: "You cannot unsubscribe from '\(mailGroup.email)' as long as you are subscribed to \(MailGroupService.EveryOne.azurduy.email) or \(MailGroupService.EveryOne.guemes.email)")
        }
        guard input.subscriptions.count > 1 else {
            return .init(value: "I cannot unsubscribe you from '\(mailGroup.email)'. You must be subscribed at least to one mail group.")
        }
        
        let remainingSubscriptions = input.subscriptions
            .filter { $0 != mailGroup }
            .map { " - \($0.email)" }
            .sorted()
            .joined(separator: "\n")
        
        return service.unsubscribe(member: input.member, from: mailGroup)
            .mapError(subscriptionError(input.member, mailGroup))
            .map { _ in "You are now unsubscribed from '\(mailGroup.email)'. You remaing subscribed to:\n\(remainingSubscriptions)" }
    }
}

fileprivate func subscriptionError(_ member: Member, _ mailGroup: MailGroupService.EveryOne)
    -> (GoogleAPI.RequestError) -> BotEngine.ErrorMessage {
    return { error in
        print(error)
        print(error.localizedDescription)
        let message = """
        Couldn't unsubscribe you (\(member.email)) to '\(mailGroup.email)'. Google's API failed.
        
        The returned error message was:
        \(error)
        """
        return .init(message: message)
    }
}
