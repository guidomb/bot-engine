//
//  CreateSurvey.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/5/18.
//

import Foundation

struct Survey {
    
    enum Destinatary: CustomStringConvertible {
        
        case slackChannel(id: String, name: String)
        case slackUser(id: String, info: UserEntityInfo?)
        
        var description: String {
            switch self {
            case .slackChannel(_, let name):
                return "#\(name)"
            case .slackUser(let userId, let info):
                if let name = info?.name {
                    return "@\(name)"
                } else {
                    return userId
                }
            }
        }
        
    }
    
    let formId: String
    let destinataries: [Destinatary]
    let deadline: Date
    
}

struct CreateSurveyBehavior: BehaviorProtocol {
    
    static func parse(input: Behavior.Message, context: Behavior.Context) -> Behavior.InitialState? {
        guard let result = input.text.firstMatch(regex: triggerRegex) else {
            return .none
        }
        
        let behavior: BehaviorProtocol
        let effect: Behavior.Effect?
        let output: Behavior.Output
        if let formId = result.substring(from: input.text, at: 5) {
            behavior = CreateSurveyBehavior(state: .waitingForFormAccessValidation(formId: formId))
            effect = .validateFormAccess(formId: formId)
            output = .textMessage("Give me a second while I validate that I can access the Google Form ...")
        } else {
            behavior = CreateSurveyBehavior(state: .waitingForFormId)
            effect = .none
            output = .textMessage("I need a Google Form's URL to create the survey from. A Google Form's URL usually looks like 'https://docs.google.com/forms/d/1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w/edit'.")
        }
        
        return Behavior.InitialState(behavior: behavior, output: output, effect: effect)
    }
    
    private var state: State
    
    var isInFinalState: Bool {
        return state.isFinalState
    }
    
    var isInErrorState: Bool {
        return state.isErrorState
    }
    
    var descriptionForCancellation: String {
        return "the survey creation process"
    }
    
    private init(state: State) {
        self.state = state
    }
    
    mutating func update(input: Behavior.Message, context: Behavior.Context) -> Behavior.StateTransitionOutput {
        switch state {
        case .waitingForFormId:
            guard let result = input.text.firstMatch(regex: CreateSurveyBehavior.formURLRegex) else {
                return .invalidFormURL
            }
            guard let formId = result.substring(from: input.text, at: 1) else {
                return .invalidFormURL
            }
            state = .waitingForFormAccessValidation(formId: formId)
            return .validateFormId(formId)
            
        case .waitingForFormAccessValidation:
            // While validating form access we ignore all messages
            return .void
            
        case .waitingForDestinataries(let formId):
            let entities = input.entities
            guard !entities.isEmpty else {
                return .missingDestinataries
            }

            state = .waitingForDeadline(formId: formId, destinataries: entities.asDestinataries(using: context))
            return .askForDeadline

        case .waitingForDeadline(let formId, let destinataries):
            let formatter = DateFormatter()
            formatter.dateFormat = "dd-MM-yyyy"
            guard let deadline = formatter.date(from: input.text) else {
                return .invalidDateFormat
            }
            guard deadline > Date() else {
                return .dateIsNotInTheFuture
            }
            
            let survey = Survey(formId: formId, destinataries: destinataries, deadline: deadline)
            state = .ready(survey)
            return .confirmSurveyCreation(survey: survey)

        case .ready(let survey):
            if input.text.lowercased() == "yes" {
                state = .confirmed(survey)
                return .surveyCreated
            } else if input.text.lowercased() == "no" {
                state = .cancelled(survey)
                return .surveyCancelled
            } else {
                return .invalidConfirmation
            }
            
        case .confirmed, .cancelled, .formAccessDenied, .internalError:
            print("WARN: This should not happen. Cannot receive messages while in a final state.")
            return .void

        }
    }
    
    mutating func update(input: Behavior.TaggedResult) -> Behavior.StateTransitionOutput {
        guard case .waitingForFormAccessValidation(let formId) = state else {
            print("WARN: Unexpected effect result while in state \(state)")
            return .void
        }
        
        switch input.result {
        case .success(.formAccessValidated):
            state = .waitingForDestinataries(formId: formId)
            return .askForDestinataries
            
        case .success(.formAccessDenied):
            state = .formAccessDenied(formId: formId)
            return .formAccessDenied(formId: formId)
        
        case .failure(let error):
            state = .internalError(error)
            return .internalError(error)
        
        }
    }
    
}

