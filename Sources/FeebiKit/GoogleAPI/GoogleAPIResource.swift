//
//  GoogleAPIResource.swift
//  AuthPackageDescription
//
//  Created by Guido Marucci Blas on 3/31/18.
//

import Foundation
import ReactiveSwift
import Result

public struct GoogleAPIResource {
    
    static let shared = GoogleAPIResource(baseURL: "https://sheets.googleapis.com", version: "v4")
    
    public typealias ResourceProducer<T> = SignalProducer<T, RequestError>
    public typealias ResourceDeserializer<T> = (Data, HTTPURLResponse) -> Result<T, AnyError>
    
    public struct Token {
        
        public let type: String
        public let value: String
        
        public init(type: String, value: String) {
            self.type = type
            self.value = value
        }
        
        fileprivate var authorizationHeaderValue: String {
            return "\(type) \(value)"
        }
        
    }
    
    public enum RequestError: Error {
        
        case missingContentTypeHeader
        case unexpectedContentType(String)
        case unexpectedErrorContentType(contentType: String, statusCode: Int)
        case errorDataDeserializationError(error: Error, statusCode: Int)
        case unexpectedResponseStatusCode(Int)
        case unexpectedResponseObjectType(URLResponse)
        case deserializationError(Error)
        case networkingError(Error)
        case resourceError(ResourceError)
        
    }
    
    public struct ResourceError: Error, Decodable {
        
        public struct ErrorInfo: Decodable {
            
            let code: UInt
            let message: String
            let status: String
            
        }
        
        public let error: ErrorInfo
        
    }
    
    private let baseURL: String
    private let version: String
    
    init(baseURL: String, version: String) {
        self.baseURL = baseURL
        self.version = version
    }
    
    func absoluteUrl(for resource: GoogleAPIResourceEndpoint) -> URL {
        return URL(string: "\(baseURL)/\(version)/\(resource.name)/\(resource.urlPath)")!
    }
    
    func urlRequest(for resource: GoogleAPIResourceEndpoint, token: GoogleAPIResource.Token) -> URLRequest {
        var request = URLRequest(url: absoluteUrl(for: resource))
        request.httpMethod = resource.httpMethod
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        return request
    }
    
    func execute<T: Decodable>(resource: GoogleAPIResourceEndpoint, token: GoogleAPIResource.Token,
                    session: URLSession = .shared) -> ResourceProducer<T> {
        return execute(resource: resource, token: token, session: session) { data, _ in
            Result { try JSONDecoder().decode(T.self, from: data) }
        }
    }
    
    func execute<T>(resource: GoogleAPIResourceEndpoint, token: GoogleAPIResource.Token,
                    session: URLSession = .shared, deserializer: @escaping ResourceDeserializer<T>) -> ResourceProducer<T> {
        let request = urlRequest(for: resource, token: token)
        return session.reactive.data(with: request)
            .mapError { .networkingError($0.error) }
            .flatMap(.concat) { data, response -> ResourceProducer<T> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return ResourceProducer(error: .unexpectedResponseObjectType(response))
                }
                
                switch httpResponse.statusCode {
                case (200 ..< 300):
                    return self.handleSuccessfulResponse(httpResponse, data: data, deserializer: deserializer)
                    
                case (400 ..< 600):
                    return self.handleFailureResponse(httpResponse, data: data)
                    
                default:
                    return ResourceProducer(error: .unexpectedResponseStatusCode(httpResponse.statusCode))
                }
        }
    }
}

protocol GoogleAPIResourceEndpoint {
    
    var name: String { get }
    var urlPath: String { get }
    var httpMethod: String { get }
    
}

fileprivate extension GoogleAPIResource {
    
    func handleSuccessfulResponse<T>(_ response: HTTPURLResponse, data: Data,
                                     deserializer: ResourceDeserializer<T>) -> ResourceProducer<T> {
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            return ResourceProducer(error: .missingContentTypeHeader)
        }
        // Content-Type header may include string encoding information. e.g: "application/json; charset=UTF-8"
        guard contentType.starts(with: "application/json") else {
            return ResourceProducer(error: .unexpectedContentType(contentType))
        }
        
        let result = deserializer(data, response).mapError {
            RequestError.deserializationError($0.error)
        }
        return ResourceProducer(result: result)
    }
    
    func handleFailureResponse<T>(_ response: HTTPURLResponse, data: Data) -> ResourceProducer<T> {
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else {
            return ResourceProducer(error: .missingContentTypeHeader)
        }
        // Content-Type header may include string encoding information. e.g: "application/json; charset=UTF-8"
        guard contentType.starts(with: "application/json") else {
            return ResourceProducer(error: .unexpectedErrorContentType(
                contentType: contentType, statusCode:
                response.statusCode)
            )
        }
        
        do {
            let error = try JSONDecoder().decode(ResourceError.self, from: data)
            return ResourceProducer(error: .resourceError(error))
        } catch let error {
            return ResourceProducer(error: .errorDataDeserializationError(
                error: error,
                statusCode: response.statusCode)
            )
        }
    }
    
}
