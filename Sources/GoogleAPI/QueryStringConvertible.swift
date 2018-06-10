//
//  File.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 4/1/18.
//

import Foundation

public protocol QueryStringConvertible {
    
    var asQueryString: String { get }
    
}

public func toQueryString(object: Any) -> String? {
    let mirror = Mirror(reflecting: object)
    guard let displayStyle = mirror.displayStyle else {
        return .none
    }
    
    switch displayStyle {
    case .class, .struct, .dictionary:
        return mirror.children.lazy
            .filter { isOptional($0) }
            .filter { $0 != nil || $1 is QueryStringConvertible }
            .map { "\($0!)=\($1)".urlEncoded }
            .joined(separator: "&")
    default:
        return .none
    }
}

extension Array where Element: CustomStringConvertible {
    
    public func makeQueryString(withKey key: String) -> String {
        return self.map { "\(key)=\($0)".urlEncoded }.joined(separator: "&")
    }
    
}

extension Array: QueryStringConvertible where Element: QueryStringConvertible {
    
    public var asQueryString: String {
        return self.map { $0.asQueryString }.joined(separator: "&")
    }
    
}

extension Dictionary: QueryStringConvertible where Key == String, Value: CustomStringConvertible {
    
    public var asQueryString: String {
        return self.map { "\($0)=\($1)" }.joined(separator: "&")
    }
    
}

extension String {
    
    var urlEncoded: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? self
    }
    
}

fileprivate func isOptional(_ object: Any) -> Bool {
    if case .some(.optional) = Mirror(reflecting: object).displayStyle {
        return true
    } else {
        return false
    }
}