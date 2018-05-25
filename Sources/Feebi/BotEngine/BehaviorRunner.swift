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
    
    final class Runner<BehaviorJobExecutorType: BehaviorJobExecutor>: ActiveBehavior
        where BehaviorJobExecutorType.JobMessageType == EffectType.JobMessageType {
        
        typealias BehaviorType = AnyBehavior<StateType, EffectType, BehaviorJobExecutorType>
        typealias SchedulableJobType = SchedulableJob<BehaviorJobExecutorType.JobMessageType>
        
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
        private var services: BotEngine.Services?
        private var effectPerformer: AnyBehaviorEffectPerformer<EffectType>?
        
        init(initialTransition: TransitionOutput, behavior: BehaviorType) {
            (self.output, self.outputObserver) = Signal<ChanneledBehaviorOutput, NoError>.pipe()
            self.mutableState = MutableProperty(.none)
            self.state = Property(mutableState)
            self.initialTransition = initialTransition
            self.behavior = behavior
        }
        
        func handle(input: BotEngine.Input) {
            handle(input: asBehaviorInput(input), for: input.channel)
        }
        
        func mount(using services: BotEngine.Services,
                   with observer: Signal<ChanneledBehaviorOutput, NoError>.Observer,
                   for channel: ChannelId) {
            guard let initialTransition = self.initialTransition else {
                fatalError("Behavior has already been mounted")
            }
            
            self.initialTransition = .none
            self.services = services
            self.effectPerformer = behavior.createEffectPerformer(repository: services.repository)
            output.observe(observer)
            handle(transition: initialTransition, for: channel)
        }
        
    }
    
}

fileprivate extension Behavior.Runner {
    
    func handle(effectResult: EffectType.EffectResult, for channel: ChannelId) {
        handle(input: .effectResult(effectResult), for: channel)
    }
    
    func handle(input: Behavior.Input, for channel: ChannelId) {
        guard let currentState = state.value else {
            fatalError("Cannot handle input if behavior is not mounted")
        }
        
        let transition = behavior.update(state: currentState, input: input)
        handle(transition: transition, for: channel)
    }
    
    func handle(transition: Behavior.TransitionOutput, for channel: ChannelId) {
        mutableState.value = transition.state
        if let output = transition.output {
            outputObserver.send(value: (output, channel))
        }
        if let effect = transition.effect {
            performEffect(effect, for: channel)
        }
    }
    
    func performEffect(_ effect: EffectType, for channel: ChannelId) {
        guard let effectPerformer = self.effectPerformer else {
            fatalError("ERROR - Cannot perform effect if effect performer is not available. Maybe you forgot to mount the runner")
        }
        
        switch effectPerformer.perform(effect: effect) {
        case .cancellAllRunningEffects:
            cancellAllRunningEffects()
            
        case .effectResultProducer(let producer):
            disposable += producer.startWithValues { (result, job) in
                self.handle(effectResult: result, for: channel)
                self.scheduleJob(job)
            }
        }
        
    }
    
    func cancellAllRunningEffects() {
        disposable.dispose()
        disposable = CompositeDisposable()
    }
    
    func scheduleJob(_ maybeJob: SchedulableJobType?) {
        guard let job = maybeJob else {
            return
        }
        guard let scheduler = services?.jobScheduler else {
            fatalError("ERROR - Cannot schedule job. There is no scheduler. Behavior was not properly mounted.")
        }
        scheduler.schedule(job: job, for: behavior)
    }
    
    func asBehaviorInput(_ input: BotEngine.Input) -> Behavior.Input {
        switch input {
        case .message(let message, let context):
            return .message(message, context)
        case .interactiveMessageAnswer(let answer, _):
            return .interactiveMessageAnswer(answer)
        }
    }
    
}
