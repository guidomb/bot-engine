//
//  ObjectRepository.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/20/18.
//

import Foundation
import ReactiveSwift
import Result

protocol Identifiable {
    
    var id: Identifier<Self>? { get set }
    
}

protocol Persistable: Identifiable, Codable {
    
    static var collectionName: String { get }
    
    var isPersisted: Bool { get }
    
}

extension Persistable {
    
    static var collectionName: String {
        let name = String(reflecting: Self.self)
            .lowercased()
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: "<", with: "_")
            .replacingOccurrences(of: ">", with: "_")
        return name.last == "_" ? String(name.dropLast()) : name
    }
    
    var isPersisted: Bool {
        return id != nil
    }
    
}

protocol ObjectRepository {
    
    func save<ObjectType: Persistable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError>
    
    func fetch<ObjectType: Persistable>(byId id: Identifier<ObjectType>) -> SignalProducer<ObjectType, AnyError>
    
    func fetchAll<ObjectType: Persistable>(_ objectType: ObjectType.Type) -> SignalProducer<[ObjectType], AnyError>
    
    func delete<ObjectType: Persistable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError>
    
}

final class InMemoryObjectRepository: ObjectRepository {
    
    enum Error: Swift.Error {
        
        case objectRepositoryDoesNotExist
        case objectIsNotPersisted
        case objectNotFound
        
    }
    
    private var repository: [String: [String : Any]] = [:]
    
    func save<ObjectType: Persistable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
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
    
    func fetch<ObjectType: Persistable>(byId id: Identifier<ObjectType>) -> SignalProducer<ObjectType, AnyError> {
        let key = String(describing: ObjectType.self)
        if let object = repository[key].flatMap({ $0[id.description] as? ObjectType }) {
            return SignalProducer(value: object)
        } else {
            return SignalProducer(error: AnyError(Error.objectNotFound))
        }
    }
    
    func fetchAll<ObjectType: Persistable>(_ objectType: ObjectType.Type) -> SignalProducer<[ObjectType], AnyError> {
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
    
    func delete<ObjectType: Persistable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
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

struct Identifier<IdentifiableType>: CustomStringConvertible, Codable {
    
    var description: String {
        return identifier
    }
    
    private let identifier: String
    
    init(identifier: String) {
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
