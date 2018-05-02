//
//  Forms.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 4/25/18.
//

import Foundation

public extension GoogleAPI {
    
    struct Scripts {
        
        private let baseURL = "https://script.googleapis.com"
        private let version = "v1"
        
        private var basePath: String {
            return "\(baseURL)/\(version)/scripts"
        }
        
        fileprivate init() {}
        
        // https://developers.google.com/apps-script/api/reference/rest/v1/scripts/run
        public func run<Response: Decodable>(scriptId: String,
                                             parameters: ScriptParameters,
                                             response: Response.Type) -> Resource<ScriptExecutionResponse<Response>> {
            return Resource(
                path: "\(basePath)/\(scriptId):run",
                requestBody: parameters,
                method: .post
            )
        }
        
    }
    
    public static var scripts: Scripts { return Scripts() }
    
}

// MARK: - Data models

public struct ScriptParameters: Encodable {
    
    enum CodingKeys: CodingKey {
        
        case function
        case parameters
        case sessionState
        case devMode
        
    }
    
    public enum ParameterValue: Encodable {
        
        case string(String)
        case number(Double)
        case array([ParameterValue])
        case dictionary([String : ParameterValue])
        case boolean(Bool)
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value):
                try container.encode(value)
            case .number(let value):
                try container.encode(value)
            case .boolean(let value):
                try container.encode(value)
            case .array(let value):
                try container.encode(value)
            case .dictionary(let value):
                try container.encode(value)
            }
        }
        
    }
    
    public let function: String
    public let parameters: [ParameterValue]
    public let sessionState: String?
    public let devMode: Bool
    
    public init(function: String, parameters: [ParameterValue] = [], sessionState: String? = .none, devMode: Bool = false) {
        self.function = function
        self.parameters = parameters
        self.sessionState = sessionState
        self.devMode = devMode
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(function, forKey: .function)
        try container.encode(devMode, forKey: .devMode)
        if !parameters.isEmpty {
            try container.encode(parameters, forKey: .parameters)
        }
        if let sessionState = sessionState {
            try container.encode(sessionState, forKey: .sessionState)
        }
    }
    
}

public enum ScriptExecutionResponse<T: Decodable>: Decodable {
    
    public struct ErrorStatus: Decodable {
        
        public struct ScriptStackTraceElement: Decodable {
            
            public let function: String
            public let lineNumber: UInt
            
        }
        
        public struct Details: Decodable {
            
            public let scriptStackTraceElements: [ScriptStackTraceElement]
            public let errorMessage: String
            public let errorType: String
            
        }
        
        public let code: Int
        public let message: String
        public let details: Details
        
    }
    
    public struct SuccessfulResult<T: Decodable>: Decodable {
        
        let type: String
        let result: T
        
        
        enum CodingKeys: String, CodingKey {
            
            case type = "@type"
            case result = "result"
            
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try container.decode(String.self, forKey: .type)
            self.result = try container.decode(T.self, forKey: .result)
        }
    }
    
    case failure(ErrorStatus)
    case success(SuccessfulResult<T>)
    
    enum CodingKeys: CodingKey {
        
        case done
        case error
        case response
        
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let done = try container.decode(Bool.self, forKey: .done)
        if done {
            self = .success(try container.decode(SuccessfulResult<T>.self, forKey: .response))
        } else {
            self = .failure(try container.decode(ErrorStatus.self, forKey: .error))
        }
    }
    
}