fileprivate extension CreateSurveyBehavior {
    
    enum State {
        
        case waitingForFormId
        case waitingForFormAccessValidation(formId: String)
        case formAccessDenied(formId: String)
        case waitingForDestinataries(formId: String)
        case waitingForDeadline(formId: String, destinataries: [Survey.Destinatary])
        case ready(Survey)
        case confirmed(Survey)
        case cancelled(Survey)
        case internalError(Behavior.Effect.Error)
        
        var isFinalState: Bool {
            if isErrorState {
                return true
            }
            
            switch self {
            case .formAccessDenied, .confirmed, .cancelled:
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

fileprivate extension Behavior.StateTransitionOutput {
    
    static let invalidFormURL = Behavior.StateTransitionOutput(
        output: .textMessage("That doesn't look like a valid Google Form's URL. Try entering a valid Google Form's URL.")
    )
    
    static func validateFormId(_ formId: String) -> Behavior.StateTransitionOutput {
        return Behavior.StateTransitionOutput(
            output: .textMessage("Give me a second while I validate if I can access the form ..."),
            effect: .validateFormAccess(formId: formId)
        )
    }
    
    static func formAccessDenied(formId: String) -> Behavior.StateTransitionOutput {
        return Behavior.StateTransitionOutput(
            output: .textMessage("I cannot access form with id '\(formId)'. Check the form's permission and make sure that anyone with the link can access it.")
        )
    }
    
    static func internalError(_ error: Behavior.Effect.Error)  -> Behavior.StateTransitionOutput {
        return Behavior.StateTransitionOutput(
            output: .textMessage("There was some unexpected internal error. You should better talk to the human that created me, and tell him about this issue. Here is the error description: \(error.localizedDescription)")
        )
    }
    
    static let askForDestinataries = Behavior.StateTransitionOutput(
        output: .textMessage("Cool! I can access the form.\nWho do you want to send this survey to? You can write a combination of channels and users. For example: #sales @capi @guidomb #devs")
    )
    
    static let missingDestinataries = Behavior.StateTransitionOutput(
        output: .textMessage("Those are not valid destinataries. I need to know who do I send this survey to. Remember you can write a combination of channels and users. For example: #sales @capi @guidomb #devs")
    )
    
    static let askForDeadline = Behavior.StateTransitionOutput(
        output: .textMessage("What's the deadline? I only understand dates with the following format dd-MM-yyyy. For example: 29-11-2018. Keep in mind that the deadline should be at least one day in the future.")
    )
    
    static let invalidDateFormat = Behavior.StateTransitionOutput(
        output: .textMessage("That's not a valid date format. I only understand dates with the following format dd-MM-yyyy. For example: 29-11-2018. Remember that the deadline should be at least one day in the future.")
    )
    
    static let dateIsNotInTheFuture = Behavior.StateTransitionOutput(
        output: .textMessage("The deadline should be at least one day in the future. Give me another date.")
    )
    
    static func confirmSurveyCreation(survey: Survey) -> Behavior.StateTransitionOutput {
        return Behavior.StateTransitionOutput(
            output: .textMessage("I'm about to create a new survey that will be sent to \(survey.printableDestinataries()) with deadline '\(survey.deadline)'.\nDo you want me to proceed?")
        )
    }
    
    static let invalidConfirmation = Behavior.StateTransitionOutput(
        output: .textMessage("I'm kind of confused. Do you want me to create the survey?\nYou need to say 'yes' or 'no'")
    )
    
    static let surveyCreated = Behavior.StateTransitionOutput(
        output: .textMessage("Cool! Your survey has been created. You should be getting answers really soon!")
    )
    
    static let surveyCancelled = Behavior.StateTransitionOutput(
        output: .textMessage("Really? OK. Maybe next time.")
    )
}

fileprivate extension String {
    
    func matches(regex: NSRegularExpression) -> [NSTextCheckingResult] {
        let inputRange = NSRange(location: 0, length: self.count)
        return regex.matches(in: self, options: [], range: inputRange)
    }
    
    func firstMatch(regex: NSRegularExpression) -> NSTextCheckingResult? {
        return self.matches(regex: regex).first
    }
    
}

fileprivate extension NSTextCheckingResult {
    
    func substring(from string: String, at index: Int) -> String? {
        guard index < self.numberOfRanges else {
            return nil
        }
        guard let range = Range(self.range(at: index), in: string) else {
            return nil
        }
        return String(string[range])
    }
    
}

fileprivate extension Array where Element == Behavior.Message.Entity {
    
    func asDestinataries(using context: Behavior.Context) -> [Survey.Destinatary] {
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
