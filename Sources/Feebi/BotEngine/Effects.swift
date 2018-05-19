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
    typealias ResultProducer = SignalProducer<EffectOutput, NoError>
    
}

enum EffectfulAction<EffectType: BehaviorEffect> {
    
    case cancellAllRunningEffects
    case effectResultProducer(EffectType.ResultProducer)
    
}

protocol BehaviorEffectPerformer {
    
    associatedtype EffectType: BehaviorEffect

    func perform(effect: EffectType) -> EffectfulAction<EffectType>
    
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
