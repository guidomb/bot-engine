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
    
    public enum Property {
        
        case string(String)
        case integer(Int)
        case double(Double)
        case bool(Bool)
        
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

extension UserConfiguration.Property: Codable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else {
            self = .double(try container.decode(Double.self))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
    
}
