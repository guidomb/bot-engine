//
//  Effector.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/6/18.
//

import Foundation
import ReactiveSwift
import FeebiKit
import Result

protocol EffectorProtocol {
    
    func perform(effect: Behavior.Effect, forChannel channel: ChannelId)
    
}

final class Effector: EffectorProtocol {
    
    private let observer: Behavior.EffectObserver
    private var disposables: [ChannelId : Disposable] = [:]
    private let googleToken: GoogleAPI.Token
    
    init(observer: Behavior.EffectObserver, googleToken: GoogleAPI.Token) {
        self.observer = observer
        self.googleToken = googleToken
    }
    
    
    func perform(effect: Behavior.Effect, forChannel channel: ChannelId) {
        switch effect {
           
        case .cancelRunningEffects:
            if let disposable = disposables[channel] {
                disposable.dispose()
                disposables.removeValue(forKey: channel)
            }
            
        case .validateFormAccess(let formId):
            GoogleAPI.drive.files.get(fileId: formId)
                .execute(using: googleToken)
                .then(effectSuccess(for: channel, response: .formAccessValidated(formId: formId)))
                .flatMapError(handleFormAccessFailure(for: channel, formId: formId))
                .start(observer)
            
        }
    }
    
}

fileprivate extension Behavior.TaggedResult {
    
    static func success(response: Behavior.Effect.Response, channel: ChannelId) -> Behavior.TaggedResult {
        return .init(channel: channel, result: .success(response))
    }
    
    static func failure(error: Behavior.Effect.Error, channel: ChannelId) -> Behavior.TaggedResult {
        return .init(channel: channel, result: .failure(error))
    }
    
}

fileprivate func handleFormAccessFailure(for channel: ChannelId, formId: String)
    -> (GoogleAPI.RequestError) -> Behavior.EffectProducer {
    return { requestError in
        guard case .resourceError(let resourceError) = requestError, resourceError.error.code == 404 else {
            return Behavior.EffectProducer(value: .failure(error: .googleAPIError(requestError), channel: channel))
        }
        return Behavior.EffectProducer(value: .success(response: .formAccessDenied(formId: formId), channel: channel))
    }
}

fileprivate func effectSuccess(for channel: ChannelId, response: Behavior.Effect.Response) -> Behavior.EffectProducer {
    return Behavior.EffectProducer(value: .success(response: response, channel: channel))
}

fileprivate func effectFailure(for channel: ChannelId) -> (GoogleAPI.RequestError) -> Behavior.EffectProducer {
    return { Behavior.EffectProducer(value: .failure(error: .googleAPIError($0), channel: channel)) }
}


fileprivate func effectFailure(for channel: ChannelId) -> (Behavior.Effect.Error) -> Behavior.EffectProducer {
    return { Behavior.EffectProducer(value: .failure(error: $0, channel: channel)) }
}
