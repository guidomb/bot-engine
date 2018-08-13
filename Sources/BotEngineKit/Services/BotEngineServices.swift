//
//  BotEngineServices.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 8/12/18.
//

import Foundation

extension BotEngine.Services {
    
    public var userLanguageService: UserLanguageService {
        guard let slackService = self.slackService else {
            fatalError("ERROR - Slack service is not available")
        }
        return .init(slackService: slackService)
    }
    
    var intentMatcher: IntentMatcherService {
        return .init(
            projectId: self.googleProjectId,
            executor: self.googleAPIResourceExecutor,
            languageService: userLanguageService
        )
    }

}
