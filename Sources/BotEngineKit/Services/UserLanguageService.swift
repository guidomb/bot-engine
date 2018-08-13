//
//  UserLanguageService.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 8/12/18.
//

import Foundation
import ReactiveSwift
import Result
import GoogleAPI

public struct UserLanguageService {
    
    private let slackService: SlackServiceProtocol
    
    init(slackService: SlackServiceProtocol) {
        self.slackService = slackService
    }
    
    public func fetchUserLanguage(userId: BotEngine.UserId) -> SignalProducer<String?, AnyError> {
        return fetchUserInfo(userId).map(\.locale)
    }
    
    public func fetchUserIntentLanguage(userId: BotEngine.UserId) -> SignalProducer<Intent.Language, AnyError> {
        return fetchUserLanguage(userId: userId).map { $0.flatMap(Intent.Language.init(identifier:)) ?? .latinAmericanSpanish }
    }
    
}

fileprivate extension UserLanguageService {
    
    func fetchUserInfo(_ userId: BotEngine.UserId) -> SignalProducer<SKCore.User, AnyError> {
        return slackService.fetchUserInfo(userId: userId.value).mapError(AnyError.init)
    }
    
}
