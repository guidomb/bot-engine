import Foundation

extension _FirestoreEncoder {
    
    final class KeyedContainer<Key> where Key: CodingKey {
    
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        
        private var storage: [AnyCodingKey : FirestoreEncodingContainer] = [:]
        
        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
        }
        
        func nestedCodingPath(forKey key: CodingKey) -> [CodingKey] {
            return self.codingPath + [key]
        }
        
    }
    
}

extension _FirestoreEncoder.KeyedContainer: KeyedEncodingContainerProtocol {
    func encodeNil(forKey key: Key) throws {
        var container = self.nestedSingleValueContainer(forKey: key)
        try container.encodeNil()
    }
    
    func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        var container = self.nestedSingleValueContainer(forKey: key)
        try container.encode(value)
    }
    
    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let container = _FirestoreEncoder.UnkeyedContainer(codingPath: self.nestedCodingPath(forKey: key), userInfo: self.userInfo)
        self.storage[AnyCodingKey(key)] = container
        
        return container
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = _FirestoreEncoder.KeyedContainer<NestedKey>(codingPath: self.nestedCodingPath(forKey: key), userInfo: self.userInfo)
        self.storage[AnyCodingKey(key)] = container
        
        return KeyedEncodingContainer(container)
    }
    
    func superEncoder() -> Encoder {
        fatalError("Unimplemented") // FIXME
    }
    
    func superEncoder(forKey key: Key) -> Encoder {
        fatalError("Unimplemented") // FIXME
    }
}

extension _FirestoreEncoder.KeyedContainer: FirestoreEncodingContainer {
    
    var value: FirestoreDocument.Value? {
        var fields: [String : FirestoreDocument.Value] = [:]
        for (key, container) in storage {
            guard let value = container.value else {
                return .none
            }
            fields[key.stringValue] = value
        }
        return .mapValue(.init(fields: fields))
    }
    
}

fileprivate extension _FirestoreEncoder.KeyedContainer {
    
    func nestedSingleValueContainer(forKey key: Key) -> SingleValueEncodingContainer {
        let container = _FirestoreEncoder.SingleValueContainer(codingPath: self.nestedCodingPath(forKey: key), userInfo: self.userInfo)
        self.storage[AnyCodingKey(key)] = container
        return container
    }
    
}
