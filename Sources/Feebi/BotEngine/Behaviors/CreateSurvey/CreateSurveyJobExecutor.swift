//
//  CreateSurveyJobExecutor.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/26/18.
//

import Foundation
import ReactiveSwift
import Result
import FeebiKit

extension CreateSurveyBehavior {
    
    struct JobExecutor: BehaviorJobExecutor {
    
        enum Error: Swift.Error {
            
            case unsupportedMessage(JobMessage)
            
            var asAnyError: AnyError {
                return AnyError(self)
            }
        }
        
        private let repository: ObjectRepository
        
        init(repository: ObjectRepository) {
            self.repository = repository
        }
        
        func executeJob(with message: JobMessage) -> SignalProducer<BehaviorJobOutput, AnyError> {
            guard case .monitorSurvey(let surveyId) = message else {
                return SignalProducer(error: Error.unsupportedMessage(message).asAnyError)
            }
            
            return repository.fetch(byId: surveyId)
                .flatMap(.concat, askPendingRespondersToCompleteSurvey)
        }
        
    }
    
}

fileprivate extension CreateSurveyBehavior.JobExecutor {
    
    func askPendingRespondersToCompleteSurvey(_ survey: ActiveSurvey) -> SignalProducer<BehaviorJobOutput, AnyError> {
        guard survey.id != nil else {
            fatalError("ERROR - Cannot handle non-persisted active survey")
        }
        guard !survey.isCompleted else {
            return repository.delete(object: survey).map(surveyCompletedOutput)
        }
        
        let channeledOutputs = survey.pendingResponders.map { pendingResponder in
            ChanneledBehaviorOutput(
                output: .confirmationQuestion(
                    message: "Hey! We would like to get your thoughts about something.",
                    question: "Would you mind answering a quick survey? I promise it will only take you a few minutes"
                ),
                channel: pendingResponder,
                transform: answerSurveyTransforms(survey: survey, channel: pendingResponder)
            )
        }
        return SignalProducer(value: .success(outputs: channeledOutputs))
    }
    
    func surveyCompletedOutput(for survey: ActiveSurvey) -> BehaviorJobOutput {
        guard let surveyId = survey.id else {
            fatalError("ERROR - Cannot create job output for non-persisted active survey")
        }
        let message = "Survey with id *'\(surveyId)'* is completed. There were *\(survey.responders.count)* responders *out of* a total of *\(survey.destinataries.count)* destinataries."
        return .completed(outputs: [.init(output: .textMessage(message), channel: survey.survey.creatorId)])
    }
    
}

fileprivate func answerSurveyTransforms(survey: ActiveSurvey, channel: ChannelId) -> ResponseTransform {
    return ResponseTransform(
        expectedResponse: .interactiveMessageAnswer(
            answer: "yes",
            channel: channel,
            senderId: survey.survey.creatorId
        ),
        transformedResponse: .message(
            message: .init(
                channel: channel,
                senderId: survey.survey.creatorId,
                text: "answer survey \(survey.id?.description ?? "")"
            ),
            context: .init()
        )
    )
}
