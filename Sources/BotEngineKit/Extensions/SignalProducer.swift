//
//  SignalProducer.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 7/28/18.
//

import Foundation
import ReactiveSwift
import Result

precedencegroup ForwardApplication {
    associativity: left
}

infix operator |>: ForwardApplication

public func |><A, B, ErrorType: Error>(lhs: SignalProducer<A, ErrorType>, rhs: @escaping (A) -> SignalProducer<B, ErrorType>) -> SignalProducer<B, ErrorType> {
    return lhs.flatMap(.concat, rhs)
}

public func |><A, B, ErrorType: Error>(lhs: SignalProducer<A, ErrorType>, rhs: @escaping (A) -> B) -> SignalProducer<B, ErrorType> {
    return lhs.map(rhs)
}

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
