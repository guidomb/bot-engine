//
//  GoogleAPIResource.swift
//  AuthPackageDescription
//
//  Created by Guido Marucci Blas on 3/31/18.
//

import Foundation
import ReactiveSwift
import Result

public protocol GoogleAPIResourceExecutor {

    func execute<T: Decodable>(resource: GoogleAPI.Resource<T>, token: GoogleAPI.Token,
                               session: URLSession) -> GoogleAPI.ResourceProducer<T>
    
    func execute<T>(resource: GoogleAPI.Resource<T>, token: GoogleAPI.Token,
        session: URLSession, deserializer: @escaping GoogleAPI.ResourceDeserializer<T>) -> GoogleAPI.ResourceProducer<T>
    
}

extension GoogleAPIResourceExecutor {
    
    public func execute<T: Decodable>(resource: GoogleAPI.Resource<T>, token: GoogleAPI.Token,
                               session: URLSession = .shared) -> GoogleAPI.ResourceProducer<T> {
        return execute(resource: resource, token: token, session: session) { data, _ in
            Result { try JSONDecoder().decode(T.self, from: data) }
        }
    }
    
    public func execute(resource: GoogleAPI.Resource<Void>, token: GoogleAPI.Token,
                               session: URLSession = .shared) -> GoogleAPI.ResourceProducer<Void> {
        return execute(resource: resource, token: token, session: session) { data, _ in
            Result.success(())
        }
    }
}

public final class GoogleAPI: GoogleAPIResourceExecutor {
    
    public static let shared = GoogleAPI()
    
    public typealias ResourceProducer<T> = SignalProducer<T, RequestError>
    public typealias ResourceDeserializer<T> = (Data, HTTPURLResponse) -> Result<T, AnyError>
    
    public enum HTTPMethod: String {
        
        case get    = "GET"
        case post   = "POST"
        case put    = "PUT"
        case patch  = "PATCH"
        case delete = "DELETE"
        
    }
    
    public struct Resource<T> {
        
        let path: String
        let queryParameters: () -> String?
        let requestBody: () ->Data?
        let method: HTTPMethod
        
        public var urlPath: String {
            if let queryString = queryParameters(), !queryString.isEmpty {
                return "\(path)?\(queryString)"
            } else {
                return path
            }
        }
        
        init(path: String = "", queryParameters: @autoclosure @escaping () -> String? = .none,
             requestBody: @autoclosure @escaping () -> Data? = .none, method: HTTPMethod = .get) {
            self.path = path
            self.queryParameters = queryParameters
            self.requestBody = requestBody
            self.method = method
        }
        
        init<T: Encodable>(path: String = "", queryParameters: @autoclosure @escaping () -> String? = .none,
             requestBody: T, method: HTTPMethod = .get) {
            self.init(
                path: path,
                queryParameters: queryParameters,
                requestBody: try? JSONEncoder().encode(requestBody),
                method: method
            )
        }
        
        init(path: String = "", queryParameters: @escaping () -> String?,
             requestBody: @autoclosure @escaping () -> Data? = .none, method: HTTPMethod = .get) {
            self.path = path
            self.queryParameters = queryParameters
            self.requestBody = requestBody
            self.method = method
        }
        
        init(path: String = "", queryParameters: QueryStringConvertible,
             requestBody: @autoclosure @escaping () -> Data? = .none, method: HTTPMethod = .get) {
            self.init(path: path, queryParameters: queryParameters.asQueryString,
                      requestBody: requestBody, method: method)
        }
        
        func with(method: HTTPMethod) -> Resource {
            return Resource(path: self.path, queryParameters: self.queryParameters, method: method)
        }
        
    }
    
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
        
        public struct ExtendedError: Decodable {
            
            public let domain: String
            public let reason: String
            public let message: String
            public let extendedHelp: String?
            public let locationType: String?
            public let location: String?
            
        }
        
        public struct ErrorInfo: Decodable {
            
            public let code: UInt
            public let message: String
            public let status: String?
            public let errors: [ExtendedError]?
            
            
        }
        
        public let error: ErrorInfo
        
        public init(code: UInt, message: String, status: String? = .none, errors: [ExtendedError]? = .none) {
            self.error = ErrorInfo(code: code, message: message, status: status, errors: errors)
        }
    }
    
    public var printDebugCurlCommand = false
    public var printRequest = false
    public var responseDumpDirectoryPath: String? = .none
    
    public func execute<T>(resource: GoogleAPI.Resource<T>, token: GoogleAPI.Token,
                    session: URLSession = .shared, deserializer: @escaping ResourceDeserializer<T>) -> ResourceProducer<T> {
        let request = urlRequest(for: resource, token: token)
        return session.reactive.data(with: request)
            .mapError { .networkingError($0.error) }
            .flatMap(.concat) { data, response -> ResourceProducer<T> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return ResourceProducer(error: .unexpectedResponseObjectType(response))
                }
                
                if let responseDumpDirectory = self.responseDumpDirectoryPath.map({ URL(fileURLWithPath: $0) }) {
                    let fileName = "\(String(describing: T.self)).\(UUID().uuidString).json"
                    let fileURL = responseDumpDirectory.appendingPathComponent(fileName)
                    do {
                        print("DEBUG - Dumping response to request '\(resource.path)' to '\(fileURL.absoluteString)'")
                        try data.write(to: fileURL)
                    } catch let error {
                        print("ERROR - Response could not be dump: \(error)")
                    }
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
            .on(starting: {
                if self.printRequest {
                    print("GoogleAPI executing request:")
                    print("\(resource.method.rawValue) '\(resource.urlPath)'")
                }
                if self.printDebugCurlCommand {
                    let headers = request.allHTTPHeaderFields?.map { "-H '\($0): \($1)'" }.joined(separator: " ") ?? ""
                    let dataOption = resource.requestBody()
                        .flatMap { String(data: $0, encoding: .utf8) }
                        .map { " -d '\($0)' " } ?? ""
                    print("\n------------------------------------------")
                    print("curl -v \(headers) -X \(resource.method.rawValue) \(dataOption)'\(request.url!.absoluteString)'")
                    print("------------------------------------------\n")
                }
            })
    }
    
    func urlRequest<T>(for resource: GoogleAPI.Resource<T>, token: GoogleAPI.Token) -> URLRequest {
        var request = URLRequest(url: URL(string: resource.urlPath)!)
        request.httpMethod = resource.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token.authorizationHeaderValue, forHTTPHeaderField: "Authorization")
        if let requestBody = resource.requestBody() {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = requestBody
        }
        return request
    }
}

public extension GoogleAPI.Resource where T: Decodable {
    
    func execute(using token: GoogleAPI.Token,
                 with executor: GoogleAPIResourceExecutor = GoogleAPI.shared)  -> GoogleAPI.ResourceProducer<T> {
        return executor.execute(resource: self, token: token)
    }
    
}

public extension GoogleAPI.Resource where T == Void {
    
    func execute(using token: GoogleAPI.Token,
                 with executor: GoogleAPIResourceExecutor = GoogleAPI.shared)  -> GoogleAPI.ResourceProducer<Void> {
        return executor.execute(resource: self, token: token)
    }
    
}

fileprivate extension GoogleAPI {
    
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
