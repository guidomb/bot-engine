//
//  UserConfigurationService.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 8/12/18.
//

import Foundation
import ReactiveSwift
import Result

public struct UserConfiguration: Persistable {
    
    public enum Property: AutoCodable {
        
        case string(stringValue: String)
        case integer(integerValue: Int)
        case double(doubleValue: Double)
        case bool(boolValue: Bool)
        
    }
    
    public var id: Identifier<UserConfiguration>?
    public let engineUserId: String
    public var intentLanguage: Intent.Language?
    public var properties: [String : Property]
    
    public init(engineUserId: BotEngine.UserId) {
        self.engineUserId = engineUserId.value
        self.properties = [:]
    }
    
}

extension UserConfiguration: QueryableByProperty {
    
    public static var queryableProperties: [String : AnyKeyPath] {
        return [ "engineUserId" : \UserConfiguration.engineUserId ]
    }
    
}

public struct UserConfigurationService {
    
    private let repository: ObjectRepository
    
    public init(repository: ObjectRepository) {
        self.repository = repository
    }
    
    public func fetchUserConfiguration(for userId: BotEngine.UserId) -> SignalProducer<UserConfiguration, AnyError> {
        return repository.fetchFirst(UserConfiguration.self, where: \.engineUserId == userId.value)
            .map { $0 ?? UserConfiguration(engineUserId: userId) }
    }
    
    public func saveUserConfiguration(_ configuration: UserConfiguration) -> SignalProducer<UserConfiguration, AnyError> {
        return repository.save(object: configuration)
    }
    
}
