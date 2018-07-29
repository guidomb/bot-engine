//
//  SignalProducer.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 7/28/18.
//

import Foundation
import ReactiveSwift
import Result

extension SignalProducer where Error == AnyError {
    
    init(errorMessage: String) {
        self.init(error: AnyError(BotEngine.ErrorMessage(message: errorMessage)))
    }
    
}

extension Signal.Observer where Error == AnyError {
    
    func send(errorMessage: String) {
        self.send(error: AnyError(BotEngine.ErrorMessage(message: errorMessage)))
    }
    
}
