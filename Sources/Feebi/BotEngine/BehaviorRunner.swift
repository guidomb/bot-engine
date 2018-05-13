//
//  BehaviorRunner.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation
import ReactiveSwift
import Result

extension Behavior {
    
    final class Runner: ActiveBehavior {
        
        typealias BehaviorType = AnyBehavior<StateType, EffectType, EffectResponseType, EffectErrorType>
        
        let state: Property<StateType?>
        let output: Signal<ChanneledBehaviorOutput, NoError>
        
        var isInFinalState: Bool {
            return state.value?.isFinalState ?? false
        }
        
        var descriptionForCancellation: String {
            return behavior.descriptionForCancellation
        }
        
        private let behavior: BehaviorType
        private let mutableState: MutableProperty<StateType?>
        private let outputObserver: Signal<ChanneledBehaviorOutput, NoError>.Observer
        private var initialTransition: TransitionOutput?
        private var disposable = CompositeDisposable()
        
        init(initialTransition: TransitionOutput, behavior: BehaviorType) {
            (self.output, self.outputObserver) = Signal<ChanneledBehaviorOutput, NoError>.pipe()
            self.mutableState = MutableProperty(.none)
            self.state = Property(mutableState)
            self.initialTransition = initialTransition
            self.behavior = behavior
        }
        
        func handle(message: BehaviorMessage, with context: BehaviorMessage.Context) {
            handle(input: .message(message, context), for: message.channel)
        }
        
        func handle(effectResult: EffectPerformer.EffectResult, for channel: ChannelId) {
            handle(input: .effectResult(effectResult), for: channel)
        }
        
        func handle(input: Input, for channel: ChannelId) {
            guard let currentState = state.value else {
                fatalError("Cannot handle input if behavior is not mounted")
            }
            
            let transition = behavior.update(state: currentState, input: input)
            handle(transition: transition, for: channel)
        }
        
        func handle(transition: TransitionOutput, for channel: ChannelId) {
            mutableState.value = transition.state
            if let output = transition.output {
                outputObserver.send(value: (output, channel))
            }
            if let effect = transition.effect {
                performEffect(effect, for: channel)
            }
        }
        
        func mount(with observer: Signal<ChanneledBehaviorOutput, NoError>.Observer, for channel: ChannelId) {
            guard let initialTransition = self.initialTransition else {
                fatalError("Behavior has already been mounted")
            }
            
            self.initialTransition = .none
            output.observe(observer)
            handle(transition: initialTransition, for: channel)
        }
        
        func performEffect(_ effect: EffectType, for channel: ChannelId) {
            switch behavior.effectPerformer.perform(effect: effect) {
            case .cancellAllRunningEffects:
                cancellAllRunningEffects()
                
            case .effectResultProducer(let producer):
                disposable += producer.startWithValues { self.handle(effectResult: $0, for: channel) }
            }
            
        }
        
        func cancellAllRunningEffects() {
            disposable.dispose()
            disposable = CompositeDisposable()
        }
        
    }
    
}
