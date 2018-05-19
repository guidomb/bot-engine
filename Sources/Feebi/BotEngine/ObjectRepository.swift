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

protocol ObjectRepository {
    
    func save<ObjectType: Identifiable & Codable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError>
    
    func fetch<ObjectType: Identifiable & Codable>(byId id: Identifier<ObjectType>) -> SignalProducer<ObjectType?, AnyError>
    
    func fetchAll<ObjectType: Identifiable & Codable>(_ objectType: ObjectType.Type) -> SignalProducer<[ObjectType], AnyError>
    
    func delete<ObjectType: Identifiable & Codable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError>
    
}

final class InMemoryObjectRepository: ObjectRepository {
    
    enum Error: Swift.Error {
        
        case objectRepositoryDoesNotExist
        case objectIsNotPersisted
        
    }
    
    private var repository: [String: [String : Any]] = [:]
    
    func save<ObjectType: Identifiable & Codable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
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
    
    func fetch<ObjectType: Identifiable & Codable>(byId id: Identifier<ObjectType>) -> SignalProducer<ObjectType?, AnyError> {
        let key = String(describing: ObjectType.self)
        return SignalProducer(value: repository[key].flatMap { $0[id.description] as? ObjectType })
    }
    
    func fetchAll<ObjectType: Identifiable & Codable>(_ objectType: ObjectType.Type) -> SignalProducer<[ObjectType], AnyError> {
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
    
    func delete<ObjectType: Identifiable & Codable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
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
