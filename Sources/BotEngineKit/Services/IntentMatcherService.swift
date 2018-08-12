//
//  IntentMatcherService.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 8/11/18.
//

import Foundation
import GoogleAPI
import ReactiveSwift
import Result
import SKCore

struct IntentMatcherService {
    
    private let executor: GoogleAPIResourceExecutor
    private let projectId: String
    private let slackService: SlackServiceProtocol
    
    init(projectId: String, executor: GoogleAPIResourceExecutor, slackService: SlackServiceProtocol) {
        self.executor = executor
        self.projectId = projectId
        self.slackService = slackService
    }
    
    func matchIntent(text: String, userId: BotEngine.UserId) -> SignalProducer<String, AnyError> {
        return fetchUserInfo(userId) |> matchIntent(text: text, userId: userId)
    }
    
}

fileprivate extension IntentMatcherService {
    
    func fetchUserInfo(_ userId: BotEngine.UserId) -> SignalProducer<SKCore.User, AnyError> {
        return slackService.fetchUserInfo(userId: userId.value).mapError(AnyError.init)
    }
    
    func matchIntent(text: String, userId: BotEngine.UserId) -> (SKCore.User) -> SignalProducer<String, AnyError> {
        return { user in
            let languageCode = user.locale.flatMap(Intent.Language.init(identifier:)) ?? .latinAmericanSpanish
            return GoogleAPI.dialogflow(projectId: self.projectId)
                .session(sessionId: userId.value)
                .detectIntent(text: text, languageCode: languageCode)
                .execute(with: self.executor)
                .mapError(AnyError.init)
                .map { $0.queryResult.fulfillmentText }
        }
    }
    
}
