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
    private let languageService: UserLanguageService
    
    init(projectId: String, executor: GoogleAPIResourceExecutor, languageService: UserLanguageService) {
        self.executor = executor
        self.projectId = projectId
        self.languageService = languageService
    }
    
    func matchIntent(text: String, userId: BotEngine.UserId) -> SignalProducer<String, AnyError> {
        return fetchUserIntentLanguage(for: userId) |> matchIntent(text: text, userId: userId)
    }
    
}

fileprivate extension IntentMatcherService {
    
    func fetchUserIntentLanguage(for userId: BotEngine.UserId) -> SignalProducer<Intent.Language, AnyError> {
        return languageService.fetchUserIntentLanguage(userId: userId)
    }
    
    func matchIntent(text: String, userId: BotEngine.UserId) -> (Intent.Language) -> SignalProducer<String, AnyError> {
        return { languageCode in
            return GoogleAPI.dialogflow(projectId: self.projectId)
                .session(sessionId: userId.value)
                .detectIntent(text: text, languageCode: languageCode)
                .execute(with: self.executor)
                .mapError(AnyError.init)
                .map { $0.queryResult.fulfillmentText }
        }
    }
    
}
