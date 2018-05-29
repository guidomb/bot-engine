//
//  Result.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 4/2/18.
//

import Foundation
import Result

precedencegroup ResultApplicativePrecedence {
    associativity: left
    lowerThan: NilCoalescingPrecedence
}

infix operator <^>: ResultApplicativePrecedence
func <^><Value, Error: Swift.Error, B>(lhs: (Value) -> B, rhs: Result<Value, Error>) -> Result<B, Error> {
    return rhs.map(lhs)
}

infix operator <*>: ResultApplicativePrecedence
func <*><Value, Error: Swift.Error, B>(lhs: Result<(Value) ->B, Error>, rhs: Result<Value, Error>) -> Result<B, Error> {
    switch (lhs, rhs) {
    case let (.success(f), .success(value)):
        return .success(f(value))
    case let (_, .failure(error)):
        return .failure(error)
    case let (.failure(error), _):
        return .failure(error)
    }
}

extension Result {
    
    static func sequence<Value, Error: Swift.Error>(_ array: [Result<Value, Error>]) -> Result<[Value], Error> {
        var values: [Value] = []
        for result in array {
            switch result {
            case .success(let value):
                values.append(value)
            case .failure(let error):
                return .failure(error)
            }
        }
        return .success(values)
    }
    
}
