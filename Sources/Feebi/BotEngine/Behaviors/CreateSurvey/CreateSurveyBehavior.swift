//
//  CreateSurvey.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/5/18.
//

import Foundation
import ReactiveSwift
import Result
import FeebiKit

struct CreateSurveyBehavior: BehaviorProtocol {
    
    enum JobMessage: AutoCodable {
        
        case sayBye(byeText: String)
        case sayHello(helloText: String)
        
    }
    
    typealias _Behavior = Behavior<State, Effect>
    typealias TransitionOutput = _Behavior.TransitionOutput
    typealias Input = _Behavior.Input
    
    var descriptionForCancellation: String {
        return "the survey creation process"
    }
    
    var schedulable: BehaviorSchedulableJobs<JobExecutor>? {
        return BehaviorSchedulableJobs(
            jobs: [],
            executor: JobExecutor()
        )
    }
    
    private let googleToken: GoogleAPI.Token
    
    init(googleToken: GoogleAPI.Token) {
        self.googleToken = googleToken
    }
    
    func createEffectPerformer(services: EffectPerformerServices) -> EffectPerformer {
        return EffectPerformer(services: services)
    }
    
    func create(message: BehaviorMessage, context: BehaviorMessage.Context) -> TransitionOutput? {
        guard let result = message.text.firstMatch(regex: CreateSurveyBehavior.triggerRegex) else {
            return .none
        }
        
        if let formId = result.substring(from: message.text, at: 5) {
            return .validateFormId(formId)
        } else {
            return .askForFormURL
        }
    }
    
    func update(state: State, input: Input) -> TransitionOutput {
        switch input {
        
        case .message(let message, let context):
            return update(state: state, message: message, context: context)
        
        case .effectResult(let effectResult):
            return update(state: state, effectResult: effectResult)
            
        case .interactiveMessageAnswer(let answer):
            guard case .ready(let survey) = state else {
                print("WARN: This should not happen. Cannot confirmation message while being in state \(state)")
                return .init(state: state)
            }
            if answer == "yes" {
                return .surveyConfirmed(survey: survey)
            } else if answer == "no" {
                return .surveyCancelled(survey: survey)
            } else {
                return .invalidConfirmationInput(survey: survey)
            }
        }
    }

}

// MARK:- State

extension CreateSurveyBehavior {
    
    enum State: BehaviorState {
        
        case waitingForFormId
        case waitingForFormAccessValidation(formId: String)
        case formAccessDenied(formId: String)
        case waitingForDestinataries(formId: String)
        case waitingForDeadline(formId: String, destinataries: [Survey.Destinatary])
        case ready(Survey)
        case confirmed(Survey)
        case cancelled(Survey)
        case created(ActiveSurvey)
        case internalError(Effect.Error)
        
        var isFinalState: Bool {
            if isErrorState {
                return true
            }
            
            switch self {
            case .formAccessDenied, .created, .cancelled:
                return true
            default:
                return false
            }
        }
        
        var isErrorState: Bool {
            if case .internalError = self {
                return true
            } else {
                return false
            }
        }
        
    }
    
}

extension CreateSurveyBehavior {

    
    struct JobExecutor: BehaviorJobExecutor {

        func executeJob(with message: JobMessage) -> SignalProducer<BehaviorJobOutput, AnyError> {
            switch message {
            case .sayBye(let text):
                return SignalProducer(value: .value(behaviorOutput: .textMessage("Bye from \(text)"), channel: "U02F7KUJM"))
            case .sayHello(let text):
                return SignalProducer(value: .value(behaviorOutput: .textMessage("Hello from \(text)"), channel: "U02F7KUJM"))
            }
        }

    }

}

// MARK:- Behavior

