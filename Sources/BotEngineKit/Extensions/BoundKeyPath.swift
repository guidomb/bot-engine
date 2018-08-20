//
//  KeyPath.swift
//  WotServer
//
//  Created by Guido Marucci Blas on 8/16/18.
//

import Foundation

public struct BoundKeyPath<Root, Value> {
    
    public let keyPath: WritableKeyPath<Root, Value>
    public let value: Value
    
    public init(keyPath: WritableKeyPath<Root, Value>, value: Value) {
        self.keyPath = keyPath
        self.value = value
    }
    
    public func apply(to object: inout Root) {
        object[keyPath: keyPath] = value
    }
    
}
