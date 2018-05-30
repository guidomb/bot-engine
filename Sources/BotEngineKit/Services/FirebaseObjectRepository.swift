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
        
        var asAnyError: AnyError {
            return AnyError(self)
        }
        
        func asFailedProducer<ObjectType: Persistable>() -> SignalProducer<ObjectType, AnyError> {
            return SignalProducer(error: self.asAnyError)
        }
        
    }
    
    private let token: GoogleAPI.Token
    private let firestore: GoogleAPI.Firestore
    
    public init(token: GoogleAPI.Token, projectId: String, databaseId: String) {
        self.token = token
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
            .execute(using: token)
            .mapError { Error.requestError($0).asAnyError }
            .flatMap(.concat, deserialize(as: ObjectType.self))
    }
    
    public func fetchAll<ObjectType: Persistable>(_ objectType: ObjectType.Type) -> SignalProducer<[ObjectType], AnyError> {
        return firestore.documents
            .list(collectionId: ObjectType.collectionName)
            .execute(using: token)
            .flatMap(.concat, fetchNextPage(collectionId: ObjectType.collectionName))
            .mapError { Error.requestError($0).asAnyError }
            .flatMap(.concat, deserialize(as: ObjectType.self))
    }
    
    public func delete<ObjectType: Persistable>(object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
        guard let id = object.id?.description else {
            return Error.objectIsNotPersisted.asFailedProducer()
        }
        return firestore.documents
            .delete(documentName: "\(ObjectType.collectionName)/\(id)")
            .execute(using: token)
            .mapError { Error.requestError($0).asAnyError }
            .map { _ in object }
    }
    
}

public extension FirestoreDocument {
    
    var id: String? {
        return name?.split(separator: "/").last.map(String.init)
    }
    
    func deserialize<ObjectType: Persistable>() throws -> ObjectType {
        var jsonObject = self.unwrapped
        if let id = self.id {
            jsonObject["id"] = id
        }
        if FirestoreDocument.printSerializationDebugLog {
            print("DEBUG - FirestoreDocument.deserialize - \(jsonObject)")
        }
        let data = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        return try JSONDecoder().decode(ObjectType.self, from: data)
    }
    
}

fileprivate extension FirebaseObjectRepository {
    
    func createDocument<ObjectType: Persistable>(for object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
        guard let document = FirestoreDocument.serialize(object: object, skipFields: ["id"]) else {
            return Error.cannotSerializeDocument.asFailedProducer()
        }
        return firestore.documents
            .createDocument(collectionId: ObjectType.collectionName, document: document)
            .execute(using: token)
            .mapError { Error.requestError($0).asAnyError }
            .map(object.updateId)
    }
    
    func updateDocument<ObjectType: Persistable>(for object: ObjectType) -> SignalProducer<ObjectType, AnyError> {
        guard let document = FirestoreDocument.serialize(object: object, skipFields: ["id"]) else {
            return Error.cannotSerializeDocument.asFailedProducer()
        }
        return firestore.documents
            .patch(document: document, updateMask: .allFieldKeys(of: document))
            .execute(using: token)
            .mapError { Error.requestError($0).asAnyError }
            .flatMap(.concat, deserialize(as: ObjectType.self))
    }
    
    func fetchNextPage(collectionId: String) -> (FirestoreDocumentList) -> SignalProducer<FirestoreDocumentList, GoogleAPI.RequestError> {
        return { documentsList in
            guard let nextPageToken = documentsList.nextPageToken else {
                return SignalProducer(value: documentsList)
            }
            
            var options = FirestoreListDocumentsOptions()
            options.pageToken = nextPageToken
            return self.firestore.documents
                .list(collectionId: collectionId, options: options)
                .execute(using: self.token)
                .flatMap(.concat) {
                    // TODO limit the amount of recursive requests
                    self.fetchNextPage(collectionId: collectionId)(documentsList.concat(with: $0))
                }
        }
    }
    
    func deserialize<ObjectType: Persistable>(as objectType: ObjectType.Type) -> (FirestoreDocumentList) -> SignalProducer<[ObjectType], AnyError> {
        return { documentList in
            guard let documents = documentList.documents else {
                return SignalProducer(value: [])
            }
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

// TODO autogenerate this protocol conformances
// for all persistable object and its properties recursively
extension CreateSurveyBehavior.JobMessage: JSONRepresentable {}
extension Survey.Destinatary: JSONRepresentable {}
extension SchedulableJob.Interval: JSONRepresentable {}
extension DayTime: JSONRepresentable {}
