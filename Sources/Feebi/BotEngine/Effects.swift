//
//  Effects.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation
import ReactiveSwift
import Result

protocol BehaviorEffect {
    
    associatedtype ResponseType
    associatedtype ErrorType: Error
    associatedtype JobMessageType: Codable
    
    typealias EffectResult = Result<ResponseType, ErrorType>
    typealias EffectOutput = (result: EffectResult, job: SchedulableJob<JobMessageType>?)
    typealias EffectOutputProducer = SignalProducer<EffectOutput, NoError>
    
}

enum EffectfulAction<EffectType: BehaviorEffect> {
    
    case cancellAllRunningEffects
    case effectResultProducer(EffectType.EffectOutputProducer)
    
}

protocol BehaviorEffectPerformer {
    
    associatedtype EffectType: BehaviorEffect

    func perform(effect: EffectType) -> EffectfulAction<EffectType>
    
}

struct EffectPerformerServices {
    
    var environment: [String : String]
    var repository: ObjectRepository
    var context: [String : Any]
    var slackService: SlackServiceProtocol?
    
    init(
        environment: [String : String] = ProcessInfo.processInfo.environment,
        repository: ObjectRepository,
        context: [String : Any] = [:],
        slackService: SlackServiceProtocol? = .none) {
        self.environment = environment
        self.repository = repository
        self.context = context
        self.slackService = slackService
    }
    
}

struct AnyBehaviorEffectPerformer<EffectType: BehaviorEffect>: BehaviorEffectPerformer {
    
    private let performEffect: (EffectType) -> EffectfulAction<EffectType>
    
    init<BehaviorEffectPerformerType: BehaviorEffectPerformer>(_ effectPerformer: BehaviorEffectPerformerType)
        where   BehaviorEffectPerformerType.EffectType == EffectType {
        self.performEffect = effectPerformer.perform(effect:)
    }
    
    func perform(effect: EffectType) -> EffectfulAction<EffectType> {
        return performEffect(effect)
    }
    
}
