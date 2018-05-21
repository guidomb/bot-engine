import Foundation
import ReactiveSwift
import Result

typealias ChannelId = String
typealias ChanneledBehaviorOutput = (output: BehaviorOutput, channel: ChannelId)

protocol BehaviorState {
    
    var isFinalState: Bool { get }
    
}

protocol BehaviorProtocol {
    
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
    
    // TODO effectPerfomer should be a factory method
    // that receives an ObjectRepository as input parameter.
    // It should probably also receive process env variables
    // and user info dictionary with objects that can interpreted
    // by each behavior. For example GoogleAPI.Token object.
    var effectPerformer: EffectPerformerType { get }
    var descriptionForCancellation: String { get }
    var schedulable: BehaviorSchedulableJobs<BehaviorJobExecutorType>? { get }
    
    func create(message: BehaviorMessage, context: BehaviorMessage.Context) -> BehaviorTransitionOutput?
    
    func update(state: StateType, input: BehaviorInput) -> BehaviorTransitionOutput
    
}

extension BehaviorProtocol {
    
    var descriptionForCancellation: String {
        return "the current task"
    }
    
}

protocol ActiveBehavior {
    
    var isInFinalState: Bool { get }
    
    var descriptionForCancellation: String { get }
    
    func mount(with observer: Signal<ChanneledBehaviorOutput, NoError>.Observer, scheduler: BehaviorJobScheduler, for channel: ChannelId)
    
    func handle(message: BehaviorMessage, with context: BehaviorMessage.Context)
        
}

struct AnyBehavior<
    StateType: BehaviorState,
    EffectType: BehaviorEffect,
    BehaviorJobExecutorType: BehaviorJobExecutor>: BehaviorProtocol
    where BehaviorJobExecutorType.JobMessageType == EffectType.JobMessageType {
    
    typealias ConcreteBehavior = Behavior<StateType, EffectType>
    typealias BehaviorTransitionOutput = ConcreteBehavior.TransitionOutput
    typealias BehaviorInput = ConcreteBehavior.Input
    typealias JobMessageType = BehaviorJobExecutorType.JobMessageType
    
    let effectPerformer: AnyBehaviorEffectPerformer<EffectType>
    let descriptionForCancellation: String
    let schedulable: BehaviorSchedulableJobs<BehaviorJobExecutorType>?
    
    private let _create: (BehaviorMessage, BehaviorMessage.Context) -> BehaviorTransitionOutput?
    private let _update: (StateType, BehaviorInput) -> BehaviorTransitionOutput
    
    init<BehaviorType: BehaviorProtocol>(_ behavior: BehaviorType) where
        BehaviorType.StateType == StateType,
        BehaviorType.EffectType == EffectType,
        BehaviorType.BehaviorJobExecutorType == BehaviorJobExecutorType {
        self.effectPerformer = AnyBehaviorEffectPerformer(behavior.effectPerformer)
        self.descriptionForCancellation = behavior.descriptionForCancellation
        self.schedulable = behavior.schedulable
        self._create = behavior.create
        self._update = behavior.update
    }
    
    func create(message: BehaviorMessage, context: BehaviorMessage.Context) -> BehaviorTransitionOutput? {
        return _create(message, context)
    }
    
    func update(state: StateType, input: BehaviorInput) -> BehaviorTransitionOutput {
        return _update(state, input)
    }
    
}

struct Behavior<StateType: BehaviorState, EffectType: BehaviorEffect> {

    typealias EffectPerformer = AnyBehaviorEffectPerformer<EffectType>
    typealias Create = (BehaviorMessage, BehaviorMessage.Context) -> TransitionOutput?
    typealias Update = (StateType, Input) -> TransitionOutput
    
    enum Input {
        
        case message(BehaviorMessage, BehaviorMessage.Context)
        case effectResult(EffectType.EffectResult)
    
    }
    
    struct TransitionOutput {
        
        let state: StateType
        let output: BehaviorOutput?
        let effect: EffectType?
        
        init(state: StateType, output: BehaviorOutput? = .none, effect: EffectType? = .none) {
            self.state = state
            self.output = output
            self.effect = effect
        }
        
    }
    
}
