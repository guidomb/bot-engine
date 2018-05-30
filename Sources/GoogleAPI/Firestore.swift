//
//  Firestore.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/20/18.
//

import Foundation

public protocol JSONRepresentable: Encodable {

    func asJsonData() throws -> Data

    func asJson() throws -> [String : Any]?

}

extension JSONRepresentable {

    public func asJsonData() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public func asJson() throws -> [String : Any]? {
        return (try JSONSerialization.jsonObject(with: asJsonData(), options: .allowFragments)) as? [String : Any]
    }

}

public extension GoogleAPI {

    public struct Firestore {

        public struct Documents {

            private let basePath: String

            fileprivate init(basePath: String) {
                self.basePath = "\(basePath)/documents"
            }

            // https://firebase.google.com/docs/firestore/reference/rest/v1beta1/projects.databases.documents/createDocument
            public func createDocument(
                parent: String? = .none,
                collectionId: String,
                document: FirestoreDocument,
                options: FirestoreCreateDocumentOptions = FirestoreCreateDocumentOptions()) -> Resource<FirestoreDocument> {
                return Resource(
                    path: basePath + (parent ?? "") + "/\(collectionId)",
                    queryParameters: options,
                    requestBody: try? JSONEncoder().encode(document),
                    method: .post
                )
            }

            // https://firebase.google.com/docs/firestore/reference/rest/v1beta1/projects.databases.documents/list
            public func list(
                parent: String? = .none,
                collectionId: String,
                options: FirestoreListDocumentsOptions = FirestoreListDocumentsOptions()) -> Resource<FirestoreDocumentList> {
                return Resource(
                    path: basePath + (parent ?? "") + "/\(collectionId)",
                    queryParameters: options,
                    method: .get
                )
            }

            // https://firebase.google.com/docs/firestore/reference/rest/v1beta1/projects.databases.documents/patch
            public func patch(
                document: FirestoreDocument,
                options: FirestorePatchDocumentOptions) -> Resource<FirestoreDocument> {
                guard let documentName = document.name else {
                    fatalError("ERROR - Cannot patch a document without name")
                }
                return Resource(
                    path: "\(basePath)/\(documentName)",
                    queryParameters: options,
                    requestBody: try? JSONEncoder().encode(document),
                    method: .patch
                )
            }

            public func patch(
                document: FirestoreDocument,
                updateMask: FirestoreDocumentMask) -> Resource<FirestoreDocument> {
                return patch(document: document, options: FirestorePatchDocumentOptions(updateMask: updateMask))
            }

            // https://firebase.google.com/docs/firestore/reference/rest/v1beta1/projects.databases.documents/get
            public func get(
                documentName: String,
                mask: FirestoreDocumentMask? = .none) -> Resource<FirestoreDocument> {
                return Resource(
                    path: "\(basePath)/\(documentName)",
                    queryParameters: mask?.asQueryString,
                    method: .get
                )
            }

            // https://firebase.google.com/docs/firestore/reference/rest/v1beta1/projects.databases.documents/delete
            public func delete(
                documentName: String,
                currentDocument: FirestoreDocumentPrecondition? = .none) -> Resource<Void> {
                return Resource(
                    path: "\(basePath)/\(documentName)",
                    queryParameters: currentDocument?.asQueryString,
                    method: .delete
                )
            }
        }

        public var documents: Documents { return Documents(basePath: basePath) }

        private let baseURL = "https://firestore.googleapis.com"
        private let version: String

        private var basePath: String

        fileprivate init(version: String = "v1beta1", projectId: String, databaseId: String) {
            self.version = version
            self.basePath = "\(baseURL)/\(version)/projects/\(projectId)/databases/\(databaseId)"
        }

    }

    public static func firestore(projectId: String, databaseId: String) -> Firestore {
        return Firestore(projectId: projectId, databaseId: databaseId)
    }

}

// MARK :- Data models

public struct FirestoreDocumentMask: Encodable {

    public static func allFieldKeys(of document: FirestoreDocument) -> FirestoreDocumentMask {
        return FirestoreDocumentMask(fieldPaths: document.flattenFieldKeys)
    }

    public let fieldPaths: [String]

}

extension FirestoreDocumentMask: QueryStringConvertible {

