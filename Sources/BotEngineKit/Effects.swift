//
//  Effects.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation
import ReactiveSwift
import Result

public protocol BehaviorEffect {
    
    associatedtype ResponseType
    associatedtype ErrorType: Error
    associatedtype JobMessageType: Codable
    
    typealias EffectResult = Result<ResponseType, ErrorType>
    typealias EffectOutput = (result: EffectResult, job: SchedulableJob<JobMessageType>?)
    typealias EffectOutputProducer = SignalProducer<EffectOutput, NoError>
    
}

public protocol BehaviorEffectPerformer {
    
    associatedtype EffectType: BehaviorEffect

    func perform(effect: EffectType, for channel: ChannelId) -> EffectType.EffectOutputProducer
    
}

public struct NoEffect: BehaviorEffect {
    
    public enum Response { }
    
    public typealias ResponseType = Response
    public typealias ErrorType = NoError
    public typealias JobMessageType = NoJobMessage
    
}

public struct NoEffectPerformer: BehaviorEffectPerformer {
    
    public func perform(effect: NoEffect, for channel: ChannelId) -> NoEffect.EffectOutputProducer {
        return .empty
    }
    
}

public struct AnyBehaviorEffectPerformer<EffectType: BehaviorEffect>: BehaviorEffectPerformer {
    
    private let performEffect: (EffectType, ChannelId) -> EffectType.EffectOutputProducer
    
    public init<BehaviorEffectPerformerType: BehaviorEffectPerformer>(_ effectPerformer: BehaviorEffectPerformerType)
        where   BehaviorEffectPerformerType.EffectType == EffectType {
        self.performEffect = effectPerformer.perform
    }
    
    public func perform(effect: EffectType, for channel: ChannelId) -> EffectType.EffectOutputProducer {
        return performEffect(effect, channel)
    }
    
}
