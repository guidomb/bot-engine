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

enum SlackServiceError: Swift.Error {
    
    case connectionAlreadyEstablished
    case webAPINotAvailable
    case sendMessageFailure(SlackError)
    
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
    
}

fileprivate extension SlackService {
    
    func createSlackClient() -> SlackKit {
        slackKit = SlackKit()
        slackKit?.addRTMBotWithAPIToken(token)
        slackKit?.addWebAPIAccessWithToken(token)
        return slackKit!
    }
    
}