    public var asQueryString: String {
        return "mask=\(asJsonString())"
    }

}

fileprivate extension FirestoreDocumentMask {

    func asJsonString() -> String {
        let jsonData = try? JSONEncoder().encode(self)
        guard let jsonString = jsonData.flatMap({ String(data: $0, encoding: .ascii) }) else {
            fatalError("ERROR - Cannot encode mask property into JSON string")
        }
        return jsonString
    }

}

public struct FirestoreCreateDocumentOptions: QueryStringConvertible {

    public var documentId: String?
    public var mask: FirestoreDocumentMask?

    public var asQueryString: String {
        var queryString = ""
        if let documentId = self.documentId {
            queryString += "documentId=\(documentId)"
        }
        if let mask = self.mask {
            let jsonString = mask.asJsonString()
            queryString += (queryString.isEmpty ? jsonString : "&\(jsonString)")
        }
        return queryString
    }

    public init() {}

}

public struct FirestoreListDocumentsOptions: QueryStringConvertible {

    public var pageSize: UInt?
    public var pageToken: String?
    public var orderBy: String?
    public var mask: FirestoreDocumentMask?
    public var showMissing: Bool = false

    public var asQueryString: String {
        var queryString = ""
        if let pageSize = self.pageSize {
            queryString += (queryString.isEmpty ? "" : "&") + "pageSize=\(pageSize)"
        }
        if let pageToken = self.pageToken {
            queryString += (queryString.isEmpty ? "" : "&") + "pageToken=\(pageToken)"
        }
        if let orderBy = self.orderBy {
            queryString += (queryString.isEmpty ? "" : "&") + "orderBy=\(orderBy)"
        }
        if let mask = self.mask {
            let jsonString = mask.asJsonString()
            queryString += (queryString.isEmpty ? jsonString : "&\(jsonString)")
        }
        queryString += (queryString.isEmpty ? "" : "&") + "showMissing=\(showMissing)"
        return queryString
    }

    public init() {}
}

public enum FirestoreDocumentPrecondition: QueryStringConvertible {

    case exists(Bool)
    case updateTime(Date)

    public var asQueryString: String {
        switch self {
        case .exists(let exists):
            return "exists=\(exists)"
        case .updateTime(let updateTime):
            let formatter = DateFormatter()
            formatter.dateFormat = FirestoreDocument.dateFormat
            return "updateTime=\(formatter.string(from: updateTime))"
        }
    }

}

public struct FirestorePatchDocumentOptions: QueryStringConvertible {

    public var updateMask: FirestoreDocumentMask
    public var mask: FirestoreDocumentMask?
    public var currentDocument: FirestoreDocumentPrecondition?

    public var asQueryString: String {
        var queryString = ""
        if let mask = self.mask {
            queryString += mask.asJsonString()
        }
        if let currentDocument = self.currentDocument {
            queryString += (queryString.isEmpty ? "" : "&") + currentDocument.asQueryString
        }
        queryString += (queryString.isEmpty ? "" : "&") + updateMask.asJsonString()
        return queryString
    }

    public init(updateMask: FirestoreDocumentMask) {
        self.updateMask = updateMask
    }

}

public struct FirestoreDocumentList: Decodable {

    public let documents: [FirestoreDocument]?
    public let nextPageToken: String?

    public init(documents: [FirestoreDocument], nextPageToken: String? = .none) {
        self.documents = documents
        self.nextPageToken = nextPageToken
    }
}

public struct FirestoreDocument: Codable, AutoEquatable {

