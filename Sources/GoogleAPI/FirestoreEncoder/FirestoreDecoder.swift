import Foundation

final public class FirestoreDecoder {
    
    public init() { }
    
    public func decode<T>(_ type: T.Type, from data: Data) throws -> T where T : Decodable {
        let document = try JSONDecoder().decode(FirestoreDocument.self, from: data)
        let decoder = _FirestoreDecoder(document: document)
        return try T(from: decoder)
    }
    
    public func decode<T>(_ type: T.Type, from document: FirestoreDocument) throws -> T where T : Decodable {
        let decoder = _FirestoreDecoder(document: document)
        return try T(from: decoder)
    }
    
}

final class _FirestoreDecoder {
    
    enum Storage {
        
        case document(FirestoreDocument)
        case array(FirestoreDocument.ArrayValue)
        case value(FirestoreDocument.Value)
        
    }
    
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    var container: FirestoreDecodingContainer?
    
    fileprivate let storage: Storage
    
    init(document: FirestoreDocument) {
        self.storage = .document(document)
    }
    
    init(array: FirestoreDocument.ArrayValue) {
        self.storage = .array(array)
    }
    
    init(value: FirestoreDocument.Value) {
        if case .arrayValue(let array) = value {
            self.storage = .array(array)
        } else {
            self.storage = .value(value)
            
        }
    }
    
}

extension _FirestoreDecoder: Decoder {
    
    fileprivate func assertCanCreateContainer() {
        precondition(self.container == nil)
    }
        
    func container<Key>(keyedBy type: Key.Type) -> KeyedDecodingContainer<Key> where Key : CodingKey {
        assertCanCreateContainer()
        let properties: FirestoreDocument.MapValue
        switch storage {
        case .document(let document):
            properties = .init(fields: document.fields)
        case .value(.mapValue(let mapValue)):
            properties = mapValue
        default:
            fatalError("Root container must be a document")
        }
    
        let container = KeyedContainer<Key>(
            codingPath: self.codingPath,
            userInfo: self.userInfo,
            mapValue: properties
        )
        self.container = container

        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedDecodingContainer {
        assertCanCreateContainer()
        guard case .array(let array) = storage else {
            fatalError("Root container must be an array")
        }
        let container = _FirestoreDecoder.UnkeyedContainer(
            codingPath: self.codingPath,
            userInfo: self.userInfo,
            arrayValue: array
        )
        self.container = container
        return container
    }
    
    func singleValueContainer() -> SingleValueDecodingContainer {
        assertCanCreateContainer()
        guard case .value(let value) = storage else {
            fatalError("Root container must be a single value")
        }
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: self.codingPath,
            userInfo: self.userInfo,
            value: value
        )
        self.container = container
        return container
    }
}

protocol FirestoreDecodingContainer {
    
    var value: FirestoreDocument.Value { get }
    
}
