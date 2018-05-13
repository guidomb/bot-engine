//
//  BotEngine.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation
import Result
import ReactiveSwift

final class BotEngine {
    
    typealias MessageWithContext = (message: BehaviorMessage, context: BehaviorMessage.Context)
    typealias MessageProducer = SignalProducer<MessageWithContext, NoError>
    typealias BehaviorFactory = (MessageWithContext) -> ActiveBehavior?
    
    private let inputProducer: MessageProducer
    private let outputRenderer: BehaviorOutputRenderer
    private var activeBehaviors: [ChannelId : ActiveBehavior] = [:]
    private var behaviorFactories: [BehaviorFactory] = []
    private var disposable: Disposable?
    private let output: Signal<ChanneledBehaviorOutput, NoError>
    private let outputObserver: Signal<ChanneledBehaviorOutput, NoError>.Observer
    
    init(inputProducer: SignalProducer<MessageWithContext, NoError>, outputRenderer: BehaviorOutputRenderer) {
        self.inputProducer = inputProducer
        self.outputRenderer = outputRenderer
        (output, outputObserver) =  Signal<ChanneledBehaviorOutput, NoError>.pipe()
    }
    
    func start() {
        disposable?.dispose()
        disposable = inputProducer.startWithValues(handle(input:))
        output.observeValues(outputRenderer.render)
    }
    
    func registerBehaviorFactory(_ behaviorFactory: @escaping BehaviorFactory) {
        behaviorFactories.append(behaviorFactory)
    }
    
    func registerBehavior<BehaviorType: BehaviorProtocol>(_ behavior: BehaviorType) {
        registerBehaviorFactory(behavior.parse)
    }
    
    private func handle(input: MessageWithContext) {
        let channel = input.message.channel
        guard !input.message.isCancelMessage else {
            if let activeBehavior = activeBehaviors[channel] {
                activeBehaviors.removeValue(forKey: channel)
                send(reply: .cancelConfirmation(description: activeBehavior.descriptionForCancellation), for: channel)
            } else {
                send(reply: .nothingToCancel, for: channel)
            }
            return
        }
        
        if let activeBehavior = activeBehaviors[channel] {
            activeBehavior.handle(message: input.message, with: input.context)
            if activeBehavior.isInFinalState {
                activeBehaviors.removeValue(forKey: channel)
            }
        } else if let activeBehavior = findBehavior(for: input) {
            activeBehavior.mount(with: outputObserver, for: channel)
            if !activeBehavior.isInFinalState {
                activeBehaviors[channel] = activeBehavior
            }
        } else {
            send(reply: .dontUnderstandMessage, for: channel)
        }
    }
    
    private func findBehavior(for message: MessageWithContext) -> ActiveBehavior? {
        for behaviorFactory in behaviorFactories {
            if let activeBehavior = behaviorFactory(message) {
                return activeBehavior
            }
        }
        return .none
    }
    
}

fileprivate extension BotEngine {
    
    enum DefaultReply {
        
        case dontUnderstandMessage
        case nothingToCancel
        case cancelConfirmation(description: String)
        
        var message: String {
            switch self {
            case .dontUnderstandMessage:
                return "Sorry, I don't understand that."
            case .nothingToCancel:
                return "There is nothing for me to cancel."
            case .cancelConfirmation(let description):
                return "OK. I cancelled \(description)."
            }
        }
    }
    
    func send(reply: DefaultReply, for channel: ChannelId) {
        send(message: reply.message, for: channel)
    }
    
    func send(message: String, for channel: ChannelId) {
        outputObserver.send(value: (.textMessage(message), channel))
    }
    
    private func send(output: BehaviorOutput, for channel: ChannelId) {
        outputObserver.send(value: (output, channel))
    }
    
}

fileprivate extension BehaviorProtocol {
    
    func parse(message: BehaviorMessage, with context: BehaviorMessage.Context) -> ActiveBehavior? {
        return create(message: message, context: context).map { transition in
            Behavior.Runner(initialTransition: transition, behavior: AnyBehavior(self))
        }
    }
    
}
