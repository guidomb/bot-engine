//
//  HTTPServer.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 6/3/18.
//

import Foundation
import HTTP
import ReactiveSwift
import Result

extension BotEngine {
    
    public final class HTTPServer {
        
        public struct Request {
            
            private let _request: HTTPRequest
            
            var urlComponents: URLComponents? {
                return URLComponents(string: _request.urlString)
            }
            
            var url: URL {
                return _request.url
            }
            
            var formURLEncodedBody: [String : String]? {
                return _request.body.data
                    .flatMap { String(data: $0, encoding: .utf8)?.removingPercentEncoding }
                    .map(decodeFormEncodedParamaters)
            }
            
            fileprivate init(_ request: HTTPRequest) {
                self._request = request
            }
        }
        
        public struct ResponseContent: ExpressibleByStringLiteral {
            
            public let contentType: String
            
            public var content: Data? {
                return contentGenerator()
            }
            
            private let contentGenerator: () -> Data?
            
            public init(contentType: String, content: @autoclosure @escaping () -> Data?) {
                self.contentType = contentType
                self.contentGenerator = content
            }
            
            public init(stringLiteral value: String) {
                self.init(contentType: "text/plain; charset=utf-8", content: value.data(using: .utf8))
            }
            
            public init<CodableType: Codable>(_ codable: CodableType) {
                let enconder = JSONEncoder()
                self.init(contentType: "application/json", content: try? enconder.encode(codable))
            }
            
            #if os(macOS)
            public init<CodableType: Codable>(
                _ codable: CodableType,
                keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy) {
                let enconder = JSONEncoder()
                enconder.keyEncodingStrategy = keyEncodingStrategy
                self.init(contentType: "application/json", content: try? enconder.encode(codable))
            }
            #endif
            
        }
        
        public enum Response {
            
            case success(ResponseContent?)
            case badRequest
            case internalError
            
            fileprivate var httpResponse: HTTPResponse {
                switch self {
                case .success(.none):
                    return .init(status: .ok)
                case .success(.some(let responseContent)):
                    if let body = responseContent.content {
                        return .init(status: .ok, headers: ["Content-Type" : responseContent.contentType], body: body)
                    } else {
                        return .init(status: .ok)
                    }
                case .badRequest:
                    return .init(status: .badRequest)
                case .internalError:
                    return .init(status: .internalServerError)
                }
            }
            
        }
        
        public typealias Handler = (Request) -> SignalProducer<Response, AnyError>
        
        final class Responder: HTTPServerResponder {
            
            fileprivate enum HandlerType {
                
                case permanent(Handler)
                case temporary(Handler)
                
                func handle(_ request: Request) -> SignalProducer<Response, AnyError> {
                    switch self {
                    case .permanent(let handler):
                        return handler(request)
                    case .temporary(let handler):
                        return handler(request)
                    }
                }
                
                var isTemporary: Bool {
                    if case .temporary = self {
                        return true
                    } else {
                        return false
                    }
                }
                
            }
            
            fileprivate var handlers: [String : HandlerType] = [:]

            func respond(to request: HTTPRequest, on worker: Worker) -> EventLoopFuture<HTTPResponse> {
                guard let handler = handlers[request.url.path] else {
                    print("WARN - Cannot handle request for path '\(request.url.path)'")
                    return worker.future(HTTPResponse(status: .notFound))
                }
                if handler.isTemporary {
                    handlers.removeValue(forKey: request.url.path)
                }
                let promise = worker.eventLoop.newPromise(HTTPResponse.self)
                handler.handle(Request(request)).startWithResult { result in
                    switch result {
                    case .success(let response):
                        promise.succeed(result: response.httpResponse)
                    case .failure(let error):
                        print("WARN - Handler for path '\(request.url.path)' returned an error: \(error)")
                        promise.fail(error: error)
                    }
                }
                return promise.futureResult
            }
            
            
        }
        
        public static func build(hostname: String = "0.0.0.0", port: Int = 8080)
            -> SignalProducer<BotEngine.HTTPServer, AnyError> {
            return SignalProducer { (observer, lifetime) in
                let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
                let responder = Responder()
                let host = URL(string: "http://\(hostname):\(port)")!
                let futureServer = HTTP.HTTPServer.start(
                    hostname: hostname,
                    port: port,
                    responder: responder,
                    on: group
                )
                futureServer.whenFailure { observer.send(error: AnyError($0)) }
                futureServer.whenSuccess {
                    observer.send(value: .init(host: host, server: $0, responder: responder, group: group))
                    observer.sendCompleted()
                }
            }
        }
        
        public let host: URL

        private let responder: Responder
        private let server: HTTP.HTTPServer
        private let group: EventLoopGroup
        
        private init(host: URL, server: HTTP.HTTPServer, responder: Responder, group: EventLoopGroup) {
            self.host = host
            self.server = server
            self.responder = responder
            self.group = group
            
            registerHandler(forPath: "/ping") { _ in .init(value: .success("pong")) }
        }
        
        public func registerHandler(forPath path: String, handler: @escaping Handler) {
            responder.handlers[path] = .permanent(handler)
        }
        
        public func registerTemporaryHandler(forPath path: String, handler: @escaping Handler) {
            print("Registering handler for path '\(path)'")
            responder.handlers[path] = .temporary(handler)
        }
        
        public func stop() throws {
            try server.close().wait()
            try group.syncShutdownGracefully()
        }
        
        public func wait() throws {
            try server.onClose.wait()
        }
        
    }
    
}

fileprivate func decodeFormEncodedParamaters(_ string: String) -> [String : String] {
    var result: [String : String] = [:]
    for parameter in string.split(separator: "&") {
        let keyValue = parameter.split(separator: "=")
        guard keyValue.count == 2 else {
            continue
        }
        result[String(keyValue[0])] = String(keyValue[1])
    }
    return result
}
