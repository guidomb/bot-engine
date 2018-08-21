//
//  ObjectRepository.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/20/18.
//

import Foundation
import ReactiveSwift
import Result

public protocol Identifiable {
    
    var id: Identifier<Self>? { get set }
    
}

public protocol Persistable: Identifiable, Codable {
    
    static var collectionName: String { get }
    
    var isPersisted: Bool { get }
    
}

public protocol QueryableByProperty {
    
    static var queryableProperties: [String : AnyKeyPath] { get }
    
}

extension Persistable {
    
    public static var collectionName: String {
        let name = String(reflecting: Self.self)
            .lowercased()
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "<", with: "_")
            .replacingOccurrences(of: ">", with: "_")
        return name.last == "_" ? String(name.dropLast()) : name
    }
    
    public var isPersisted: Bool {
        return id != nil
    }
    
}

public protocol ObjectRepository {
    
    func save<ObjectType: Persistable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError>
    
    func fetch<ObjectType: Persistable>(byId id: Identifier<ObjectType>) -> SignalProducer<ObjectType, AnyError>
    
    func fetchAll<ObjectType: Persistable>(_ objectType: ObjectType.Type) -> SignalProducer<[ObjectType], AnyError>

    func fetchAll<ObjectType: Persistable & QueryableByProperty, Value: Equatable>(_ objectType: ObjectType.Type, where: KeyPatchMatcher<ObjectType, Value>) -> SignalProducer<[ObjectType], AnyError>
    
    func delete<ObjectType: Persistable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError>
    
}

extension ObjectRepository {
    
    
    public func fetchFirst<ObjectType: Persistable & QueryableByProperty, Value: Equatable>(_ objectType: ObjectType.Type, where keyPathMatcher: KeyPatchMatcher<ObjectType, Value>) -> SignalProducer<ObjectType?, AnyError> {
        return fetchAll(objectType, where: keyPathMatcher).map { $0.first }
    }
    
}

public struct KeyPatchMatcher<Root, Value> {
    
    public let keyPath: KeyPath<Root, Value>
    public let value: Value
    
    init(keyPath: KeyPath<Root, Value>, value: Value) {
        self.keyPath = keyPath
        self.value = value
    }
    
}

public func ==<Root, Value>(lhs: KeyPath<Root, Value>, rhs: Value) -> KeyPatchMatcher<Root, Value> {
    return .init(keyPath: lhs, value: rhs)
}

public final class InMemoryObjectRepository: ObjectRepository {

    enum Error: Swift.Error {
        
        case objectRepositoryDoesNotExist
        case objectIsNotPersisted
        case objectNotFound
        
    }
    
    private var repository: [String: [String : Any]] = [:]
    
    public func save<ObjectType: Persistable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
        let key = String(describing: ObjectType.self)
        var objectRepository = repository[key] ?? [:]
        if let id = object.id {
            objectRepository[id.description] = object
            repository[key] = objectRepository
            return SignalProducer(value: object)
        } else {
            let id = Identifier<ObjectType>(identifier: UUID().uuidString)
            var savedObject = object
            savedObject.id = id
            objectRepository[id.description] = savedObject
            repository[key] = objectRepository
            return SignalProducer(value: savedObject)
        }
    }
    
    public func fetch<ObjectType: Persistable>(byId id: Identifier<ObjectType>) -> SignalProducer<ObjectType, AnyError> {
        let key = String(describing: ObjectType.self)
        if let object = repository[key].flatMap({ $0[id.description] as? ObjectType }) {
            return SignalProducer(value: object)
        } else {
            return SignalProducer(error: AnyError(Error.objectNotFound))
        }
    }
    
    public func fetchAll<ObjectType: Persistable>(_ objectType: ObjectType.Type) -> SignalProducer<[ObjectType], AnyError> {
        let key = String(describing: ObjectType.self)
        guard let values = repository[key]?.values else {
            return SignalProducer(value: [])
        }
        var objects: [ObjectType] = []
        for value in values {
            if let object = value as? ObjectType {
                objects.append(object)
            }
        }
        return SignalProducer(value: objects)
    }
    
    public func fetchAll<ObjectType: Persistable & QueryableByProperty, Value: Equatable>(_ objectType: ObjectType.Type, where keyPatchMatcher: KeyPatchMatcher<ObjectType, Value>) -> SignalProducer<[ObjectType], AnyError> {
        return fetchAll(objectType).map { objects in
            objects.filter { $0[keyPath: keyPatchMatcher.keyPath] == keyPatchMatcher.value }
        }
    }

    
    public func delete<ObjectType: Persistable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
        let key = String(describing: ObjectType.self)
        guard let id = object.id?.description else {
            return SignalProducer(error: AnyError(Error.objectIsNotPersisted))
        }
        guard var objectRepository = repository[key] else {
            return SignalProducer(error: AnyError(Error.objectRepositoryDoesNotExist))
        }
        guard objectRepository[id] != nil else {
            return SignalProducer(error: AnyError(Error.objectIsNotPersisted))
        }
        objectRepository.removeValue(forKey: id)
        repository[key] = objectRepository
        return SignalProducer(value: object)
    }
    
}

public struct Identifier<IdentifiableType>: CustomStringConvertible, Codable {
    
    public var description: String {
        return identifier
    }
    
    private let identifier: String
    
    public init(identifier: String) {
        self.identifier = identifier
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        self.init(identifier: identifier)
    }
    
}
