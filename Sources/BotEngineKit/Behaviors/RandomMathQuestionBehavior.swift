////
////  RandomMathQuestionBehavior.swift
////  Feebi
////
////  Created by Guido Marucci Blas on 5/26/18.
////
//
import Foundation
import ReactiveSwift
import Result

public struct RandomMathQuestionBehavior: BehaviorProtocol {

    public typealias _Behavior = Behavior<State, NoEffect>
    public typealias TransitionOutput = _Behavior.TransitionOutput
    public typealias Input = _Behavior.Input

    let questions = [
        ("2 + 2", "4"),
        ("2 + 4", "6"),
        ("10 - 5", "5"),
        ("5 x 5", "25")
    ]
    
    public init() { }
    
    public func createSchedulable(services: BotEngine.Services) -> BehaviorSchedulableJobs<NoBehaviorJobExecutor>? {
        return .none
    }

    public func createEffectPerformer(services: BotEngine.Services) -> NoEffectPerformer {
        return NoEffectPerformer()
    }

    public func create(message: BehaviorMessage, context: BehaviorMessage.Context) -> TransitionOutput? {
        if message.text.firstMatch(regex: RandomMathQuestionBehavior.askRegex) != nil {
            guard case .slackUserId(let userId)? = message.entities.first else {
                return .none
            }
            
            let hash = abs(message.text.hashValue)
            let questionIndex = hash % questions.count
            let question = questions[questionIndex].0
            let answer = questions[questionIndex].1
            
            return .init(
                state: .ok,
                output: .textMessage("Will do!"),
                effect: .startConversation(ChanneledBehaviorOutput(
                    output: .textMessage("Answer this question and win a prize: *\(question) = X. What's the value of X*"),
                    channel: userId,
                    transform: .messageTransform(
                        expected: answer,
                        transformed: "answer math question \(question) with \(answer)",
                        channel: userId,
                        sender: message.senderId
                    )
                ))
            )
        } else if let result = message.text.firstMatch(regex: RandomMathQuestionBehavior.answerRegex) {
            guard   let question = result.substring(from: message.text, at: 1),
                    let answer = result.substring(from: message.text, at: 2) else {
                return .none
            }
            guard let validQuestion = questions.first(where: { $0.0 == question }) else {
                return .init(
                    state: .ok,
                    output: .textMessage("You are giving me an answer to a question I didn't ask")
                )
            }
            if validQuestion.1 == answer {
                return .init(
                    state: .ok,
                    output: .textMessage("That's correct!")
                )
            } else {
                return .init(
                    state: .ok,
                    output: .textMessage("INCORRECT!!!!. Maybe next time looser!")
                )
            }
        } else {
            return .none
        }
    }

    public func update(state: State, input: Input) -> TransitionOutput {
        return .init(state: state)
    }

}

extension RandomMathQuestionBehavior {

    public struct State: BehaviorState {
        
        static let ok = State()
        
        public var isFinalState: Bool {
            return true
        }
        
    }

}

 extension RandomMathQuestionBehavior {
    
    static let askRegex = try! NSRegularExpression(
        pattern: "^ask random math question to <@.*>$",
        options: .caseInsensitive
    )
    
    static let answerRegex = try! NSRegularExpression(
        pattern: "^answer math question (\\d+\\s+[+-x/]\\s+\\d+) with (\\d+)$",
        options: .caseInsensitive
    )
    
}
