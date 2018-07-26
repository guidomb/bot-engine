//
//  MailChimp.swift
//  WoloxKit
//
//  Created by Guido Marucci Blas on 7/14/18.
//

import Foundation
import ReactiveSwift

public struct MailChimp {
    
    public typealias ResourceProducer<ResourceType> = SignalProducer<ResourceType, ResourceError>

    public enum ResourceError: Error, CustomStringConvertible {
        
        case serializationError(Error)
        case deserializationError(Error)
        case requestError(Error)
        case serviceError(ServiceError)
        
        public var description: String {
            switch self {
            case .serializationError(let error):
                return "Serialization error: \(error)"
            case .deserializationError(let error):
                return "Deserialization error: \(error)"
            case .requestError(let error):
                return "Request error: \(error)"
            case .serviceError(let error):
                return "Service error: \(error)"
                
            }
        }
        
        public var localizedDescription: String {
            return description
        }
        
    }
    
    public struct ServiceError: Error, Codable, CustomStringConvertible {
        
        let type: String
        let title: String
        let status: Int
        let detail: String
        let instance: String
        
        public var description: String {
            return """
            Mailchimp service \(type) error \(status). \(title)
            \t\(detail)
            \t\(instance)
            """
        }
        
        public var localizedDescription: String {
            return description
        }
        
    }
    
    public struct Lists {
        
        public enum Status: String, Codable {
            
            case subscribed
            case unsubscribed
            
        }
        
        public struct Member: Codable, AutoSnakeCaseCodingKey {
            
            public let emailAddress: String
            public let status: Status
            public let mergeFields: [String : String]
            
            public init(firstName: String, lastName: String, emailAddress: String, status: Status) {
                self.init(emailAddress: emailAddress, status: status, mergeFields: [
                    "FNAME" : firstName,
                    "LNAME" : lastName
                    ]
                )
            }
            
            public init(emailAddress: String, status: Status, mergeFields: [String : String] = [:]) {
                self.emailAddress = emailAddress
                self.status = status
                self.mergeFields = mergeFields
            }
            
        }
        
        public struct UpdateMembersResponse: Decodable, AutoSnakeCaseCodingKey {
            
            public let newMembers: [Member]
            public let updatedMembers: [Member]
            public let errors: [Int]
            public let totalCreated: Int
            public let totalUpdated: Int
            public let errorCount: Int
            
        }
        
        struct UpdateMembersRequestParameters: Encodable, AutoSnakeCaseCodingKey {
            
            let members: [MailChimp.Lists.Member]
            let updateExisting: Bool
            
        }
        
        private let client: Client
        
        fileprivate init(client: Client) {
            self.client = client
        }
        
        public func update(list listId: String, members: [Member], updateExisting: Bool = true)
            -> ResourceProducer<UpdateMembersResponse> {
            let parameters = UpdateMembersRequestParameters(members: members, updateExisting: updateExisting)
            return client.execute(method: .post, path: "lists/\(listId)", requestBody: parameters)
        }
        
    }
    
    public var lists: Lists {
        return Lists(client: client)
    }
    
    private let client: Client
    
    public init(apiKey: String) {
        self.client = Client(apiKey: apiKey)
    }
    
}

fileprivate extension MailChimp {
    
    struct Client {
        
        enum HTTPMethod: String {
            
            case get    = "GET"
            case post   = "POST"
            case put    = "PUT"
            case patch  = "PATCH"
            case delete = "DELETE"
            
        }
        
        private let session: URLSession
        private let baseUrl: URL
        private let apiKey: String
        
        init(apiKey: String, session: URLSession = .shared) {
            let splitApiKey = apiKey.split(separator: "-")
            guard splitApiKey.count == 2 else {
                fatalError("ERROR - Invalid MailChimp API key '\(apiKey)'")
            }
            let dataCenter = splitApiKey[1]
            guard let baseUrl = URL(string: "https://\(dataCenter).api.mailchimp.com/3.0") else {
                fatalError("ERROR - Invalid base URL with data center '\(dataCenter)'")
            }
            self.apiKey = apiKey
            self.session = session
            self.baseUrl = baseUrl
        }
        
        func execute<RequestBodyType: Encodable, ResourceType: Decodable>(
            method: HTTPMethod,
            path: String,
            requestBody: RequestBodyType) -> ResourceProducer<ResourceType> {
            do {
                // https://developer.mailchimp.com/documentation/mailchimp/guides/get-started-with-mailchimp-api-3/#authentication
                let token = "foo:\(apiKey)".data(using: .utf8)!.base64EncodedString()
                var request = URLRequest(url: baseUrl.appendingPathComponent(path))
                request.httpMethod = method.rawValue
                request.httpBody = try JSONEncoder().encode(requestBody)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
                return session.reactive.data(with: request)
                    .mapError(ResourceError.requestError)
                    .flatMap(.concat, asMailChimpResource)
            } catch let error {
                return .init(error: ResourceError.serializationError(error))
            }
        }
        
        func asMailChimpResource<ResourceType: Decodable>(data: Data, response: URLResponse)
            -> ResourceProducer<ResourceType> {
            guard let httpResponse = response as? HTTPURLResponse else {
                fatalError("ERROR - Unexpected URLResponse value: \(response)")
            }
            do {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    let resource = try JSONDecoder().decode(ResourceType.self, from: data)
                    return .init(value: resource)
                } else {
                    let error = try JSONDecoder().decode(ServiceError.self, from: data)
                    return .init(error: .serviceError(error))
                }
            } catch let error {
                return .init(error: ResourceError.deserializationError(error))
            }
        }
        
    }
    
}
