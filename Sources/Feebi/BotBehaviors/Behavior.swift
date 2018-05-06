//
//  Behavior.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/6/18.
//

import Foundation
import ReactiveSwift
import Result

protocol BehaviorProtocol {
    
    
    static func parse(input: Behavior.Message, context: Behavior.Context) -> Behavior.InitialState?
    
    var isInFinalState: Bool { get }
    
    var isInErrorState: Bool { get }
    
    var descriptionForCancellation: String { get }
    
    mutating func update(input: Behavior.Message, context: Behavior.Context) -> Behavior.StateTransitionOutput
    
    mutating func update(input: Behavior.TaggedResult) -> Behavior.StateTransitionOutput
    
}

struct Behavior {
    
    typealias EffectResult = Result<Effect.Response, Effect.Error>
    typealias EffectSignal = Signal<TaggedResult, NoError>
    typealias EffectObserver = EffectSignal.Observer
    typealias InputProducer = SignalProducer<Input, NoError>
    typealias MessageProducer = SignalProducer<(Message, Context), NoError>
    
    static let behaviors: [BehaviorProtocol.Type] = [
        CreateSurveyBehavior.self
    ]
    
    struct Context {
        
        var userEntitiesInfo: [String : UserEntityInfo]
        
        init(userEntitiesInfo: [UserEntityInfo] = []) {
            self.userEntitiesInfo = Dictionary(userEntitiesInfo.map { ($0.id, $0) }) { a, _  in a }
        }
        
    }
    
    enum Input {
        
        case message(Message, Context)
        case effectResult(TaggedResult)
        
    }
    
    enum Output {
        
        case textMessage(String)
        case confirmationQuestion(yesMessage: String, noMessage: String)
        
    }
    
    
    enum Effect {
        
        enum Error: Swift.Error {
            
        }
        
        enum Response {
            
            case formAccessValidated(formId: String)
            case formAccessDenied(formId: String)
            
        }
        
        case cancelRunningEffects
        case validateFormAccess(formId: String)
        
    }
    
    struct Message {
        
        enum Source {
            
            case slack
            case console
            
        }
        
        let source: Source
        let channel: ChannelId
        let text: String
        let entities: [Entity]
        
        var isCancelMessage: Bool {
            return text == "cancel"
        }
        
        init(source: Source, channel: ChannelId, text: String) {
            self.source = source
            self.channel = channel
            self.text = text
            self.entities = source == .slack ? Message.parseSlackEntities(from: text) : []
        }
        
    }
    
    struct TaggedResult {
        
        let channel: ChannelId
        let result: EffectResult
        
    }
    
    struct InitialState {
        
        let behavior: BehaviorProtocol
        let transition: StateTransitionOutput
        
        var isFinalState: Bool {
            return behavior.isInFinalState
        }
        
    }
    
    struct StateTransitionOutput {
        
        static let unsupportedMessage = StateTransitionOutput(
            output: .textMessage("Sorry, I don't undestand that."),
            effect: .none
        )
        
        static func activeBehaviorCancelled(behaviorName: String) -> StateTransitionOutput {
            return StateTransitionOutput(
                output: .textMessage("OK. I cancelled \(behaviorName)."),
                effect: .cancelRunningEffects
            )
        }
        
        static let void = StateTransitionOutput(output: .none, effect: .none)
        
        let output: Output?
        let effect: Effect?
        
        init(output: Output? = .none, effect: Effect? = .none) {
            self.output = output
            self.effect = effect
        }
        
    }
    
}

extension Behavior.InitialState {
    
    init(behavior: BehaviorProtocol, output: Behavior.Output? = .none, effect: Behavior.Effect? = .none) {
        self.behavior = behavior
        self.transition = Behavior.StateTransitionOutput(output: output, effect: effect)
    }
    
}

extension Behavior.Message {
    
    enum Entity {
        
        case slackChannel(id: String, name: String)
        case slackUserId(String)
        
    }
    
    var slackUserIdEntities: [String] {
        return entities.map { entity in
            if case .slackUserId(let userId) = entity {
                return userId
            } else {
                return ""
            }
        }
        .filter { !$0.isEmpty }
    }
    
}

fileprivate extension Behavior.Message {

    static func parseSlackEntities(from text: String) -> [Entity] {
        return text.split(" ")
            .filter {
                // <#U234AFG|channelName> or <@U2345AD>
                $0.last == ">" && ($0.starts(with: "<@") || ($0.starts(with: "<#") && $0.contains("|")))
            }
            .map { word in
                let reference = word.dropLast().dropFirst() // removes '<' '>'
                if reference.starts(with: "@") {
                    return .slackUserId(String(reference.dropFirst()))
                } else {
                    let result = reference.dropFirst().split(separator: "|").map(String.init)
                    return .slackChannel(id: result[0], name: result[1])
                }
        }
    }
    
}
