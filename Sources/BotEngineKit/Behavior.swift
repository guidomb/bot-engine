import Foundation
import ReactiveSwift
import Result

public typealias ChannelId = String

public protocol BehaviorState {
    
    var isFinalState: Bool { get }
    
}

public protocol BehaviorProtocol {
    
    associatedtype StateType: BehaviorState
    associatedtype EffectType
    associatedtype EffectPerformerType: BehaviorEffectPerformer
        where EffectPerformerType.EffectType == EffectType
    associatedtype BehaviorJobExecutorType: BehaviorJobExecutor
        where EffectType.JobMessageType == BehaviorJobExecutorType.JobMessageType
    
    typealias ConcreteBehavior = Behavior<StateType, EffectType>
    typealias BehaviorTransitionOutput = ConcreteBehavior.TransitionOutput
    typealias BehaviorInput = ConcreteBehavior.Input
    typealias JobMessageType = BehaviorJobExecutorType.JobMessageType
    typealias ScheduledJobType = ScheduledJob<JobMessageType>
    
    var descriptionForCancellation: String { get }
    
    func createSchedulable(services: BotEngine.Services) -> BehaviorSchedulableJobs<BehaviorJobExecutorType>?
    
    func createEffectPerformer(services: BotEngine.Services) -> EffectPerformerType
    
    func create(message: BehaviorMessage, context: BehaviorMessage.Context) -> BehaviorTransitionOutput?
    
    func update(state: StateType, input: BehaviorInput) -> BehaviorTransitionOutput
    
}

extension BehaviorProtocol {
    
    public var descriptionForCancellation: String {
        return "the current task"
    }
    
}

public protocol ActiveBehavior {
    
    var isInFinalState: Bool { get }
    
    var descriptionForCancellation: String { get }
    
    func mount(using dependencies: BehaviorDependencies,
               with observer: BotEngine.OutputSignal.Observer,
               for channel: ChannelId)
    
    func handle(input: BotEngine.Input)
        
}

public struct BehaviorDependencies {
    
    public let scheduler: BehaviorJobScheduler
    public let services: BotEngine.Services
    
}

public struct AnyBehavior<
    StateType: BehaviorState,
    EffectType: BehaviorEffect,
    BehaviorJobExecutorType: BehaviorJobExecutor>: BehaviorProtocol
    where BehaviorJobExecutorType.JobMessageType == EffectType.JobMessageType {
    
    public typealias ConcreteBehavior = Behavior<StateType, EffectType>
    public typealias BehaviorInput = ConcreteBehavior.Input
    public typealias BehaviorTransitionOutput = ConcreteBehavior.TransitionOutput
    
    typealias JobMessageType = BehaviorJobExecutorType.JobMessageType
    
    public let descriptionForCancellation: String
    
    private let _create: (BehaviorMessage, BehaviorMessage.Context) -> BehaviorTransitionOutput?
    private let _update: (StateType, BehaviorInput) -> BehaviorTransitionOutput
    private let _createEffectPerformer: (BotEngine.Services) -> AnyBehaviorEffectPerformer<EffectType>
    private let _createSchedulable: (BotEngine.Services) -> BehaviorSchedulableJobs<BehaviorJobExecutorType>?
    
    init<BehaviorType: BehaviorProtocol>(_ behavior: BehaviorType) where
        BehaviorType.StateType == StateType,
        BehaviorType.EffectType == EffectType,
        BehaviorType.BehaviorJobExecutorType == BehaviorJobExecutorType {
        self.descriptionForCancellation = behavior.descriptionForCancellation
        self._create = behavior.create
        self._update = behavior.update
        self._createEffectPerformer = { AnyBehaviorEffectPerformer(behavior.createEffectPerformer(services: $0)) }
        self._createSchedulable = behavior.createSchedulable
    }

    public func createSchedulable(services: BotEngine.Services) -> BehaviorSchedulableJobs<BehaviorJobExecutorType>? {
        return _createSchedulable(services)
    }
    
    public func createEffectPerformer(services: BotEngine.Services) -> AnyBehaviorEffectPerformer<EffectType> {
        return _createEffectPerformer(services)
    }
    
    public func create(message: BehaviorMessage, context: BehaviorMessage.Context) -> BehaviorTransitionOutput? {
        return _create(message, context)
    }
    
    public func update(state: StateType, input: BehaviorInput) -> BehaviorTransitionOutput {
        return _update(state, input)
    }
    
}

public struct Behavior<StateType: BehaviorState, EffectType: BehaviorEffect> {

    typealias EffectPerformer = AnyBehaviorEffectPerformer<EffectType>
    typealias Create = (BehaviorMessage, BehaviorMessage.Context) -> TransitionOutput?
    typealias Update = (StateType, Input) -> TransitionOutput
    
    public enum Input {
        
        case message(BehaviorMessage, BehaviorMessage.Context)
        case effectResult(EffectType.EffectResult)
        case interactiveMessageAnswer(String, String)
    
    }
    
    public enum Effect {
        
        case effect(EffectType)
        case cancelAllRunningEffects
        case startConversation(ChanneledBehaviorOutput)
        // TODO case scheduleJob(SchedulableJob<JobMessageType>)
    }
    
    public struct TransitionOutput {
        
        public let state: StateType
        public let output: BehaviorOutput?
        public let effect: Effect?
        
        public init(state: StateType, output: BehaviorOutput? = .none, effect: Effect? = .none) {
            self.state = state
            self.output = output
            self.effect = effect
        }
                
    }
    
}
