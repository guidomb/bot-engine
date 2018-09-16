import Foundation

extension _FirestoreDecoder {
    
    final class UnkeyedContainer {
    
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        var currentIndex: Int = 0
        
        fileprivate let arrayValue: FirestoreDocument.ArrayValue
        
        init(
            codingPath: [CodingKey],
            userInfo: [CodingUserInfoKey : Any],
            arrayValue: FirestoreDocument.ArrayValue) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.arrayValue = arrayValue
        }
        
    }
    
}

extension _FirestoreDecoder.UnkeyedContainer: UnkeyedDecodingContainer {
    
    var count: Int? {
        return arrayValue.values?.count
    }
    
    var isAtEnd: Bool {
        guard let count = arrayValue.values?.count else {
            return true
        }
        return currentIndex >= count
    }
    
    
    func decodeNil() throws -> Bool {
        defer {
            currentIndex += 1
        }
        
        if case .nullValue = try currentValue() {
            return true
        } else {
            return false
        }
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        defer {
            currentIndex += 1
        }
        
        guard case .booleanValue(let booleanValue) = try currentValue() else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Bool")
            throw DecodingError.typeMismatch(Bool.self, context)
        }
        return booleanValue
    }
    
    func decode(_ type: String.Type) throws -> String {
        defer {
            currentIndex += 1
        }
        
        guard case .stringValue(let stringValue) = try currentValue() else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as String")
            throw DecodingError.typeMismatch(String.self, context)
        }
        return stringValue
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        defer {
            currentIndex += 1
        }
        
        guard case .doubleValue(let doubleValue) = try currentValue() else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Double")
            throw DecodingError.typeMismatch(Double.self, context)
        }
        return doubleValue
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        defer {
            currentIndex += 1
        }
        
        guard case .doubleValue(let doubleValue) = try currentValue() else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Float")
            throw DecodingError.typeMismatch(Double.self, context)
        }
        return Float(doubleValue)
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        defer {
            currentIndex += 1
        }
        
        guard case .integerValue(let stringValue) = try currentValue(), let integerValue = Int(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Int")
            throw DecodingError.typeMismatch(Int.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        defer {
            currentIndex += 1
        }
        
        guard case .integerValue(let stringValue) = try currentValue(), let integerValue = Int8(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Int8")
            throw DecodingError.typeMismatch(Int8.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        defer {
            currentIndex += 1
        }
        
        guard case .integerValue(let stringValue) = try currentValue(), let integerValue = Int16(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Int16")
            throw DecodingError.typeMismatch(Int16.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        defer {
            currentIndex += 1
        }
        
        guard case .integerValue(let stringValue) = try currentValue(), let integerValue = Int32(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Int32")
            throw DecodingError.typeMismatch(Int32.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        defer {
            currentIndex += 1
        }
        
        guard case .integerValue(let stringValue) = try currentValue(), let integerValue = Int64(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Int64")
            throw DecodingError.typeMismatch(Int64.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        defer {
            currentIndex += 1
        }
        
        guard case .integerValue(let stringValue) = try currentValue(), let integerValue = UInt(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as UInt")
            throw DecodingError.typeMismatch(UInt.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        defer {
            currentIndex += 1
        }
        
        guard case .integerValue(let stringValue) = try currentValue(), let integerValue = UInt8(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as UInt8")
            throw DecodingError.typeMismatch(UInt8.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        defer {
            currentIndex += 1
        }
        
        guard case .integerValue(let stringValue) = try currentValue(), let integerValue = UInt16(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as UInt16")
            throw DecodingError.typeMismatch(UInt16.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        defer {
            currentIndex += 1
        }
        
        guard case .integerValue(let stringValue) = try currentValue(), let integerValue = UInt32(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as UInt32")
            throw DecodingError.typeMismatch(UInt32.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        defer {
            currentIndex += 1
        }
        
        guard case .integerValue(let stringValue) = try currentValue(), let integerValue = UInt64(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as UInt64")
            throw DecodingError.typeMismatch(UInt64.self, context)
        }
        return integerValue
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        defer {
            currentIndex += 1
        }
        
        let value = try currentValue()
        let decoder = _FirestoreDecoder(value: value)
        decoder.codingPath = nestedCodingPath
        decoder.userInfo = userInfo
        return try T(from: decoder)
    }
    
    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        defer {
            currentIndex += 1
        }
        
        guard case .arrayValue(let nestedValue) = try currentValue() else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "Cannot create a UnkeyedDecodingContainer for a non-array value at index \(currentIndex)")
        }
        
        return _FirestoreDecoder.UnkeyedContainer(
            codingPath: nestedCodingPath,
            userInfo: userInfo,
            arrayValue: nestedValue
        )
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
        defer {
            currentIndex += 1
        }
        
        guard case .mapValue(let nestedValue) = try currentValue() else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "Cannot create a UnkeyedDecodingContainer for a non-map value at index \(currentIndex)")
        }
        
        let container = _FirestoreDecoder.KeyedContainer<NestedKey>(
            codingPath: nestedCodingPath,
            userInfo: userInfo,
            mapValue: nestedValue
        )
        
        return KeyedDecodingContainer(container)
    }

    func superDecoder() throws -> Decoder {
        fatalError("Implement me!")
    }
    
}

extension _FirestoreDecoder.UnkeyedContainer: FirestoreDecodingContainer {
    
    var value: FirestoreDocument.Value {
        return .arrayValue(arrayValue)
    }

}

fileprivate extension _FirestoreDecoder.UnkeyedContainer {
    
    func currentValue() throws -> FirestoreDocument.Value {
        guard let values = arrayValue.values, currentIndex < values.count else {
            throw DecodingError.dataCorruptedError(in: self, debugDescription: "Cannot decode value from empty array value.")
        }
        return values[currentIndex]
    }
    
    var nestedCodingPath: [CodingKey] {
        return codingPath + [AnyCodingKey(intValue: currentIndex)!]
    }
    
}
