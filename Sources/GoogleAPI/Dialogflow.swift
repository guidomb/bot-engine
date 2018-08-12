//
//  Dialogflow.swift
//  GoogleAPI
//
//  Created by Guido Marucci Blas on 8/11/18.
//

import Foundation

extension GoogleAPI {
    

    public struct Dialogflow {
        
        public struct Intents {
            
            private let basePath: String
            
            fileprivate init(basePath: String) {
                self.basePath = "\(basePath)/intents"
            }
            
            // https://cloud.google.com/dialogflow-enterprise/docs/reference/rest/v2beta1/projects.agent.intents/create
            public func create(intent: Intent, language: Intent.Language? = .none, intentView: Intent.IntentView? = .none) -> Resource<Intent> {
                return Resource(
                    path: basePath,
                    queryParameters: [
                        "language" : language.map { $0.rawValue },
                        "intentView" : intentView.map { $0.rawValue }
                    ].asQueryString,
                    requestBody: intent,
                    method: .post
                )
            }
            
            // https://cloud.google.com/dialogflow-enterprise/docs/reference/rest/v2beta1/projects.agent.intents/list
            public func list(options: ListIntentsOptions = .init()) -> Resource<IntentList> {
                return Resource(
                    path: basePath,
                    queryParameters: options,
                    method: .get
                )
            }
            
            // https://cloud.google.com/dialogflow-enterprise/docs/reference/rest/v2beta1/projects.agent.intents/delete
            public func delete(intentId: String) -> Resource<Void> {
                return Resource(
                    path: "\(basePath)/\(intentId)",
                    method: .delete
                )
            }
            
        }
        
        public struct Session {
            
            private let basePath: String
            
            fileprivate init(basePath: String, sessionId: String) {
                self.basePath = "\(basePath)/sessions/\(sessionId)"
            }
            
            // https://cloud.google.com/dialogflow-enterprise/docs/reference/rest/v2/projects.agent.sessions/detectIntent
            public func detectIntent(parameters: DetectIntentParameters) -> Resource<DetectIntentResponse> {
                return Resource(
                    path: "\(basePath):detectIntent",
                    requestBody: parameters,
                    method: .post
                )
            }
            
            public func detectIntent(text: String, languageCode: Intent.Language) -> Resource<DetectIntentResponse> {
                return detectIntent(parameters: .init(queryInput: .init(text: .init(text: text, languageCode: languageCode))))
            }
            
        }
        
        private let baseURL = "https://dialogflow.googleapis.com"
        private let basePath: String
        
        fileprivate init(version: String = "v2beta1", projectId: String) {
            self.basePath = "\(baseURL)/\(version)/projects/\(projectId)/agent"
        }
        
        public var intents: Intents {
            return .init(basePath: basePath)
        }
        
        public func session(sessionId: String) -> Session {
            return Session(basePath: basePath, sessionId: sessionId)
        }
        
    }
    
    public static func dialogflow(projectId: String) -> Dialogflow {
        return .init(projectId: projectId)
    }
    
}

public struct Intent: Codable {
    
    public enum IntentView: String, Codable  {
        
        case unspecified    = "INTENT_VIEW_UNSPECIFIED"
        case full           = "INTENT_VIEW_FULL"
        
    }
    
    public enum Language: String, Codable  {
        
        case latinAmericanSpanish   = "es-419"
        case spainSpanish           = "es-ES"
        case austrlianEnglish       = "en-AU"
        case canadianEnglish        = "en-CA"
        case greatBritainEnglish    = "en-GB"
        case indianEnglish          = "en-IN"
        case usEnglish              = "en-US"
        
    }
    
    public enum WebhookState: String, Codable  {
        
        case enabled                = "WEBHOOK_STATE_ENABLED"
        case enabledForSlotFilling  = "WEBHOOK_STATE_ENABLED_FOR_SLOT_FILLING"
        case unspecified            = "WEBHOOK_STATE_UNSPECIFIED"
        
    }
    
    public struct TrainingPhrase: Codable {
        
        public enum TrainingPhraseType: String, Codable  {
            
            case example        = "EXAMPLE"
            case template       = "TEMPLATE"
            case unspecified    = "TYPE_UNSPECIFIED"
            
        }
        
        public struct Part: Codable {
            
            public let text: String
            public let userDefined: Bool?
            public let alias: String?
            public let entityType: String?
            
            public init(text: String, userDefined: Bool? = .none, alias: String? = .none, entityType: String? = .none) {
                self.text = text
                self.userDefined = userDefined
                self.alias = alias
                self.entityType = entityType
            }
            
        }
        
        public let type: TrainingPhraseType
        public let parts: [Part]
        
        public init(type: TrainingPhraseType, parts: [Part]) {
            self.type = type
            self.parts = parts
        }
        
    }
    
    public struct Message: Codable {
        
        public struct Text: Codable {
            
            let text: [String]
            
            public init(text: [String]) {
                self.text = text
            }
            
        }
        
        let text: Text
        
        public init(text: Text) {
            self.text = text
        }
        
        public init(text: String...) {
            self.text = Text(text: text)
        }
        
    }
    
    public let name: String?
    public let displayName: String
    public let priority: UInt?
    public let action: String?
    public let webhookState: WebhookState?
    public let trainingPhrases: [TrainingPhrase]?
    public let messages: [Message]?
    
    public var id: String? {
        return name.flatMap { $0.split(separator: "/").last.map(String.init) }
    }
    
    public init(
        displayName: String,
        priority: UInt,
        action: String,
        webhookState: WebhookState,
        trainingPhrases: [TrainingPhrase],
        messages: [Message]) {
        self.name = .none
        self.displayName = displayName
        self.priority = priority
        self.action = action
        self.webhookState = webhookState
        self.trainingPhrases = trainingPhrases
        self.messages = messages
    }
    
}

public struct DetectIntentResponse: Codable {

    public struct QueryResult: Codable {
        
        public struct Context: Codable {
            
            let name: String
            let lifespanCount: Double
//            let parameters: [String : Any]
            
        }
        
        public let queryText: String
        public let languageCode: Intent.Language
        public let speechRecognitionConfidence: Double?
        public let action: String
//        let parameters: [String : Any]
        public let allRequiredParamsPresent: Bool
        public let fulfillmentText: String
        public let fulfillmentMessages: [Intent.Message]
        public let webhookSource: String?
//        let webhookPayload: [String : Any]
        public let outputContexts: [Context]?
        public let intent: Intent
        public let intentDetectionConfidence: Double
//        let diagnosticInfo: [String : Any]
        
    }
    
    public let responseId: String
    public let queryResult: QueryResult
    
}

public struct QueryInput: Codable {
    
    public struct TextInput: Codable {
        
        public let text: String
        public let languageCode: Intent.Language
        
        public init(text: String, languageCode: Intent.Language) {
            self.text = text
            self.languageCode = languageCode
        }
        
    }
    
    public let text: TextInput
    
}

public struct DetectIntentParameters: Codable {
    
    let queryInput: QueryInput
    
}

public struct IntentList: Paginable, Decodable {
    
    public let intents: [Intent]?
    public let nextPageToken: String?
    
}

public struct ListIntentsOptions: PaginableFetcherOptions, QueryStringConvertible {
    
    public var languageCode: Intent.Language?
    public var pageSize: Int?
    public var pageToken: String?
    public var intentView: Intent.IntentView?
    
    public var asQueryString: String {
        return toQueryString(object: self) ?? ""
    }
    
    public init() { }
    
}
