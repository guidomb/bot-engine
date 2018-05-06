//
//  BotBehaviorRunner.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/5/18.
//

import Foundation
import ReactiveSwift
import Result

protocol BehaviorProtocol {
    
    typealias Instance = (BehaviorProtocol, Behavior.StateTransition)
    
    static func parse(input: Behavior.Message) -> Instance?
    
    mutating func update(input: Behavior.Message) -> Behavior.StateTransition
    
    mutating func update(input: Behavior.TaggedResult) -> Behavior.StateTransition
    
}

struct Behavior {

    typealias EffectResult = Result<Effect.Response, Effect.Error>
    typealias EffectSignal = Signal<TaggedResult, NoError>
    typealias EffectObserver = EffectSignal.Observer
    typealias InputProducer = SignalProducer<Input, NoError>
    typealias MessageProducer = SignalProducer<Message, NoError>
    typealias StateTransition = (isFinalState: Bool, transition: Behavior.Transition)
    
    static let behaviors: [BehaviorProtocol.Type] = [
        CreateSurveyBehavior.self
    ]
    
    enum Input {
        
        case message(Message)
        case effectResult(TaggedResult)
        
    }
    
    enum Output {
        
        case textMessage(String)
        
    }


    enum Effect {
     
        enum Error: Swift.Error {
            
        }
        
        enum Response {
            
        }
        
        case validateFormAccess(formId: String)
        
    }
    
    struct Message {
        
        let channel: ChannelId
        let text: String
        
    }
    
    struct TaggedResult {
        
        let channel: ChannelId
        let result: EffectResult
        
    }
    
    struct Transition {
        
        static func unsupportedMessage(_ message: Message) -> Transition {
            return Transition(
                input: .message(message),
                output: .textMessage("Sorry, I don't undestand that."),
                effect: .none
            )
        }
        
        static func ignoreInput(_ input: Input) -> Transition {
            return Transition(input: input, output: .none, effect: .none)
        }
        
        let input: Input
        let output: Output?
        let effect: Effect?
        
        var channel: ChannelId {
            switch input {
            case .message(let message):
                return message.channel
            case .effectResult(let taggedResult):
                return taggedResult.channel
            }
        }
        
    }
    
}

protocol EffectorProtocol {
    
    init(observer: Behavior.EffectObserver)
    
    func perform(effect: Behavior.Effect, forChannel channel: ChannelId)
    
}

protocol OutputRendererProtocol {
    
    func render(output: Behavior.Output, forChannel channel: ChannelId)
    
}

struct Effector: EffectorProtocol {
    
    let observer: Behavior.EffectObserver
    
    func perform(effect: Behavior.Effect, forChannel channel: ChannelId) {
        
    }
    
}

struct SlackOutputRenderer: OutputRendererProtocol {
    
    let slackService: SlackServiceProtocol
    
    func render(output: Behavior.Output, forChannel channel: ChannelId) {
        switch output {
        case .textMessage(let message):
            slackService.sendMessage(channel: channel, text: message).startWithFailed { error in
                print("Error sending message:")
                print("\tChannel: \(channel)")
                print("\tMessage: \(message)")
                print("\tError: \(error)")
                print("")
            }
        }
    }

}

struct ConsoleOutputRenderer: OutputRendererProtocol {
    
    func render(output: Behavior.Output, forChannel channel: ChannelId) {
        switch output {
        case .textMessage(let message):
            print("Output: \(message)")
        }
    }
    
}

typealias ChannelId = String

final class BotBehaviorRunner {
    
    static func slackRunner(token: String) -> BotBehaviorRunner {
        let slackService = SlackService(token: token)
        let outputRenderer = SlackOutputRenderer(slackService: slackService)
        let messageProducer: Behavior.MessageProducer = slackService.start()
            .flatMapError { _ in .empty }
            .filterMap { event in
                guard let channel = event.message?.channel, let messageText = event.message?.text else {
                    return nil
                }
                return Behavior.Message(channel: channel, text: messageText)
            }
        return BotBehaviorRunner(messageProducer: messageProducer, outputRenderer: outputRenderer)
    }
    
    static func consoleRunner() -> BotBehaviorRunner {
        let outputRenderer = ConsoleOutputRenderer()
        let messageProducer = Behavior.MessageProducer { observer, _ in
            while (true) {
                print("Enter input:")
                guard let line = readLine() else {
                    break
                }
                guard line != "exit" else {
                    print("bye!")
                    observer.sendInterrupted()
                    exit(0)
                }
                
                observer.send(value: Behavior.Message(channel: "console", text: line))
            }
        }
        return BotBehaviorRunner(messageProducer: messageProducer, outputRenderer: outputRenderer)
    }
    
    private let messageProducer: Behavior.MessageProducer
    private let effectorType: EffectorProtocol.Type
    private let outputRenderer: OutputRendererProtocol
    private var effectResultObserver: Behavior.EffectObserver?
    private var disposable: Disposable?
    private var activeBehaviors: [ChannelId : BehaviorProtocol] = [:]
    
    init(messageProducer: Behavior.MessageProducer,
         outputRenderer: OutputRendererProtocol,
         effectorType: EffectorProtocol.Type = Effector.self) {
        self.messageProducer = messageProducer
        self.outputRenderer = outputRenderer
        self.effectorType = effectorType
    }
    
    func run() {
        disposable = Behavior.InputProducer.merge(
            messageProducer.map(Behavior.Input.message),
            createEffectsResultPipe()
        )
        .map(handleInput)
        .startWithValues { [unowned self] transition in
            if let output = transition.output {
                self.outputRenderer.render(output: output, forChannel: transition.channel)
            }
            if let effect = transition.effect, let observer = self.effectResultObserver {
                let effector = self.effectorType.init(observer: observer)
                effector.perform(effect: effect, forChannel: transition.channel)
            }
        }
    }
    
    func stop() {
        disposable?.dispose()
        effectResultObserver?.sendInterrupted()
        effectResultObserver = .none
        disposable = .none
    }
    
}

fileprivate extension BotBehaviorRunner {
    
    func createEffectsResultPipe() -> Behavior.InputProducer {
        let pipe = Behavior.EffectSignal.pipe()
        effectResultObserver?.sendInterrupted()
        effectResultObserver = pipe.input
        return SignalProducer(pipe.output).map(Behavior.Input.effectResult)
    }
    
    func handleInput(_ input: Behavior.Input) -> Behavior.Transition {
        switch input {
            
        case .message(let message):
            if var behavior = activeBehaviors[message.channel] {
                let (isFinalState, transition) = behavior.update(input: message)
                if isFinalState {
                    activeBehaviors.removeValue(forKey: message.channel)
                }
                return transition
            } else if let (behavior, stateTransition) = matchBehavior(for: message) {
                if !stateTransition.isFinalState {
                    activeBehaviors[message.channel] = behavior
                }
                return stateTransition.transition
            } else {
                return .unsupportedMessage(message)
            }
            
        case .effectResult(let taggedResult):
            guard var behavior = activeBehaviors[taggedResult.channel] else {
                print("WARN: There is no active behavior to handle effect result for channel '\(taggedResult.channel)'")
                return .ignoreInput(input)
            }
            let (isFinalState, transition) = behavior.update(input: taggedResult)
            if isFinalState {
                activeBehaviors.removeValue(forKey: taggedResult.channel)
            }
            return transition
        }
    }
    
    func matchBehavior(for message: Behavior.Message) -> BehaviorProtocol.Instance? {
        for behaviorType in Behavior.behaviors {
            if let instance = behaviorType.parse(input: message) {
                return instance
            }
        }
        return .none
    }
    
}
