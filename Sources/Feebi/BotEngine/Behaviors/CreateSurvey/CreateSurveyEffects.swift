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
            
        }
        
        enum Response {
            
            case formAccessValidated(formId: String)
            case formAccessDenied(formId: String)
            case surveyCreated(Survey)
            
        }
        
        case validateFormAccess(formId: String)
        case createSurvey(Survey)
        
    }
    
}

extension CreateSurveyBehavior {
    
    struct EffectPerformer: BehaviorEffectPerformer {
        
        private let googleToken: GoogleAPI.Token
        
        init(googleToken: GoogleAPI.Token) {
            self.googleToken = googleToken
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
                let job = SchedulableJob(interval: 10.0, message: CreateSurveyBehavior.JobMessage.sayBye(byeText: "Mister"))
                return successfulResponse(.surveyCreated(survey), job: job).asEffectfulAction

            }
        }
        
    }
    
}

fileprivate extension CreateSurveyBehavior.EffectPerformer {
    
    func handleFormAccessFailure(formId: String) -> (GoogleAPI.RequestError) -> CreateSurveyBehavior.Effect.ResultProducer {
        return { requestError in
            guard case .resourceError(let resourceError) = requestError, resourceError.error.code == 404 else {
                return .init(value: (.failure(.googleAPIError(requestError)), .none))
            }
            return .init(value: (.success(.formAccessDenied(formId: formId)), .none))
        }
    }
    
    func successfulResponse(_ response: CreateSurveyBehavior.Effect.Response, job: SchedulableJob<CreateSurveyBehavior.JobMessage>? = .none) -> CreateSurveyBehavior.Effect.ResultProducer {
        return .init(value: (.success(response), job))
    }
    
}

fileprivate extension SignalProducer where
    Value == (result: CreateSurveyBehavior.Effect.EffectResult, job: SchedulableJob<CreateSurveyBehavior.Effect.JobMessageType>?),
    Error == NoError {

    var asEffectfulAction: EffectfulAction<CreateSurveyBehavior.Effect> {
        return .effectResultProducer(self)
    }

}
