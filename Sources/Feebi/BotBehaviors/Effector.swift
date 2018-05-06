//
//  Effector.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/6/18.
//

import Foundation
import ReactiveSwift

protocol EffectorProtocol {
    
    init(observer: Behavior.EffectObserver)
    
    func perform(effect: Behavior.Effect, forChannel channel: ChannelId)
    
}

final class Effector: EffectorProtocol {
    
    private let observer: Behavior.EffectObserver
    private var disposables: [ChannelId : Disposable] = [:]
    
    init(observer: Behavior.EffectObserver) {
        self.observer = observer
    }
    
    
    func perform(effect: Behavior.Effect, forChannel channel: ChannelId) {
        switch effect {
           
        case .cancelRunningEffects:
            if let disposable = disposables[channel] {
                disposable.dispose()
                disposables.removeValue(forKey: channel)
            }
            
        case .validateFormAccess(let formId):
            // TODO implement this for real!
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.observer.send(value: Behavior.TaggedResult(
                    channel: channel,
                    result: .success(.formAccessValidated(formId: formId))
                ))
            }
            
        }
    }
    
}