    public indirect enum Value: Codable, AutoEquatable {

        enum CodingKeys: CodingKey {

            case nullValue
            case booleanValue
            case integerValue
            case doubleValue
            case timestampValue
            case stringValue
            case bytesValue
            case referenceValue
            case geoPointValue
            case arrayValue
            case mapValue

        }

        case nullValue
        case booleanValue(Bool)
        case integerValue(String)
        case doubleValue(Double)
        case timestampValue(String)
        case stringValue(String)
        case bytesValue(String)
        case referenceValue(String)
        case geoPointValue(LatLng)
        case arrayValue(ArrayValue)
        case mapValue(MapValue)

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let _ = try container.decodeIfPresent(String?.self, forKey: .nullValue) {
                self = .nullValue
            } else if let value = try container.decodeIfPresent(Bool.self, forKey: .booleanValue) {
                self = .booleanValue(value)
            } else if let value = try container.decodeIfPresent(String.self, forKey: .integerValue) {
                self = .integerValue(value)
            } else if let value = try container.decodeIfPresent(Double.self, forKey: .doubleValue) {
                self = .doubleValue(value)
            } else if let value = try container.decodeIfPresent(String.self, forKey: .timestampValue) {
                self = .timestampValue(value)
            } else if let value = try container.decodeIfPresent(String.self, forKey: .stringValue) {
                self = .stringValue(value)
            } else if let value = try container.decodeIfPresent(String.self, forKey: .bytesValue) {
                self = .bytesValue(value)
            } else if let value = try container.decodeIfPresent(String.self, forKey: .referenceValue) {
                self = .referenceValue(value)
            } else if let value = try container.decodeIfPresent(LatLng.self, forKey: .geoPointValue) {
                self = .geoPointValue(value)
            } else if let value = try container.decodeIfPresent(ArrayValue.self, forKey: .arrayValue) {
                self = .arrayValue(value)
            } else if let value = try container.decodeIfPresent(MapValue.self, forKey: .mapValue) {
                self = .mapValue(value)
            } else {
                throw DecodeError.unsupportedValueType
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .nullValue:
                try container.encode(Optional<String>.none, forKey: .nullValue)
            case .booleanValue(let value):
                try container.encode(value, forKey: .booleanValue)
            case .integerValue(let value):
                try container.encode(value, forKey: .integerValue)
            case .doubleValue(let value):
                try container.encode(value, forKey: .doubleValue)
            case .timestampValue(let value):
                try container.encode(value, forKey: .timestampValue)
            case .stringValue(let value):
                try container.encode(value, forKey: .stringValue)
            case .bytesValue(let value):
                try container.encode(value, forKey: .bytesValue)
            case .referenceValue(let value):
                try container.encode(value, forKey: .referenceValue)
            case .geoPointValue(let value):
                try container.encode(value, forKey: .geoPointValue)
            case .arrayValue(let value):
                try container.encode(value, forKey: .arrayValue)
            case .mapValue(let value):
                try container.encode(value, forKey: .mapValue)
            }
        }

    }

    public struct LatLng: Codable, AutoEquatable {

        public let latitude: Double
        public let longitude: Double

        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }

    }

    public struct ArrayValue: Codable, AutoEquatable {

        public let values: [Value]?

        init(_ values: [Value]) {
            self.values = values
        }

        init<SequenceType: Sequence>(_ values: SequenceType) where SequenceType.Element == Value {
            self.values = Array(values)
        }

    }

    public struct MapValue: Codable, AutoEquatable {

        public let fields: [String : Value]?

        public init(fields: [String : Value]) {
            self.fields = fields
        }

        func flattenFieldKeys(prefix: String = "") -> [String] {
            return fields?.flatMap { pair -> [String] in
                if case .mapValue(let map) = pair.value {
                    return map.flattenFieldKeys(prefix: pair.key)
                } else {
                    return ["\(prefix).\(pair.key)"]
                }
            } ?? []
        }

    }

    public let name: String?
    public let fields: [String : Value]
    public let createTime: Date
    public let updateTime: Date

    public init(name: String? = .none, fields: [String : Value]) {
        self.name = name
        self.fields = fields
        self.createTime = Date()
        self.updateTime = Date()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.fields = try container.decode([String : Value].self, forKey: .fields)
        self.createTime = try FirestoreDocument.decodeDate(forKey: .createTime, container: container)
        self.updateTime = try FirestoreDocument.decodeDate(forKey: .updateTime, container: container)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let name = self.name {
            try container.encode(name, forKey: .name)
        }
        try container.encode(fields, forKey: .fields)
    }

}

public extension FirestoreDocument {

    static var printSerializationDebugLog = false

    static func serialize(object: Any, skipFields: [String] = []) -> FirestoreDocument? {
        if printSerializationDebugLog {
            print("DEBUG - FirestoreDocument.serialize() - skipFields: \(skipFields), object: \(object)")
        }
        return serializeFields(object: object, skipFields: Set(skipFields)).map { FirestoreDocument(fields: $0) }
    }

