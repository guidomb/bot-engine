//
//  Effects.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation
import ReactiveSwift
import Result

enum EffectfulAction<EffectResponseType, EffectErrorType: Error> {
    
    typealias EffectResult = Result<EffectResponseType, EffectErrorType>
    typealias EffectResultProducer = SignalProducer<EffectResult, NoError>
    
    case cancellAllRunningEffects
    case effectResultProducer(EffectResultProducer)
    
}

protocol BehaviorEffectPerformer {
    
    associatedtype EffectType
    associatedtype EffectResponseType
    associatedtype EffectErrorType: Error
    
    typealias EffectResult = Result<EffectResponseType, EffectErrorType>
    typealias EffectResultProducer = SignalProducer<EffectResult, NoError>
    
    func perform(effect: EffectType) -> EffectfulAction<EffectResponseType, EffectErrorType>
    
}

struct AnyBehaviorEffectPerformer<EffectType, EffectResponseType, EffectErrorType: Error>: BehaviorEffectPerformer {
    
    typealias EffectResult = Result<EffectResponseType, EffectErrorType>
    typealias EffectResultProducer = SignalProducer<EffectResult, NoError>
    
    private let performEffect: (EffectType) -> EffectfulAction<EffectResponseType, EffectErrorType>
    
    init<BehaviorEffectPerformerType: BehaviorEffectPerformer>(_ effectPerformer: BehaviorEffectPerformerType)
        where   BehaviorEffectPerformerType.EffectType == EffectType,
        BehaviorEffectPerformerType.EffectResponseType == EffectResponseType,
        BehaviorEffectPerformerType.EffectErrorType ==EffectErrorType {
            self.performEffect = effectPerformer.perform(effect:)
    }
    
    func perform(effect: EffectType) -> EffectfulAction<EffectResponseType, EffectErrorType> {
        return performEffect(effect)
    }
    
}
