//
//  Collection.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 8/16/18.
//

import Foundation

extension Collection {
    
    public func map<Value>(_ keyPath: KeyPath<Element, Value>) -> [Value] {
        return self.map { $0[keyPath: keyPath] }
    }
    
}

extension Collection where Element: Collection {
    
    public func flatten() -> [Element.Element] {
        return self.flatMap { $0 }
    }
    
}