fileprivate extension CreateSurveyBehavior {
    
    func update(state: State, message: BehaviorMessage, context: BehaviorMessage.Context) -> TransitionOutput {
        switch state {
        case .waitingForFormId:
            guard let result = message.text.firstMatch(regex: CreateSurveyBehavior.formURLRegex) else {
                return .invalidFormURL
            }
            guard let formId = result.substring(from: message.text, at: 1) else {
                return .invalidFormURL
            }
            return .validateFormId(formId)
            
        case .waitingForFormAccessValidation:
            // While validating form access we ignore all messages
            return .init(state: state)
            
        case .waitingForDestinataries(let formId):
            let entities = message.entities
            guard !entities.isEmpty else {
                return .missingDestinataries(formId: formId)
            }
            return .askForDeadline(formId: formId, destinataries: entities.asDestinataries(using: context))
            
        case .waitingForDeadline(let formId, let destinataries):
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM-yyyy"
            guard let deadline = formatter.date(from: message.text) else {
                return .invalidDateFormat(formId: formId, destinataries: destinataries)
            }
            guard deadline > Date() else {
                return .dateIsNotInTheFuture(formId: formId, destinataries: destinataries)
            }
            let survey = Survey(formId: formId, destinataries: destinataries, deadline: deadline)
            return .confirmSurveyCreation(survey: survey)
            
        case .ready:
            print("WARN - Ignoring messages while in ready state. Waiting for interactive message confirmation")
            return .init(state: state)
           
        case .confirmed:
            print("WARN - Ignoring messages while in confirmed state. Waiting for survey to be activated via effect result.")
            return .init(state: state)
            
        case .created, .cancelled, .formAccessDenied, .internalError:
            print("WARN -This should not happen. Cannot receive messages while in a final state.")
            return .init(state: state)
            
        }
    }
    
    func update(state: State, effectResult: Effect.EffectResult) -> TransitionOutput {
        switch (state, effectResult) {
        case (.waitingForFormAccessValidation(let formId), .success(.formAccessValidated)):
            return .askForDestinataries(formId: formId)
            
        case (.waitingForFormAccessValidation(let formId), .success(.formAccessDenied)):
            return .formAccessDenied(formId: formId)
            
        case (.waitingForFormAccessValidation, .failure(let error)):
            return .internalError(error)
            
        case (.confirmed, .success(.surveyCreated(let survey))):
            return .surveyCreated(survey: survey)
            
        default:
            print("WARN: Unexpected effect result while in state \(state)")
            return .init(state: state)
        }
    }
    
}

fileprivate extension CreateSurveyBehavior {

    // This pattern matches valid Google Form URLs and extracts Form ID.
    // The optional characters '<' and '>' at the beginning and end of the URL
    // are needed because Slack adds them.
    static let formURLPattern = "<?https://docs.google.com/forms/d/([a-zA-Z0-9-_]+)(/edit)?>"

    // This accepts messages like:
    //      create new survey
    //      create survey
    //      create new survey based on https://docs.google.com/forms/d/1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w/edit
    //      create survey based on https://docs.google.com/forms/d/1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w/edit
    //      create new survey from https://docs.google.com/forms/d/1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w/edit
    //      create survey from https://docs.google.com/forms/d/1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w/edit
    //      create new survey based on https://docs.google.com/forms/d/1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w
    //      create survey based on https://docs.google.com/forms/d/1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w
    //      create new survey from https://docs.google.com/forms/d/1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w
    //      create survey from https://docs.google.com/forms/d/1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w
    static let triggerRegex = try! NSRegularExpression(
        pattern: "^create\\s+(new\\s+)?survey(\\s+(based\\s+on|from)\\s+(\(formURLPattern)?))?$",
        options: .caseInsensitive
    )

    static let formURLRegex = try! NSRegularExpression(
        pattern: formURLPattern,
        options: .caseInsensitive
    )

}

// MARK:- Transition outputs

