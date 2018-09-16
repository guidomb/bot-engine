import Foundation

public class FirestoreEncoder {
    
    public init() {}
    
    public func encode(_ value: Encodable) throws -> Data {
        let encoder = _FirestoreEncoder()
        try value.encode(to: encoder)
        return try encoder.value.map(JSONEncoder().encode) ?? Data()
    }
    
    public func encode(_ value: Encodable, name: String? = .none, skipFields: [String] = []) throws -> FirestoreDocument {
        let encoder = _FirestoreEncoder()
        try value.encode(to: encoder)
        
        guard case .some(.mapValue(let mapValue)) = encoder.value, let fields = mapValue.fields else {
            let context = EncodingError.Context(codingPath: [], debugDescription: "Unable to encode value as FirestoreDocument because its fields cannot be mapped as FirestoreDocument.Value.mapValue")
            throw EncodingError.invalidValue(value, context)
        }
        
        let fieldPaths = skipFields.map { $0.split(separator: ".").map(String.init) }
        let filteredFields = fields.filterFields(fieldPaths)
        
        return FirestoreDocument(name: name, fields: filteredFields)
    }
    
    public func encodeProperty(_ value: Encodable) throws -> FirestoreDocument.Value {
        let encoder = _FirestoreEncoder()
        try value.encode(to: encoder)
        guard let encodedValue = encoder.value else {
            let context = EncodingError.Context(codingPath: [], debugDescription: "Unable to encode value as FirestoreDocument.Value")
            throw EncodingError.invalidValue(value, context)
        }
        return encodedValue
    }
    
}

final class _FirestoreEncoder {
    
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    var value: FirestoreDocument.Value? {
        return container?.value
    }
    
    fileprivate var container: FirestoreEncodingContainer?
    
}

extension _FirestoreEncoder: Encoder {
    fileprivate func assertCanCreateContainer() {
        precondition(self.container == nil)
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        assertCanCreateContainer()
        
        let container = KeyedContainer<Key>(codingPath: self.codingPath, userInfo: self.userInfo)
        self.container = container
        
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        assertCanCreateContainer()
        
        let container = UnkeyedContainer(codingPath: self.codingPath, userInfo: self.userInfo)
        self.container = container
        
        return container
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        assertCanCreateContainer()
        
        let container = SingleValueContainer(codingPath: self.codingPath, userInfo: self.userInfo)
        self.container = container
        
        return container
    }
}

protocol FirestoreEncodingContainer: class {
    
    var value: FirestoreDocument.Value? { get }

}

fileprivate extension Dictionary where Key == String, Value == FirestoreDocument.Value {
    
    func filterFields(_ fieldPaths: [[String]]) -> [String : FirestoreDocument.Value] {
        var result: [String : FirestoreDocument.Value] = [:]
        for (key, value) in self {
            let applicableFieldPaths = fieldPaths.filter { $0.first == key }
            if applicableFieldPaths.contains(where: { $0.count == 1 }) {
                continue
            } else if case .mapValue(let mapValue) = value, let fields = mapValue.fields {
                let innerFieldPath = applicableFieldPaths.map { Array($0.dropFirst()) }
                result[key] = .mapValue(.init(fields: fields.filterFields(innerFieldPath)))
            } else {
                result[key] = value
            }
        }
        return result
    }
    
}