    static func serializeFields(object: Any, skipFields: Set<String> = Set()) -> [String : FirestoreDocument.Value]? {
        let mirror = Mirror(reflecting: object)
        guard mirror.displayStyle == .struct || mirror.displayStyle == .class || mirror.displayStyle == .dictionary else {
            if  let jsonRepresentable = object as? JSONRepresentable,
                let maybeJson = try? jsonRepresentable.asJson(),
                let json = maybeJson {
                return serializeFields(object: json, skipFields: skipFields)
            } else {
                return .none
            }
        }

        let children: [Mirror.Child]
        if mirror.displayStyle == .dictionary {
            children = mirror.children.map { child in
                // Mirror values for dictionary types have children
                // for each key-value pair where Child.label is nil
                // and Child.value is (key: String, value: Any)
                let keyValuePair = (child.value  as! (key: String, value: Any))
                return (keyValuePair.key, keyValuePair.value)
            }
        } else {
            children = Array(mirror.children)
        }

        var fields: [String : FirestoreDocument.Value] = [:]
        for case let (label?, value) in children where !skipFields.contains(label) {
            if printSerializationDebugLog {
                print("DEBUG - FirestoreDocument.serializeFields() - \(label): \(type(of: value)) = \(value)")
            }
            let childMirror = Mirror(reflecting: value)
            // First try to serialize as a simple value
            // because there are some types that are classes but
            // can be converted to simple values like NSTaggedPointerString
            // that can be cast to String. In that previous example,
            // a value of type NSTaggedPointerString would have
            // .`class` as displayStyle.
            if canBeCastToSimpleValue(value), let serializedValue = serializeSimpleValue(value) {
                fields[label] = serializedValue
            } else if let displayStyle = childMirror.displayStyle {
                switch displayStyle {

                case .collection, .set:
                    let values = childMirror.children.lazy
                        .map { (label, value) -> FirestoreDocument.Value? in
                            let innerSkipFields: Set<String>
                            if let label = label {
                                innerSkipFields = filterSkipFields(skipFields, property: label)
                            } else {
                                innerSkipFields = Set()
                            }
                            return serializeSimpleValue(value, skipFields: innerSkipFields)
                        }
                        .filter { $0 != nil }
                        .map { $0! }
                    fields[label] = .arrayValue(ArrayValue(values))

                case .dictionary,.`struct`, .`class`:
                    let innerSkipFields = filterSkipFields(skipFields, property: label)
                    if let mapValue = serializeFields(object: value, skipFields: innerSkipFields) {
                        fields[label] = .mapValue(MapValue(fields: mapValue))
                    } else {
                        print("WARN - Unable to serialize property '\(label)' with value '\(value)' into FirestoreDocument.MapValue")
                    }

                case .optional:
                    if case .some((.some("some"), let childValue)) = childMirror.children.first {
                        let innerSkipFields = filterSkipFields(skipFields, property: label)
                        if let mapValue = serializeFields(object: childValue, skipFields: innerSkipFields) {
                            fields[label] = .mapValue(MapValue(fields: mapValue))
                        } else if let simpleValue = serializeSimpleValue(childValue) {
                            fields[label] = simpleValue
                        } else {
                            print("WARN - Unable to serialize optional property '\(label)' with value '\(value)' into FirestoreDocument.Value")
                        }
                    } else {
                        fields[label] = .nullValue
                    }

                default:
                    let innerSkipFields = filterSkipFields(skipFields, property: label)
                    if  let jsonRepresentable = value as? JSONRepresentable,
                        let maybeJson = try? jsonRepresentable.asJson(),
                        let json = maybeJson,
                        let mapValue = serializeFields(object: json, skipFields: innerSkipFields) {
                        fields[label] = .mapValue(MapValue(fields: mapValue))
                    } else {
                        print("WARN - Unable to serialize property '\(label)' with value '\(value)' into FirestoreDocument.Value")
                    }
                }
            } else {
                print("WARN - Unable to serialize property '\(label)' with value '\(value)' into FirestoreDocument.Value")
            }
        }

        return fields
    }

    static func canBeCastToSimpleValue(_ value: Any) -> Bool {
        return  value as? Bool != nil   ||
                value as? Int != nil    ||
                value as? Double != nil ||
                value as? Date != nil   ||
                value as? String != nil
    }

