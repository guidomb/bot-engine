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
    
    enum Effect {
        
        enum Error: Swift.Error {
            
            case googleAPIError(GoogleAPI.RequestError)
            
        }
        
        enum Response {
            
            case formAccessValidated(formId: String)
            case formAccessDenied(formId: String)
            
        }
        
        case validateFormAccess(formId: String)
        case createSurvey(Survey)
        
    }
    
}

extension CreateSurveyBehavior {
    
    struct EffectPerformer: BehaviorEffectPerformer {
        
        typealias CreateSurveyEffectfulAction = EffectfulAction<Effect.Response, Effect.Error>
        
        private let googleToken: GoogleAPI.Token
        
        init(googleToken: GoogleAPI.Token) {
            self.googleToken = googleToken
        }
        
        func perform(effect: Effect) -> CreateSurveyEffectfulAction {
            switch effect {
                
            case .validateFormAccess(let formId):
                return GoogleAPI.drive.files.get(byId: formId)
                    .execute(using: googleToken)
                    .then(successfulResponse(.formAccessValidated(formId: formId)))
                    .flatMapError(handleFormAccessFailure(formId: formId))
                    .asEffectfulAction
                
            case .createSurvey(let survey):
                return CreateSurveyBehavior.EffectResultProducer.empty.asEffectfulAction
                
            }
        }
        
    }
    
}

fileprivate extension CreateSurveyBehavior.EffectPerformer {
    
    func handleFormAccessFailure(formId: String) -> (GoogleAPI.RequestError) -> CreateSurveyBehavior.EffectResultProducer {
        return { requestError in
            guard case .resourceError(let resourceError) = requestError, resourceError.error.code == 404 else {
                return .init(value: .failure(.googleAPIError(requestError)))
            }
            return .init(value: .success(.formAccessDenied(formId: formId)))
        }
    }
    
    func successfulResponse(_ response: CreateSurveyBehavior.Effect.Response) -> CreateSurveyBehavior.EffectResultProducer {
        return .init(value: .success(response))
    }
    
}

fileprivate extension SignalProducer where Value == Result<CreateSurveyBehavior.Effect.Response, CreateSurveyBehavior.Effect.Error>, Error == NoError {
    
    var asEffectfulAction: EffectfulAction<CreateSurveyBehavior.Effect.Response, CreateSurveyBehavior.Effect.Error> {
        return .effectResultProducer(self)
    }
    
}
