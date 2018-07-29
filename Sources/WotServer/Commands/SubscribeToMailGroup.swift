//
//  SubscribeToMailingList.swift
//  BotEngine
//
//  Created by Guido Marucci Blas on 7/15/18.
//

import Foundation
import WoloxKit
import BotEngineKit
import ReactiveSwift
import Result
import GoogleAPI

struct SubscribeToMailGroup: BotEngineCommand {

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
        self.commandUsage = "subscribe me to (\(subscribables)) mail group"
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
    
    func execute(using services: BotEngine.Services, parameters: MailGroupService.EveryOne, senderId: String) -> SignalProducer<String, BotEngine.ErrorMessage> {
        guard let slackService = services.slackService else {
            fatalError("ERROR - Slack service not available.")
        }
        guard MailGroupService.EveryOne.subscribables.contains(parameters) else {
            return .init(value: "You cannot subscribe to mail group '\(parameters.email)'")
        }
        
        return slackService.fetchUserInfo(userId: senderId)
            .mapError(BotEngine.ErrorMessage.init(error:))
            .flatMap(.concat, subscribeUserToMailGroup(parameters, executor: services.googleAPIResourceExecutor))
    }
    
}

fileprivate func extractMailGroup(from input: String, using result: NSTextCheckingResult) -> MailGroupService.EveryOne? {
    return result.substring(from: input, at: 1).flatMap(MailGroupService.EveryOne.init)
}

fileprivate func subscribeUserToMailGroup(_ mailGroup: MailGroupService.EveryOne, executor: GoogleAPIResourceExecutor) -> (SKCore.User) ->  SignalProducer<String, BotEngine.ErrorMessage> {
    return { user in
        guard let email = user.profile?.email else {
            return .init(error: "I cannot subscribe. Your Slack account email address is not available.")
        }
        
        let mailGroupService = MailGroupService(executor: executor)
        let member = Member(email: email, role: .member)
        
        func subscribeUnlessIncluded(_ members: [Member]) -> SignalProducer<String, BotEngine.ErrorMessage> {
            guard !members.contains(member) else {
                return .init(value: "You are already subscribed to '\(mailGroup.email)'")
            }
            return mailGroupService
                .subscribeMember(member, to: mailGroup)
                .mapError(subscriptionError(member, mailGroup))
                .map { _ in "You have been subscribed to '\(mailGroup.email)'" }
        }
        
        return mailGroupService.members(in: mailGroup)
            .mapError(fetchMembersError(member, mailGroup))
            .flatMap(.concat, subscribeUnlessIncluded)
    }
}

fileprivate func subscriptionError(_ member: Member, _ mailGroup: MailGroupService.EveryOne) -> (GoogleAPI.RequestError) -> BotEngine.ErrorMessage {
    return { error in
        print(error)
        print(error.localizedDescription)
        let message = """
        Couldn't subscribe you (\(member.email)) to '\(mailGroup.email)'. Google's API subscribe method failed.
        
        The returned error message was:
        \(error)
        """
        return .init(message: message)
    }
}

fileprivate func fetchMembersError(_ member: Member, _ mailGroup: MailGroupService.EveryOne) -> (GoogleAPI.RequestError) -> BotEngine.ErrorMessage {
    return { error in
        let message = """
        Couldn't check if you (\(member.email)) are already subscribed to '\(mailGroup.email)'. Google's API members method failed.
        
        The returned error message was:
        \(error)
        """
        return .init(message: message)
    }
}
