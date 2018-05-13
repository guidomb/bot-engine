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
    associatedtype EffectResponseType
    associatedtype EffectErrorType
    associatedtype EffectPerformerType: BehaviorEffectPerformer where
        EffectPerformerType.EffectType == EffectType,
        EffectPerformerType.EffectResponseType == EffectResponseType,
        EffectPerformerType.EffectErrorType ==EffectErrorType
    
    typealias ConcreteBehavior = Behavior<StateType, EffectType, EffectResponseType, EffectErrorType>
    typealias BehaviorTransitionOutput = ConcreteBehavior.TransitionOutput
    typealias BehaviorInput = ConcreteBehavior.Input
    
    var effectPerformer: EffectPerformerType { get }
    var descriptionForCancellation: String { get }
    
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
    
    func mount(with observer: Signal<ChanneledBehaviorOutput, NoError>.Observer, for channel: ChannelId)
    
    func handle(message: BehaviorMessage, with context: BehaviorMessage.Context)
    
}

struct AnyBehavior<StateType: BehaviorState, EffectType, EffectResponseType, EffectErrorType: Error>: BehaviorProtocol {
    
    typealias ConcreteBehavior = Behavior<StateType, EffectType, EffectResponseType, EffectErrorType>
    typealias BehaviorTransitionOutput = ConcreteBehavior.TransitionOutput
    typealias BehaviorInput = ConcreteBehavior.Input
    
    let effectPerformer: AnyBehaviorEffectPerformer<EffectType, EffectResponseType, EffectErrorType>
    let descriptionForCancellation: String
    
    private let _create: (BehaviorMessage, BehaviorMessage.Context) -> BehaviorTransitionOutput?
    private let _update: (StateType, BehaviorInput) -> BehaviorTransitionOutput
    
    init<BehaviorType: BehaviorProtocol>(_ behavior: BehaviorType) where
        BehaviorType.StateType == StateType,
        BehaviorType.EffectType == EffectType,
        BehaviorType.EffectResponseType == EffectResponseType,
        BehaviorType.EffectErrorType == EffectErrorType {
        self.effectPerformer = AnyBehaviorEffectPerformer(behavior.effectPerformer)
        self.descriptionForCancellation = behavior.descriptionForCancellation
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

struct Behavior<StateType: BehaviorState, EffectType, EffectResponseType, EffectErrorType: Error> {

    typealias EffectPerformer = AnyBehaviorEffectPerformer<EffectType, EffectResponseType, EffectErrorType>
    typealias EffectResult = Result<EffectResponseType, EffectErrorType>
    typealias EffectResultProducer = SignalProducer<EffectResult, NoError>
    typealias Create = (BehaviorMessage, BehaviorMessage.Context) -> TransitionOutput?
    typealias Update = (StateType, Input) -> TransitionOutput
    
    enum Input {
        
        case message(BehaviorMessage, BehaviorMessage.Context)
        case effectResult(EffectResult)
    
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
