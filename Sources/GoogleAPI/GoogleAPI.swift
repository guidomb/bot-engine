//
//  GoogleAPIResource.swift
//  AuthPackageDescription
//
//  Created by Guido Marucci Blas on 3/31/18.
//

import Foundation
import ReactiveSwift
import Result

public protocol GoogleAPITokenProvider {
    
    func fetchToken() -> SignalProducer<GoogleAPI.Token, AnyError>
    
}

public protocol GoogleAPIResourceExecutor {

    func execute<T: Decodable>(resource: GoogleAPI.Resource<T>,
                               session: URLSession) -> GoogleAPI.ResourceProducer<T>
    
    func execute<T>(resource: GoogleAPI.Resource<T>,
        session: URLSession, deserializer: @escaping GoogleAPI.ResourceDeserializer<T>) -> GoogleAPI.ResourceProducer<T>
    
}

extension GoogleAPIResourceExecutor {
    
    public func execute<T: Decodable>(resource: GoogleAPI.Resource<T>, session: URLSession = .shared)
        -> GoogleAPI.ResourceProducer<T> {
        return execute(resource: resource, session: session) { data, _ in
            Result { try JSONDecoder().decode(T.self, from: data) }
        }
    }
    
    public func execute(resource: GoogleAPI.Resource<Void>, session: URLSession = .shared)
        -> GoogleAPI.ResourceProducer<Void> {
        return execute(resource: resource, session: session) { data, _ in
            Result.success(())
        }
    }
}

public protocol Paginable {
    
    var nextPageToken: String? { get }
    
}

public protocol PaginableFetcherOptions {
    
    var pageToken: String? { get set }
    
}

public final class GoogleAPI: GoogleAPIResourceExecutor {
    
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
        public let expiresIn: Int
        public let creationTime: Date
        
        public init(type: String, value: String, expiresIn: Int, creationTime: Date = Date()) {
            self.type = type
            self.value = value
            self.expiresIn = expiresIn
            self.creationTime = creationTime
        }
        
        public func isExpired() -> Bool {
            let expirationDate = creationTime.addingTimeInterval(TimeInterval(expiresIn))
            return Date() >= expirationDate
        }
        
        fileprivate var authorizationHeaderValue: String {
            return "\(type) \(value)"
        }
        
    }
    
    public enum RequestError: Error, CustomStringConvertible {
        
        case fetchTokenFailure(Error)
        case missingContentTypeHeader
        case unexpectedContentType(String)
        case unexpectedErrorContentType(contentType: String, statusCode: Int)
        case errorDataDeserializationError(error: Error, statusCode: Int)
        case unexpectedResponseStatusCode(Int)
        case unexpectedResponseObjectType(URLResponse)
        case deserializationError(Error)
        case networkingError(Error)
        case resourceError(ResourceError)
        case resourceErrors([ResourceError])
        case htmlErrorResponse(Data)
        
        public var localizedDescription: String {
            return description
        }
        
        public var description: String {
            switch self {
            case .fetchTokenFailure(let error):
                return "There was an error while fetching access token: \(error)"
            case .missingContentTypeHeader:
                return "Missing 'Content-Type' HTTP header"
            case .unexpectedContentType(let contentType):
                return "Unexpected value in 'Content-Type' HTTP header '\(contentType)'"
            case .unexpectedErrorContentType(let contentType, let statusCode):
                return "Unexpected value in 'Content-Type' HTTP header '\(contentType)' for error response with status code '\(statusCode)'"
            case .errorDataDeserializationError(let error, let statusCode):
                return "Deserialization error while deserialinzing error response with status code '\(statusCode)': \(error.localizedDescription)"
            case .unexpectedResponseStatusCode(let statusCode):
                return "Unexpected response status code '\(statusCode)'"
            case .deserializationError(let error):
                return "Deserialization error \(error)"
            case .networkingError(let error):
                return "Networking error \(error)"
            case .resourceError(let error):
                return "Resource error '\(error)'"
            case .resourceErrors(let errors):
                return "Resource error '\(errors)'"
            case .unexpectedResponseObjectType(let response):
                return "Unexpected response object type: \(response)"
            case .htmlErrorResponse(let error):
                return String(data: error, encoding: .utf8) ?? ""
            }
        }
        
    }
    
    public struct ResourceError: Error, Decodable, CustomStringConvertible {
        
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
        
        public var localizedDescription: String {
            return error.message
        }
        
        public var description: String {
            return error.message
        }
        
        public init(code: UInt, message: String, status: String? = .none, errors: [ExtendedError]? = .none) {
            self.error = ErrorInfo(code: code, message: message, status: status, errors: errors)
        }
    }
    
    public var printDebugCurlCommand = false
    public var printRequest = false
    public var responseDumpDirectoryPath: String? = .none
    
    private let tokenProvider: GoogleAPITokenProvider
    
    public init(tokenProvider: GoogleAPITokenProvider) {
        self.tokenProvider = tokenProvider
    }
    
    public func execute<T>(
        resource: GoogleAPI.Resource<T>,
        session: URLSession = .shared,
        deserializer: @escaping ResourceDeserializer<T>) -> ResourceProducer<T> {

        func executeResource(token: (GoogleAPI.Token)) -> ResourceProducer<T> {
            return execute(resource: resource, token: token, deserializer: deserializer)
        }
        
        return tokenProvider.fetchToken()
            .mapError(RequestError.fetchTokenFailure)
            .flatMap(.concat, executeResource)
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
    
    func execute(with executor: GoogleAPIResourceExecutor) -> GoogleAPI.ResourceProducer<T> {
        return executor.execute(resource: self)
    }
    
}

