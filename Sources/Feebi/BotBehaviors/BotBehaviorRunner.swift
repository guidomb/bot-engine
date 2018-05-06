//
//  BotBehaviorRunner.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/5/18.
//

import Foundation
import ReactiveSwift
import Result

typealias ChannelId = String

struct UserEntityInfo {
    
    let id: String
    let name: String?
    let email: String?
    let firstName: String?
    let lastName: String?
    
}

final class BotBehaviorRunner {
    
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
        .startWithValues { [unowned self] (channel, transition) in
            if let output = transition.output {
                self.outputRenderer.render(output: output, forChannel: channel)
            }
            if let effect = transition.effect, let observer = self.effectResultObserver {
                let effector = self.effectorType.init(observer: observer)
                effector.perform(effect: effect, forChannel: channel)
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

extension BotBehaviorRunner {
    
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
                
                let message = Behavior.Message(source: .console, channel: "console", text: line)
                observer.send(value: (message, Behavior.Context()))
            }
        }
        return BotBehaviorRunner(messageProducer: messageProducer, outputRenderer: outputRenderer)
    }
    
}

fileprivate extension BotBehaviorRunner {
    
    func createEffectsResultPipe() -> Behavior.InputProducer {
        let pipe = Behavior.EffectSignal.pipe()
        effectResultObserver?.sendInterrupted()
        effectResultObserver = pipe.input
        return SignalProducer(pipe.output).map(Behavior.Input.effectResult)
    }
    
    func handleInput(_ input: Behavior.Input) -> (ChannelId, Behavior.StateTransitionOutput) {
        switch input {
        case .message(let message, let context):
            return handleInput(message, with: context)
        case .effectResult(let taggedResult):
            return handleInput(taggedResult)
        }
    }
    
    func handleInput(_ input: Behavior.Message, with context: Behavior.Context) -> (ChannelId, Behavior.StateTransitionOutput) {
        if var behavior = activeBehaviors[input.channel] {
            guard !input.isCancelMessage else {
                activeBehaviors.removeValue(forKey: input.channel)
                return (input.channel, .activeBehaviorCancelled(behaviorName: behavior.descriptionForCancellation))
            }
            
            let transition = behavior.update(input: input, context: context)
            if behavior.isInFinalState {
                activeBehaviors.removeValue(forKey: input.channel)
            } else {
                activeBehaviors[input.channel] = behavior
            }
            return (input.channel, transition)
        } else if let initialState = matchBehavior(for: input, context: context) {
            if !initialState.isFinalState {
                activeBehaviors[input.channel] = initialState.behavior
            }
            return (input.channel, initialState.transition)
        } else {
            return (input.channel, .unsupportedMessage)
        }
    }
    
    func handleInput(_ input: Behavior.TaggedResult) -> (ChannelId, Behavior.StateTransitionOutput) {
        guard var behavior = activeBehaviors[input.channel] else {
            print("WARN: There is no active behavior to handle effect result for channel '\(input.channel)'")
            return (input.channel, .void)
        }
        
        let transition = behavior.update(input: input)
        if behavior.isInFinalState {
            activeBehaviors.removeValue(forKey: input.channel)
        } else {
            activeBehaviors[input.channel] = behavior
        }
        return (input.channel, transition)
    }
    
    func matchBehavior(for message: Behavior.Message, context: Behavior.Context) -> Behavior.InitialState? {
        for behaviorType in Behavior.behaviors {
            if let instance = behaviorType.parse(input: message, context: context) {
                return instance
            }
        }
        return .none
    }
    
}

