import Foundation

extension _FirestoreDecoder {
    
    final class SingleValueContainer {
        
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        
        let value: FirestoreDocument.Value
        
        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any], value: FirestoreDocument.Value) {
            self.codingPath = codingPath
            self.userInfo = userInfo
            self.value = value
        }
        
    }
    
}

extension _FirestoreDecoder.SingleValueContainer: SingleValueDecodingContainer {
    
    func decodeNil() -> Bool {
        if case .nullValue = value {
            return true
        } else {
            return false
        }
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        guard case .booleanValue(let booleanValue) = value else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Bool")
            throw DecodingError.typeMismatch(Bool.self, context)
        }
        return booleanValue
    }
    
    func decode(_ type: String.Type) throws -> String {
        guard case .stringValue(let stringValue) = value else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as String")
            throw DecodingError.typeMismatch(String.self, context)
        }
        return stringValue
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        guard case .doubleValue(let doubleValue) = value else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Double")
            throw DecodingError.typeMismatch(Double.self, context)
        }
        return doubleValue
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        guard case .doubleValue(let doubleValue) = value else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Float")
            throw DecodingError.typeMismatch(Double.self, context)
        }
        return Float(doubleValue)
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        guard case .integerValue(let stringValue) = value, let integerValue = Int(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Int")
            throw DecodingError.typeMismatch(Int.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        guard case .integerValue(let stringValue) = value, let integerValue = Int8(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Int8")
            throw DecodingError.typeMismatch(Int8.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        guard case .integerValue(let stringValue) = value, let integerValue = Int16(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Int16")
            throw DecodingError.typeMismatch(Int16.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        guard case .integerValue(let stringValue) = value, let integerValue = Int32(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Int32")
            throw DecodingError.typeMismatch(Int32.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        guard case .integerValue(let stringValue) = value, let integerValue = Int64(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as Int64")
            throw DecodingError.typeMismatch(Int64.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        guard case .integerValue(let stringValue) = value, let integerValue = UInt(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as UInt")
            throw DecodingError.typeMismatch(UInt.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard case .integerValue(let stringValue) = value, let integerValue = UInt8(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as UInt8")
            throw DecodingError.typeMismatch(UInt8.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard case .integerValue(let stringValue) = value, let integerValue = UInt16(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as UInt16")
            throw DecodingError.typeMismatch(UInt16.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard case .integerValue(let stringValue) = value, let integerValue = UInt32(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as UInt32")
            throw DecodingError.typeMismatch(UInt32.self, context)
        }
        return integerValue
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard case .integerValue(let stringValue) = value, let integerValue = UInt64(stringValue) else {
            let context = DecodingError.Context(codingPath: codingPath, debugDescription: "value \(value) cannot be decoded as UInt64")
            throw DecodingError.typeMismatch(UInt64.self, context)
        }
        return integerValue
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        if (type == Date.self || type == NSDate.self),
            case .timestampValue(let timestamp) = value,
            let date = FirestoreDocument.deserialize(date: timestamp) {
            return date as! T
        } else if (type == Data.self || type == NSData.self),
            case .bytesValue(let base64String) = value,
            let data = Data(base64Encoded: base64String) {
            return data as! T
        } else {
            let decoder = _FirestoreDecoder(value: value)
            decoder.codingPath = codingPath
            decoder.userInfo = userInfo
            return try T(from: decoder)
        }
    }
    
}

extension _FirestoreDecoder.SingleValueContainer: FirestoreDecodingContainer {}