    static func serializeSimpleValue(_ value: Any, skipFields: Set<String> = Set()) -> FirestoreDocument.Value? {
        if let booleanValue = value as? Bool {
            return .booleanValue(booleanValue)
        } else if let integerValue = value as? Int {
            return .integerValue(String(integerValue))
        } else if let doubleValue = value as? Double {
            return .doubleValue(doubleValue)
        } else if let dateValue = value as? Date {
            let formatter = DateFormatter()
            formatter.dateFormat = FirestoreDocument.dateFormat
            return .timestampValue(formatter.string(from: dateValue))
        } else if let dataValue = value as? Data {
            return .bytesValue(dataValue.base64EncodedString())
        } else if let stringValue = value as? String {
            return .stringValue(stringValue)
        } else if let mapValueFields = serializeFields(object: value, skipFields: skipFields) {
            return .mapValue(.init(fields: mapValueFields))
        } else {
            return .none
        }
    }

    var unwrapped: [String : Any] {
        var unwrappedFields = fields.mapValues { $0.unwrapped }
        let formatter = DateFormatter()
        formatter.dateFormat = FirestoreDocument.dateFormat
        unwrappedFields["createTime"] = formatter.string(from: createTime)
        unwrappedFields["updateTime"] = formatter.string(from: updateTime)
        return unwrappedFields
    }

    var flattenFieldKeys: [String] {
        return fields.flatMap { pair -> [String] in
            if case .mapValue(let map) = pair.value {
                return map.flattenFieldKeys(prefix: pair.key)
            } else {
                return [pair.key]
            }
        }
    }
}

public extension FirestoreDocument.Value {

    var unwrapped: Any {
        switch self {
        case .nullValue:
            return NSNull()
        case .booleanValue(let value):
            return value
        case .integerValue(let value):
            // Firebase returns integer values as String. Don't ask me why.
            return Int(value) ?? value
        case .doubleValue(let value):
            return value
        case .timestampValue(let value):
            // Unwrapped should be used for JSON deserialization using JSONDecoder.
            // Date time is serialized as Double by JSONCoder. That's why the
            // attempt to convert to Date to later get the interval value.
            //
            // First we use the Firestore declared time format. If that fails
            // it might be because firebase omits the miliseconds with dates
            // that have the time set to 00:00:00.
            let formatter = DateFormatter()
            formatter.dateFormat = FirestoreDocument.dateFormat
            if let date = formatter.date(from: value) {
                return date.timeIntervalSinceReferenceDate
            } else {
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                if let date = formatter.date(from: value) {
                    return date.timeIntervalSinceReferenceDate
                } else {
                    if FirestoreDocument.printSerializationDebugLog {
                        print("WARN - FirestoreDocument.unwrapped - Unable to unwrap timestamp value '\(value)'")
                    }
                    return value
                }
            }
        case .stringValue(let value):
            return value
        case .bytesValue(let value):
            return Data(base64Encoded: value) ?? Data()
        case .referenceValue(let value):
            return value
        case .geoPointValue(let value):
            return ["latitude" : value.latitude, "longitude": value.longitude]
        case .arrayValue(let value):
            return value.values?.map { $0.unwrapped } ?? []
        case .mapValue(let value):
            return value.fields?.mapValues { $0.unwrapped } ?? [:]
        }
    }

}

fileprivate extension FirestoreDocument {

    static let dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

    static func decodeDate(forKey key: CodingKeys, container: KeyedDecodingContainer<CodingKeys>) throws -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        let dateString = try container.decode(String.self, forKey: key)
        guard let date = formatter.date(from: dateString) else {
            throw DecodeError.invalidDate(date: dateString, format: formatter.dateFormat, key: key)
        }
        return date
    }

    static func filterSkipFields(_ skipFields: Set<String>, property: String) -> Set<String> {
        return Set(skipFields.filter { !$0.starts(with: "\(property).") }
            .map { String($0.dropFirst("\(property).".count)) })
    }

    enum CodingKeys: CodingKey {

        case name
        case fields
        case createTime
        case updateTime

    }

    enum DecodeError: Error {

        case invalidDate(date: String, format: String, key: CodingKeys)
        case unsupportedValueType

    }
}
