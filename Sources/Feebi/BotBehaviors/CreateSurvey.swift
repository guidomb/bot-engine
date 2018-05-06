//
//  CreateSurvey.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/5/18.
//

import Foundation

struct Survey {
    
    enum Destinatary {
        
        case channel(name: String)
        case user(id: String)
        
    }
    
    let formId: String
    let destinataries: [Destinatary]
    let deadline: Date
    
}

struct CreateSurveyBehavior: BehaviorProtocol {
    
    enum State {
        
        case waitingForFormId
        case waitingForFormAccessValidation(formId: String)
        case formAccessDenied(formId: String)
        case waitingForDestinataries(formId: String)
        case waitingForDeadline(formId: String, destinataries: [Survey.Destinatary])
        case ready(Survey)
        
        var isFinalState: Bool {
            switch self {
            case .formAccessDenied, .ready:
                return true
            default:
                return false
            }
        }
        
    }
    
    static func parse(input: Behavior.Message) -> Instance? {
        let matchingResult = matches(input: input.text)
        guard !matchingResult.isEmpty else {
            return .none
        }
        guard let result = matchingResult.first else {
            return .none
        }
        
        let behavior: BehaviorProtocol
        let effect: Behavior.Effect?
        let output: Behavior.Output
        if let formId = result.substring(from: input.text, at: 4) {
            behavior = CreateSurveyBehavior(state: .waitingForFormAccessValidation(formId: formId))
            effect = .validateFormAccess(formId: formId)
            output = .textMessage("Give me a second while I validate that I can access the Google Form ...")
        } else {
            behavior = CreateSurveyBehavior(state: .waitingForFormId)
            effect = .none
            output = .textMessage("I need a Google Form's URL to create the survey from. A Google Form's URL usually looks like 'https://docs.google.com/forms/d/1mlteVfq46HlO4VPR4LQjUKAqGS8f8fE7AtqWapqoM3w/edit'.")
        }
        
        let transition = Behavior.Transition(
            input: .message(input),
            output: output,
            effect: effect
        )
        return (behavior, (false, transition))
    }
    
    private(set) var state: State
    
    private init(state: State) {
        self.state = state
    }
    
    mutating func update(input: Behavior.Message) -> Behavior.StateTransition {
        return (false, Behavior.Transition(input: .message(input), output: .none, effect: .none))
    }
    
    mutating func update(input: Behavior.TaggedResult) -> Behavior.StateTransition {
        return (false, Behavior.Transition(input: .effectResult(input), output: .none, effect: .none))
    }
    
}

fileprivate extension CreateSurveyBehavior {
    
    static let triggerRegex = try! NSRegularExpression(
        pattern: "^create\\s+new\\s+survey(\\s+(based\\s+on|from)\\s+(<?https://docs.google.com/forms/d/([a-zA-Z0-9]+)(/edit)?>?))?$",
        options: .caseInsensitive
    )
    
    static func matches(input: String) -> [NSTextCheckingResult] {
        let inputRange = NSRange(location: 0, length: input.count)
        return triggerRegex.matches(in: input, options: [], range: inputRange)
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
