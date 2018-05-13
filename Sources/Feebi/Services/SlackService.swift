//
//  Slack.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/5/18.
//

import Foundation
import ReactiveSwift
import SlackKit
import Result
import FeebiKit

enum SlackServiceError: Swift.Error {
    
    case connectionAlreadyEstablished
    case webAPINotAvailable
    case sendMessageFailure(SlackError)
    case fetchUserInfoFailure(SlackError)
    
}

protocol SlackServiceProtocol {
    
    func start() -> SignalProducer<Event, SlackServiceError>
    
    func sendMessage(channel: String, text: String) -> SignalProducer<(), SlackServiceError>
    
}

final class SlackService: SlackServiceProtocol {
    
    private let token: String
    private var slackKit: SlackKit?
    
    init(token: String) {
        self.token = token
    }
    
    func start() -> SignalProducer<Event, SlackServiceError> {
        guard self.slackKit == nil else {
            return SignalProducer(error: .connectionAlreadyEstablished)
        }
        return SignalProducer { observer, lifetime in
            let slackKit = self.createSlackClient()
            slackKit.notificationForEvent(.message) { event, _ in
                guard event.message?.user != nil else {
                    // We ignore messages from non-authenticated users
                    // to avoid something that looks like a SlackKit bug.
                    //
                    // It seems that every message we send back to the users
                    // gets sent to this closure which means that we receive
                    // the messages that we send to the user which generates
                    // an infinite loop of messages.
                    return
                }
                // TODO Only responde to mentions in group channels and start a direct conversation
                observer.send(value: event)
            }
            lifetime.observeEnded {
                self.slackKit = nil
            }
        }
    }
    
    func sendMessage(channel: String, text: String) -> SignalProducer<(), SlackServiceError> {
        guard let webAPI = self.slackKit?.webAPI else {
            return SignalProducer(error: .webAPINotAvailable)
        }
        return SignalProducer { observer, _ in
            webAPI.sendMessage(
                channel: channel,
                text: text,
                success: { _ in observer.sendCompleted() },
                failure: { observer.send(error: .sendMessageFailure($0)) }
            )
        }
    }
    
    func fetchUsers(userIds: [String]) -> SignalProducer<[User], SlackServiceError>{
        return SignalProducer.merge(userIds.map(fetchUserInfo)).collect()
    }
    
    func fetchUserInfo(userId: String)  -> SignalProducer<User, SlackServiceError>{
        guard let webAPI = self.slackKit?.webAPI else {
            return SignalProducer(error: .webAPINotAvailable)
        }
        return SignalProducer { observer, _ in
            webAPI.userInfo(
                id: userId,
                success: { user in
                    observer.send(value: user)
                    observer.sendCompleted()
                },
                failure: { observer.send(error: .fetchUserInfoFailure($0)) }
            )
        }
    }
}

struct SlackOutputRenderer: BehaviorOutputRenderer {
    
    let slackService: SlackServiceProtocol
    
    func render(output: BehaviorOutput, forChannel channel: ChannelId) {
        switch output {
        case .textMessage(let message):
            slackService.sendMessage(channel: channel, text: message).startWithFailed { error in
                print("Error sending message:")
                print("\tChannel: \(channel)")
                print("\tMessage: \(message)")
                print("\tError: \(error)")
                print("")
            }
            
        case .confirmationQuestion(let yesMessage, let noMessage):
            slackService.sendMessage(channel: channel, text: "I need confirmation bitch!").startWithFailed { error in
                print("Error sending message:")
                print("\tChannel: \(channel)")
                print("\tError: \(error)")
                print("")
            }
        }
    }
    
}

extension UserEntityInfo {
    
    static func from(user: User) -> UserEntityInfo {
        return UserEntityInfo(
            id: user.id!,
            name: user.name,
            email: user.profile?.email,
            firstName: user.profile?.firstName,
            lastName: user.profile?.lastName
        )
    }
    
}

extension BotEngine {
    
    static func slackBotEngine(slackToken: String, googleToken: GoogleAPI.Token) -> BotEngine {
        let slackService = SlackService(token: slackToken)
        let outputRenderer = SlackOutputRenderer(slackService: slackService)
        let messageProducer: BotEngine.MessageProducer = slackService.start()
            .flatMapError { _ in .empty }
            .filterMap(eventToBehaviorMessage)
            .flatMap(.concat, addContextToBehaviorMessage(slackService: slackService))
        
        return BotEngine(inputProducer: messageProducer, outputRenderer: outputRenderer)
    }
    
}

fileprivate extension SlackService {
    
    func createSlackClient() -> SlackKit {
        slackKit = SlackKit()
        slackKit?.addRTMBotWithAPIToken(token)
        slackKit?.addWebAPIAccessWithToken(token)
        return slackKit!
    }
    
}

fileprivate func eventToBehaviorMessage(_ event: Event) -> BehaviorMessage? {
    guard let channel = event.message?.channel, let messageText = event.message?.text else {
        return nil
    }
    return BehaviorMessage(source: .slack, channel: channel, text: messageText)
}

fileprivate func addContextToBehaviorMessage(slackService: SlackService) -> (BehaviorMessage) -> BotEngine.MessageProducer {
    return { message in
        guard !message.entities.isEmpty else {
            return .init(value: (message, BehaviorMessage.Context()))
        }
        
        return slackService.fetchUsers(userIds: message.slackUserIdEntities)
            .map { (message, .with(users: $0)) }
            .flatMapError { _ in .empty }
    }
}

fileprivate extension BehaviorMessage.Context {
    
    static func with(users: [User]) -> BehaviorMessage.Context {
        return BehaviorMessage.Context(userEntitiesInfo: users.map(UserEntityInfo.from))
    }
    
}
