import Foundation

extension _FirestoreEncoder {
    
    final class UnkeyedContainer {
        
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey : Any]
        
        var count: Int {
            return storage.count
        }
        
        var nestedCodingPath: [CodingKey] {
            return self.codingPath + [AnyCodingKey(intValue: self.count)!]
        }

        private var storage: [FirestoreEncodingContainer] = []
        
        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
        }
        
    }
    
}

extension _FirestoreEncoder.UnkeyedContainer: UnkeyedEncodingContainer {
    
    func encodeNil() throws {
        var container = self.nestedSingleValueContainer()
        try container.encodeNil()
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        var container = self.nestedSingleValueContainer()
        try container.encode(value)
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        let container = _FirestoreEncoder.KeyedContainer<NestedKey>(codingPath: self.nestedCodingPath, userInfo: self.userInfo)
        self.storage.append(container)
        
        return KeyedEncodingContainer(container)
    }
    
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let container = _FirestoreEncoder.UnkeyedContainer(codingPath: self.nestedCodingPath, userInfo: self.userInfo)
        self.storage.append(container)
        return container
    }
    
    func superEncoder() -> Encoder {
        fatalError("Unimplemented") // FIXME
    }
}

fileprivate extension _FirestoreEncoder.UnkeyedContainer {
    
    private func nestedSingleValueContainer() -> SingleValueEncodingContainer {
        let container = _FirestoreEncoder.SingleValueContainer(codingPath: self.nestedCodingPath, userInfo: self.userInfo)
        self.storage.append(container)
        return container
    }
    
}

extension _FirestoreEncoder.UnkeyedContainer: FirestoreEncodingContainer {
    
    var value: FirestoreDocument.Value? {
        return .arrayValue(.init(storage.compactMap { $0.value }))
    }
    
}
