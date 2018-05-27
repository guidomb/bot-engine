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

protocol BehaviorEffectPerformer {
    
    associatedtype EffectType: BehaviorEffect

    func perform(effect: EffectType, for channel: ChannelId) -> EffectType.EffectOutputProducer
    
}

struct AnyBehaviorEffectPerformer<EffectType: BehaviorEffect>: BehaviorEffectPerformer {
    
    private let performEffect: (EffectType, ChannelId) -> EffectType.EffectOutputProducer
    
    init<BehaviorEffectPerformerType: BehaviorEffectPerformer>(_ effectPerformer: BehaviorEffectPerformerType)
        where   BehaviorEffectPerformerType.EffectType == EffectType {
        self.performEffect = effectPerformer.perform
    }
    
    func perform(effect: EffectType, for channel: ChannelId) -> EffectType.EffectOutputProducer {
        return performEffect(effect, channel)
    }
    
}

struct NoEffect: BehaviorEffect {
    
    enum Response { }
    
    typealias ResponseType = Response
    typealias ErrorType = NoError
    typealias JobMessageType = NoJobMessage
    
}

struct NoEffectPerformer: BehaviorEffectPerformer {
    
    func perform(effect: NoEffect, for channel: ChannelId) -> NoEffect.EffectOutputProducer {
        return .empty
    }
    
}
