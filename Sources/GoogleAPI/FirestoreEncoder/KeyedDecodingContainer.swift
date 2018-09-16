import Foundation

extension _FirestoreDecoder {
    
    final class KeyedContainer<Key> where Key: CodingKey {
        
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]

        fileprivate let mapValue: FirestoreDocument.MapValue
        
        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any], mapValue: FirestoreDocument.MapValue) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.mapValue = mapValue
        }
        
    }
    
}

extension _FirestoreDecoder.KeyedContainer: KeyedDecodingContainerProtocol {
    
    var allKeys: [Key] {
        guard let fields = mapValue.fields else {
            return []
        }
        
        return fields.keys.compactMap { Key(stringValue: $0) }
    }
    
    func contains(_ key: Key) -> Bool {
        return mapValue.fields?.keys.contains(key.stringValue) ?? false
    }
    
    func decodeNil(forKey key: Key) throws -> Bool {
        if case .nullValue = try getValue(for: key) {
            return true
        } else {
            return false
        }
    }
    
    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: String.Type, forKey key: Key) throws -> String {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
        let value = try getValue(for: key)
        let container = _FirestoreDecoder.SingleValueContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            value: value
        )
        return try container.decode(type)
    }
    
 
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        guard case .arrayValue(let nestedValue) = try getValue(for: key) else {
             throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "cannot decode nested container for key: \(key)")
        }
        
        return _FirestoreDecoder.UnkeyedContainer(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            arrayValue: nestedValue
        )
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        guard case .mapValue(let nestedValue) = try getValue(for: key) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "cannot decode nested container for key: \(key)")
        }
        
        let container = _FirestoreDecoder.KeyedContainer<NestedKey>(
            codingPath: nestedCodingPath(for: key),
            userInfo: userInfo,
            mapValue: nestedValue
        )
        
        return KeyedDecodingContainer(container)
    }
    
    func superDecoder() throws -> Decoder {
        guard let fields = mapValue.fields else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Cannot create super decoder with null fields")
             throw DecodingError.dataCorrupted(context)
        }
        
        return _FirestoreDecoder(document: .init(fields: fields))
    }
    
    func superDecoder(forKey key: Key) throws -> Decoder {
        guard case .mapValue(let nestedValue) = try getValue(for: key), let fields = nestedValue.fields else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "Cannot create super decoder with non-map value for key \(key)")
            throw DecodingError.dataCorrupted(context)
        }
        
        return _FirestoreDecoder(document: .init(fields: fields))
    }
}

extension _FirestoreDecoder.KeyedContainer: FirestoreDecodingContainer {
    
    var value: FirestoreDocument.Value {
        return .mapValue(mapValue)
    }
    
}

fileprivate extension _FirestoreDecoder.KeyedContainer {
    
    func getValue(for key: Key) throws -> FirestoreDocument.Value {
        guard let fields = mapValue.fields, let value = fields[key.stringValue] else {
            let context = DecodingError.Context(codingPath: self.codingPath, debugDescription: "key not found: \(key)")
            throw DecodingError.keyNotFound(key, context)
        }
        return value
    }
    
    func nestedCodingPath(for key: Key) -> [CodingKey] {
        return codingPath + [AnyCodingKey(key)]
    }
    
}
