//
//  Effects.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation
import FeebiKit
import ReactiveSwift
import Result

extension CreateSurveyBehavior {
    
    enum Effect: BehaviorEffect {
        
        typealias ResponseType = Response
        typealias ErrorType = Error
        typealias JobMessageType = CreateSurveyBehavior.JobMessage
        
        enum Error: Swift.Error {
            
            case googleAPIError(GoogleAPI.RequestError)
            case repositoryError(AnyError)
            case slackServiceError(SlackServiceError)
            
        }
        
        enum Response {
            
            case formAccessValidated(formId: String)
            case formAccessDenied(formId: String)
            case surveyCreated(ActiveSurvey)
            
        }
        
        case validateFormAccess(formId: String)
        case createSurvey(Survey)
        
    }
    
}

extension CreateSurveyBehavior {
    
    struct EffectPerformer: BehaviorEffectPerformer {
        
        private let googleToken: GoogleAPI.Token
        private let repository: ObjectRepository
        private let slackService: SlackServiceProtocol
        
        init(services: EffectPerformerServices) {
            guard let googleToken = (services.context["GoogleToken"] as? GoogleAPI.Token) else {
                fatalError("ERROR - Google API token is not available in services context.")
            }
            guard let slackService = services.slackService else {
                fatalError("ERROR - Slack service instance is not available in services.")
            }
            self.googleToken = googleToken
            self.repository = services.repository
            self.slackService = slackService
        }
        
        func perform(effect: Effect) -> EffectfulAction<Effect> {
            switch effect {

            case .validateFormAccess(let formId):
                return GoogleAPI.drive.files.get(byId: formId)
                    .execute(using: googleToken)
                    .then(successfulResponse(.formAccessValidated(formId: formId)))
                    .flatMapError(handleFormAccessFailure(formId: formId))
                    .asEffectfulAction

            case .createSurvey(let survey):
                 return createActiveSurvey(survey)
                    .flatMap(.concat, saveActiveSurvey)
                    .flatMapError(failureResponse)
                    .asEffectfulAction

            }
        }
        
    }
    
}

fileprivate extension CreateSurveyBehavior.EffectPerformer {
    
    func createActiveSurvey(_ survey: Survey) -> SignalProducer<ActiveSurvey, CreateSurveyBehavior.Effect.Error> {
        let destinataries = Set<String>(survey.userDestinataryIds)
        let channelDestinataryIds = survey.channelDestinataryIds
        if !channelDestinataryIds.isEmpty {
            return SignalProducer.merge(channelDestinataryIds.map(slackService.fetchUsersInChannel))
                .collect()
                .map { result in
                    var newDestinataries = Set(result.flatMap { $0.compactMap { $0.id } })
                    for destinatary in destinataries {
                        newDestinataries.insert(destinatary)
                    }
                    return ActiveSurvey(survey: survey, destinataries: newDestinataries)
                }
                .mapError(CreateSurveyBehavior.Effect.Error.slackServiceError)
        } else {
            return .init(value: ActiveSurvey(survey: survey, destinataries: destinataries))
        }
    }
    
    func saveActiveSurvey(_ survey: ActiveSurvey) -> CreateSurveyBehavior.Effect.EffectOutputProducer {
        return repository.save(object: survey)
            .flatMap(.concat) { successfulResponse(.surveyCreated($0)) }
            .flatMapError { failureResponse(.repositoryError($0)) }
    }
    
}

fileprivate func handleFormAccessFailure(formId: String) -> (GoogleAPI.RequestError) -> CreateSurveyBehavior.Effect.EffectOutputProducer {
    return { requestError in
        guard case .resourceError(let resourceError) = requestError, resourceError.error.code == 404 else {
            return .init(value: (.failure(.googleAPIError(requestError)), .none))
        }
        return .init(value: (.success(.formAccessDenied(formId: formId)), .none))
    }
}

fileprivate func successfulResponse(_ response: CreateSurveyBehavior.Effect.Response, job: SchedulableJob<CreateSurveyBehavior.JobMessage>? = .none) -> CreateSurveyBehavior.Effect.EffectOutputProducer {
    return .init(value: (.success(response), job))
}

fileprivate func failureResponse(_ error: CreateSurveyBehavior.Effect.Error) -> CreateSurveyBehavior.Effect.EffectOutputProducer {
    return .init(value: (.failure(error), .none))
}

fileprivate extension SignalProducer where
    Value == CreateSurveyBehavior.Effect.EffectOutput,
    Error == NoError {

    var asEffectfulAction: EffectfulAction<CreateSurveyBehavior.Effect> {
        return .effectResultProducer(self)
    }

}
