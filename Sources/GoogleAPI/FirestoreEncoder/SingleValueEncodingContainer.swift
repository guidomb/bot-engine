import Foundation

extension _FirestoreEncoder {
    
    final class SingleValueContainer {
        
        var codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any]
        
        private var storage: FirestoreDocument.Value?
        
        init(codingPath: [CodingKey], userInfo: [CodingUserInfoKey : Any]) {
            self.codingPath = codingPath
            self.userInfo = userInfo
        }
    }
    
}

extension _FirestoreEncoder.SingleValueContainer: SingleValueEncodingContainer {
    
    func encodeNil() throws {
        try checkCanEncode(value: nil)
        storage = .nullValue
    }
    
    func encode(_ value: Bool) throws {
        try checkCanEncode(value: nil)
        storage = .booleanValue(value)
    }
    
    func encode(_ value: String) throws {
        try checkCanEncode(value: nil)
        storage = .stringValue(value)
    }
    
    func encode(_ value: Double) throws {
        try checkCanEncode(value: nil)
        storage = .doubleValue(value)
    }
    
    func encode(_ value: Float) throws {
        try checkCanEncode(value: nil)
        storage = .doubleValue(Double(value))
    }
    
    func encode(_ value: Int) throws {
        try checkCanEncode(value: nil)
        storage = .integerValue(String(value))
    }
    
    func encode(_ value: Int8) throws {
        try checkCanEncode(value: nil)
        storage = .integerValue(String(value))
    }
    
    func encode(_ value: Int16) throws {
        try checkCanEncode(value: nil)
        storage = .integerValue(String(value))
    }
    
    func encode(_ value: Int32) throws {
        try checkCanEncode(value: nil)
        storage = .integerValue(String(value))
    }
    
    func encode(_ value: Int64) throws {
        try checkCanEncode(value: nil)
        storage = .integerValue(String(value))
    }
    
    func encode(_ value: UInt) throws {
        try checkCanEncode(value: nil)
        storage = .integerValue(String(value))
    }
    
    func encode(_ value: UInt8) throws {
        try checkCanEncode(value: nil)
        storage = .integerValue(String(value))
    }
    
    func encode(_ value: UInt16) throws {
        try checkCanEncode(value: nil)
        storage = .integerValue(String(value))
    }
    
    func encode(_ value: UInt32) throws {
        try checkCanEncode(value: nil)
        storage = .integerValue(String(value))
    }
    
    func encode(_ value: UInt64) throws {
        try checkCanEncode(value: nil)
        storage = .integerValue(String(value))
    }
    
    func encode<T>(_ value: T) throws where T : Encodable {
        try checkCanEncode(value: nil)
        
        let valuesType = type(of: value)
        if valuesType == Date.self || valuesType == NSDate.self {
            let date = value as! Date
            storage = .timestampValue(FirestoreDocument.serialize(date: date))
        } else if valuesType == Data.self || valuesType ==  NSData.self {
            let data = value as! Data
            storage = .bytesValue(data.base64EncodedString())
        } else {
            let encoder = _FirestoreEncoder()
            try value.encode(to: encoder)
            storage = encoder.value
        }
    }
}

fileprivate extension _FirestoreEncoder.SingleValueContainer {
    
    func checkCanEncode(value: Any?) throws {
        guard storage == nil else {
            let context = EncodingError.Context(codingPath: self.codingPath, debugDescription: "Attempt to encode value through single value container when previously value already encoded.")
            throw EncodingError.invalidValue(value as Any, context)
        }
    }
    
}

extension _FirestoreEncoder.SingleValueContainer: FirestoreEncodingContainer {
    
    var value: FirestoreDocument.Value? {
        return storage
    }
    
}
