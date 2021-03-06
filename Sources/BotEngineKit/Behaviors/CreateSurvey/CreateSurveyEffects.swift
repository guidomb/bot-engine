//
//  Effects.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation
import GoogleAPI
import ReactiveSwift
import Result

extension CreateSurveyBehavior {
    
    public enum Effect: BehaviorEffect {
        
        public typealias ResponseType = Response
        public typealias ErrorType = Error
        public typealias JobMessageType = CreateSurveyBehavior.JobMessage
        
        public enum Error: Swift.Error {
            
            case googleAPIError(GoogleAPI.RequestError)
            case repositoryError(AnyError)
            case slackServiceError(SlackServiceError)
            
        }
        
        public enum Response {
            
            case formAccessValidated(formId: String)
            case formAccessDenied(formId: String)
            case surveyCreated(ActiveSurvey)
            
        }
        
        case validateFormAccess(formId: String)
        case createSurvey(Survey)
        
    }
    
}

extension CreateSurveyBehavior {
    
    public struct EffectPerformer: BehaviorEffectPerformer {
        
        private let executor: GoogleAPIResourceExecutor
        private let repository: ObjectRepository
        private let slackService: SlackServiceProtocol
        
        init(services: BotEngine.Services) {
            guard let slackService = services.slackService else {
                fatalError("ERROR - Slack service instance is not available in services.")
            }
            self.executor = services.googleAPIResourceExecutor
            self.repository = services.repository
            self.slackService = slackService
        }
        
        public func perform(effect: Effect, for channel: ChannelId) -> Effect.EffectOutputProducer {
            switch effect {

            case .validateFormAccess(let formId):
                return GoogleAPI.drive.files.get(byId: formId)
                    .execute(with: executor)
                    .then(successfulResponse(.formAccessValidated(formId: formId)))
                    .flatMapError(handleFormAccessFailure(formId: formId))

            case .createSurvey(let survey):
                return createActiveSurvey(survey, creator: channel)
                    .flatMap(.concat, saveActiveSurvey)
                    .flatMapError(failureResponse)

            }
        }
        
    }
    
}

fileprivate extension CreateSurveyBehavior.EffectPerformer {
    
    func createActiveSurvey(_ survey: Survey, creator: ChannelId) -> SignalProducer<ActiveSurvey, CreateSurveyBehavior.Effect.Error> {
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
            .flatMap(.concat) { successfulResponse(.surveyCreated($0), job: monitorSurvey($0)) }
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

fileprivate func monitorSurvey(_ activeSurvey: ActiveSurvey) -> SchedulableJob<CreateSurveyBehavior.JobMessage> {
    guard let surveyId = activeSurvey.id else {
        fatalError("ERROR - Cannot monitor survey that is not persisted ")
    }
    let timeZone = CreateSurveyBehavior.surveyMonitorIntervalTimeZoneIdentifier
    guard let dayTime = DayTime.at("11:30", in: timeZone) else {
        fatalError("ERROR - Cannot create active survey monitor interval day time.")
    }
    
    return SchedulableJob(interval: .everyDay(at: dayTime), message: .monitorSurvey(surveyId: surveyId))
}