fileprivate extension Behavior.TransitionOutput where
    StateType == CreateSurveyBehavior.State,
    EffectType == CreateSurveyBehavior.Effect {

    static let askForFormURL = CreateSurveyBehavior.TransitionOutput(
        state: .waitingForFormId,
        output: .textMessage("I need a Google Form's URL to create the survey from. A Google Form's URL usually looks like 'https://docs.google.com/forms/d/1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w/edit'.")
    )

    static let invalidFormURL = CreateSurveyBehavior.TransitionOutput(
        state: .waitingForFormId,
        output: .textMessage("That doesn't look like a valid Google Form's URL. Try entering a valid Google Form's URL.")
    )

    static func validateFormId(_ formId: String) -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .waitingForFormAccessValidation(formId: formId),
            output: .textMessage("Give me a second while I validate if I can access the form ..."),
            effect: .validateFormAccess(formId: formId)
        )
    }

    static func formAccessDenied(formId: String) -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .formAccessDenied(formId: formId),
            output: .textMessage("I cannot access form with id '\(formId)'. Check the form's permission and make sure that anyone with the link can access it.")
        )
    }

    static func internalError(_ error: CreateSurveyBehavior.Effect.Error)  -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .internalError(error),
            output: .textMessage("There was some unexpected internal error. You should better talk to the human that created me, and tell him about this issue. Here is the error description: \(error.localizedDescription)")
        )
    }

    static func askForDestinataries(formId: String) -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .waitingForDestinataries(formId: formId),
            output: .textMessage("Cool! I can access the form.\nWho do you want to send this survey to? You can write a combination of channels and users. For example: #sales @capi @guidomb #devs")
        )
    }
    
    static func missingDestinataries(formId: String) -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .waitingForDestinataries(formId: formId),
            output: .textMessage("Those are not valid destinataries. I need to know who do I send this survey to. Remember you can write a combination of channels and users. For example: #sales @capi @guidomb #devs")
        )
    }

    static func askForDeadline(formId: String, destinataries: [Survey.Destinatary]) -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .waitingForDeadline(formId: formId, destinataries: destinataries),
            output: .textMessage("What's the deadline? I only understand dates with the following format dd-MM-yyyy. For example: 29-11-2018. Keep in mind that the deadline should be at least one day in the future.")
        )
    }
    
    static func invalidDateFormat(formId: String, destinataries: [Survey.Destinatary]) -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .waitingForDeadline(formId: formId, destinataries: destinataries),
            output: .textMessage("That's not a valid date format. I only understand dates with the following format dd-MM-yyyy. For example: 29-11-2018. Remember that the deadline should be at least one day in the future.")
        )
    }
    
    static func dateIsNotInTheFuture(formId: String, destinataries: [Survey.Destinatary]) -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .waitingForDeadline(formId: formId, destinataries: destinataries),
            output: .textMessage("The deadline should be at least one day in the future. Give me another date.")
        )
    }

    static func confirmSurveyCreation(survey: Survey) -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .ready(survey),
            output: .confirmationQuestion(
                message: "I'm about to create a new survey that will be sent to \(survey.printableDestinataries()) with deadline '\(survey.deadline)'",
                question: "Do you want me to proceed?"
            )
        )
    }
    
    static func invalidConfirmationInput(survey: Survey) -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .ready(survey),
            output: .textMessage("I'm kind of confused. Do you want me to create the survey?\nYou need to say 'yes' or 'no'")
        )
    }

    static func surveyConfirmed(survey: Survey) -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .confirmed(survey),
            output: .textMessage("Creating survey ..."),
            effect: .createSurvey(survey)
        )
    }
    
    static func surveyCancelled(survey: Survey) -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .cancelled(survey),
            output: .textMessage("Really? OK. Maybe next time.")
        )
    }
    
    static func surveyCreated(survey: ActiveSurvey)  -> CreateSurveyBehavior.TransitionOutput {
        return .init(
            state: .created(survey),
            output: .textMessage("Cool! Your survey has been created. You should be getting answers really soon!")
        )
    }

}

// MARK:- Utility extensions

fileprivate extension Array where Element == BehaviorMessage.Entity {

    func asDestinataries(using context: BehaviorMessage.Context) -> [Survey.Destinatary] {
       return self.map { entity in
            switch entity {
            case .slackChannel(let id, let name):
                return .slackChannel(id: id, name: name)
            case .slackUserId(let userId):
                return .slackUser(id: userId, info: context.userEntitiesInfo[userId])
            }
        }
    }

}

fileprivate extension Survey {

    func printableDestinataries() -> String {
        return self.destinataries
            .dropLast()
            .map(String.init)
            .joined(separator: ", ")
            + (self.destinataries.count > 1 ? " and " : "")
            + String(describing: self.destinataries.last!) // force unwrap is safe because at least 1 destinatary is guaranteed
    }

}