public extension GoogleAPI.Resource where T == Void {
    
    func execute(with executor: GoogleAPIResourceExecutor) -> GoogleAPI.ResourceProducer<Void> {
        return executor.execute(resource: self)
    }
    
}

public func fetchAllPages<Element, Options: PaginableFetcherOptions, PaginableType: Paginable>(
    options: Options,
    using fetcher: @escaping (Options) -> GoogleAPI.Resource<PaginableType>,
    executor: GoogleAPIResourceExecutor,
    extract keyPath: KeyPath<PaginableType, [Element]?>) -> GoogleAPI.ResourceProducer<[Element]> where PaginableType: Decodable {
    let resourceProducer: (Options) -> GoogleAPI.ResourceProducer<PaginableType> = {
        let resource: GoogleAPI.Resource<PaginableType> = fetcher($0)
        return executor.execute(resource: resource)
    }
    return fetchAllPages(options: options, using: resourceProducer, extract: keyPath)
}

public func fetchAllPages<Element, Options: PaginableFetcherOptions, PaginableType: Paginable>(
    options: Options,
    using fetcher: @escaping (Options) -> GoogleAPI.ResourceProducer<PaginableType>,
    extract keyPath: KeyPath<PaginableType, [Element]?>) -> GoogleAPI.ResourceProducer<[Element]> {
    var _options = options
    _options.pageToken = .none
    return fetcher(_options).flatMap(.concat) { (paginable: PaginableType) -> SignalProducer<[Element], GoogleAPI.RequestError> in
        guard let elements = paginable[keyPath: keyPath] else {
            return .init(value: [])
        }
        if let nextPageToken = paginable.nextPageToken {
            _options.pageToken = nextPageToken
            return fetcher(_options).map { elements + ($0[keyPath: keyPath] ?? [])
}
        } else {
            return .init(value: elements)
        }
    }
}

fileprivate extension GoogleAPI {
    
    func execute<T>(
        resource: GoogleAPI.Resource<T>,
        token: GoogleAPI.Token,
        session: URLSession = .shared,
        deserializer: @escaping ResourceDeserializer<T>) -> ResourceProducer<T> {
    
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
        
        if contentType.starts(with: "text/html") {
            return ResourceProducer(error: .htmlErrorResponse(data))
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
        } catch {
            do {
                let errors = try JSONDecoder().decode([ResourceError].self, from: data)
                return ResourceProducer(error: .resourceErrors(errors))
            } catch let error {
                return ResourceProducer(error: .errorDataDeserializationError(
                    error: error,
                    statusCode: response.statusCode)
                )
            }
        }
    }
    
}
