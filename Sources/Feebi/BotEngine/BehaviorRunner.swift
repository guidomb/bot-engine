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
        
        var isInFinalState: Bool {
            return state.value?.isFinalState ?? false
        }
        
        var descriptionForCancellation: String {
            return behavior.descriptionForCancellation
        }
        
        private let behavior: BehaviorType
        private let mutableState: MutableProperty<StateType?>
        
        private var disposable = CompositeDisposable()
        private var runningState: RunningState
        
        var dependencies: BehaviorDependencies? {
            if case .mounted(let mount) = runningState {
                return mount.dependencies
            } else {
                return .none
            }
        }
        
        var effectPerformer: EffectPerformer? {
            if case .mounted(let mount) = runningState {
                return mount.effectPerformer
            } else {
                return .none
            }
        }
        
        init(initialTransition: TransitionOutput, behavior: BehaviorType) {
            self.mutableState = MutableProperty(.none)
            self.state = Property(mutableState)
            self.runningState = .waitingToBeMounted(initialTransition: initialTransition)
            self.behavior = behavior
        }
        
        func handle(input: BotEngine.Input) {
            handle(input: asBehaviorInput(input), for: input.channel)
        }
        
        func mount(using dependencies: BehaviorDependencies,
                   with observer: BotEngine.OutputSignal.Observer,
                   for channel: ChannelId) {
            guard case .waitingToBeMounted(let initialTransition) = runningState else {
                fatalError("ERROR - Behavior has already been mounted.")
            }
            
            self.runningState = .mounted(Mounted(
                dependencies: dependencies,
                outputObserver: observer,
                effectPerformer: behavior.createEffectPerformer(services: dependencies.services)
            ))
            handle(transition: initialTransition, for: channel)
        }
        
    }
    
}

fileprivate extension Behavior.Runner {
    
    enum RunningState {
        
        case waitingToBeMounted(initialTransition: Behavior.TransitionOutput)
        case mounted(Mounted)
        
    }
    
    struct Mounted {
        
        let dependencies: BehaviorDependencies
        let outputObserver: BotEngine.OutputSignal.Observer
        let effectPerformer: AnyBehaviorEffectPerformer<EffectType>
        
    }
    
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
            send(output: .init(output: output, channel: channel))
        }
        if let effect = transition.effect {
            performEffect(effect, for: channel)
        }
    }
    
    func performEffect(_ effect: Behavior.Effect, for channel: ChannelId) {
        switch effect {
            
        case .effect(let effect):
            guard let effectPerformer = self.effectPerformer else {
                fatalError("ERROR - Cannot perform effect if effect performer is not available. Maybe you forgot to mount the runner")
            }
            
            disposable += effectPerformer.perform(effect: effect, for: channel).startWithValues { (result, job) in
                self.handle(effectResult: result, for: channel)
                self.scheduleJob(job)
            }
            
        case .startConversation(let channeledOutput):
            send(output: channeledOutput)
            
        case .cancelAllRunningEffects:
            cancellAllRunningEffects()
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
        guard let scheduler = dependencies?.scheduler else {
            fatalError("ERROR - Cannot schedule job. There is no scheduler. Behavior was not properly mounted.")
        }
        scheduler.schedule(job: job, for: behavior)
    }
    
    func asBehaviorInput(_ input: BotEngine.Input) -> Behavior.Input {
        switch input {
        case .message(let message, let context):
            return .message(message, context)
        case .interactiveMessageAnswer(let answer, _, let senderId):
            return .interactiveMessageAnswer(answer, senderId)
        }
    }
    
    func send(output: ChanneledBehaviorOutput) {
        guard case .mounted(let mount) = runningState else {
            print("WARN - Trying to send output when behavior is not mounted. Ignoring output.")
            return
        }
        mount.outputObserver.send(value: output)
    }
    
}
