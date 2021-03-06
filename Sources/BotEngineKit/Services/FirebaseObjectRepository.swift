//
//  FirebaseObjectRepository.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/20/18.
//

import Foundation
import GoogleAPI
import ReactiveSwift
import Result

public struct FirebaseObjectRepository: ObjectRepository {
    
    enum Error: Swift.Error {
    
        case cannotSerializeDocument
        case requestError(GoogleAPI.RequestError)
        case deserializationError(Swift.Error)
        case objectIsNotPersisted
        case cannotSerializeFieldValue(Any)
        
        var asAnyError: AnyError {
            return AnyError(self)
        }
        
        func asFailedProducer<ObjectType: Persistable>() -> SignalProducer<ObjectType, AnyError> {
            return SignalProducer(error: self.asAnyError)
        }
        
    }
    
    private let executor: GoogleAPIResourceExecutor
    private let firestore: GoogleAPI.Firestore
    
    public init(executor: GoogleAPIResourceExecutor, projectId: String, databaseId: String) {
        self.executor = executor
        self.firestore = GoogleAPI.firestore(projectId: projectId, databaseId: databaseId)
    }
    
    public func save<ObjectType: Persistable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
        if object.id != nil {
            return updateDocument(for: object)
        } else {
            return createDocument(for: object)
        }
    }
    
    public func fetch<ObjectType: Persistable>(byId id: Identifier<ObjectType>) -> SignalProducer<ObjectType, AnyError> {
        return firestore.documents
            .get(documentName: "\(ObjectType.collectionName)/\(id.description)")
            .execute(with: executor)
            .mapError { Error.requestError($0).asAnyError }
            .flatMap(.concat, deserialize(as: ObjectType.self))
    }
    
    public func fetchAll<ObjectType: Persistable>(_ objectType: ObjectType.Type) -> SignalProducer<[ObjectType], AnyError> {
        let fetcher = { self.firestore.documents.list(collectionId: ObjectType.collectionName, options: $0) }
        return fetchAllPages(
            options: FirestoreListDocumentsOptions(),
            using: fetcher,
            executor: executor,
            extract: \FirestoreDocumentList.documents
        )
        .mapError { Error.requestError($0).asAnyError }
        .flatMap(.concat, deserialize(as: ObjectType.self))
    }
    
    public func fetchAll<ObjectType: Persistable & QueryableByProperty, Value: Equatable>(
        _ objectType: ObjectType.Type,
        where keyPatchMatcher: KeyPatchMatcher<ObjectType, Value>) -> SignalProducer<[ObjectType], AnyError> {
        
        let keyPath = keyPatchMatcher.keyPath as AnyKeyPath
        guard let queryableProperty = ObjectType.queryableProperties.first(where: { $0.value == keyPath }) else {
            return .init(value: [])
        }
        guard let fieldValue = try? serializeValue(keyPatchMatcher.value) else {
            return SignalProducer(error: Error.cannotSerializeFieldValue(keyPatchMatcher.value).asAnyError)
        }
        
        var query = StructuredQuery(from: ObjectType.collectionName)
        query.where = .field(.init(fieldPath: queryableProperty.key, op: .equal, value: fieldValue))
        return firestore.documents
            .runQuery(query: query)
            .execute(with: executor)
            .mapError { Error.requestError($0).asAnyError }
            .flatMap(.concat) { response -> SignalProducer<[ObjectType], AnyError> in
                guard !response.isEmpty else {
                    return .init(value: [])
                }
                
                var result: [ObjectType] = Array()
                result.reserveCapacity(response.count)
                for document in response.compactMap({ $0.document }) {
                    do {
                        result.append(try document.deserialize())
                    } catch let error {
                        return .init(error: .init(error))
                    }
                }
                
                return .init(value: result)
            }
    }
    
    public func delete<ObjectType: Persistable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
        guard let id = object.id?.description else {
            return Error.objectIsNotPersisted.asFailedProducer()
        }
        return firestore.documents
            .delete(documentName: "\(ObjectType.collectionName)/\(id)")
            .execute(with: executor)
            .mapError { Error.requestError($0).asAnyError }
            .map { _ in object }
    }
    
}

public extension FirestoreDocument {
    
    var id: String? {
        return name?.split(separator: "/").last.map(String.init)
    }
    
    func deserialize<ObjectType: Persistable>() throws -> ObjectType {
        return try FirestoreDecoder().decode(ObjectType.self, from: self)
    }
    
}

fileprivate extension FirebaseObjectRepository {
    
    func createDocument<ObjectType: Persistable>(for object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
        guard let document = try? serialize(object) else {
            return Error.cannotSerializeDocument.asFailedProducer()
        }
        
        // Explicit cast to FirestoreDocument is needed to avoid deserializing to ObjectType
        // when we only want to update the object's ID.
        let documentProducer: GoogleAPI.ResourceProducer<FirestoreDocument> = firestore.documents
            .createDocument(collectionId: ObjectType.collectionName, document: document)
            .execute(with: executor)
            
        return documentProducer
            .mapError { Error.requestError($0).asAnyError }
            .map(object.updateId)
    }
    
    func updateDocument<ObjectType: Persistable>(for object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
        guard let document = try? serialize(object) else {
            return Error.cannotSerializeDocument.asFailedProducer()
        }
        return firestore.documents
            .patch(document: document, updateMask: .allFieldKeys(of: document))
            .execute(with: executor)
            .mapError { Error.requestError($0).asAnyError }
            .flatMap(.concat, deserialize(as: ObjectType.self))
    }
    
    func serializeValue<T: Encodable>(_ value: T) throws -> FirestoreDocument.Value {
        return try FirestoreEncoder().encodeProperty(value)
    }
    
    func serialize<ObjectType: Persistable>(_ object: ObjectType) throws -> FirestoreDocument {
        return try FirestoreEncoder().encode(object, name: ObjectType.collectionName, skipFields: ["id"])
    }
    
    func deserialize<ObjectType: Persistable>(as objectType: ObjectType.Type) -> ([FirestoreDocument]) -> SignalProducer<[ObjectType], AnyError> {
        return { documents in
            do {
                return SignalProducer(value: try documents.map { try $0.deserialize() })
            } catch let error {
                return SignalProducer(error: Error.deserializationError(error).asAnyError)
            }
        }
    }
    
    func deserialize<ObjectType: Persistable>(as objectType: ObjectType.Type) -> (FirestoreDocument) -> SignalProducer<ObjectType, AnyError> {
        return { document in
            do {
                return SignalProducer(value: try document.deserialize())
            } catch let error {
                return SignalProducer(error: Error.deserializationError(error).asAnyError)
            }
        }
    }
    
}

fileprivate extension Persistable {
    
    func updateId(using document: FirestoreDocument) -> Self {
        var object = self
        object.id = document.id.map(Identifier.init)
        return object
    }
    
}

fileprivate extension FirestoreDocumentList {
    
    func concat(with list: FirestoreDocumentList) -> FirestoreDocumentList {
        var newDocuments = self.documents ?? []
        if let documents = list.documents {
            newDocuments.append(contentsOf: documents)            
        }
        return FirestoreDocumentList(documents: newDocuments, nextPageToken: list.nextPageToken)
    }
    
}
