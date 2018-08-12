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
        // class, struct and dictionary all have
        // children with non-nil key which are the name
        // of the property in a class or struct or the
        // name of the key in a dictionary.
        return mirror.children.lazy
            // We need to make filter out children without labels
            // unless they are QueryStringConvertible.
            // Also if a value's type is Optional then we need to
            // filter out .none value. This check needs to be done
            // dynamically at runtime. We don't want quer string that
            // look like 'foo=nil&bar=nil'
            .filter { ($0 != nil || $1 is QueryStringConvertible) && !isNone($1) }
            .map { label, value in
                if value is QueryStringConvertible {
                    return (value as! QueryStringConvertible).asQueryString
                } else {
                    // We can safely unwrap label because of the
                    // the filter clause.
                    // We can also unwrap the value (if it's an optional)
                    // also because of the filter clause that checks
                    // if the value is not .none
                    return "\(label!)=\(unwrapped(value))".urlEncoded
                }
            }
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

extension Dictionary: QueryStringConvertible where Key == String, Value == Optional<String> {
    
    public var asQueryString: String {
        return self.filter { $1 != nil }.map { "\($0)=\($1!)".urlEncoded }.joined(separator: "&")
    }
    
}

extension String {
    
    var urlEncoded: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? self
    }
    
}


/// Runtime checks if the given object is an optional
/// type with the value .none.
///
/// - Parameter object: the object to check if it's value is .none
/// - Returns: true if the object is an .none optional downcast to Any. false otherwise.
fileprivate func isNone(_ object: Any) -> Bool {
    let mirror = Mirror(reflecting: object)
    if case .some(.optional) = mirror.displayStyle {
        return mirror.children.first?.label != "some"
    } else {
        return false
    }
}


/// Unsafely unwraps a value if it's an optional
/// at runtime.
///
/// let a: String? = "foo"
/// let b: String = "bar"
/// let c: String? = .none
///
/// unwrapped(a) -> "foo"
/// unwrapped(b) -> "bar"
/// unwrapped(c) -> CRASH!
///
/// - Parameter object: the object to be unwrapped if it is an optional value.
/// - Returns: the unwrapped value if it is an optional value or the object otherwise.
fileprivate func unwrapped(_ object: Any) -> Any {
    let mirror = Mirror(reflecting: object)
    if case .some(.optional) = mirror.displayStyle {
        // It is not possible to 'cast back' an Any value
        // that was downcast from Option to Any.
        // Doing (object as Optional<Any>) when object is .none
        // returns .some(nil)
        return mirror.children.first!.value
    } else {
        return object
    }
}
