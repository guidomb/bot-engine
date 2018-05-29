//
//  Forms.swift
//  FeebiKit
//
//  Created by Guido Marucci Blas on 5/2/18.
//

import Foundation
import ReactiveSwift

public extension GoogleAPI {
    
    public typealias FormResource = Resource<ScriptExecutionResponse<Form>>
    public typealias FormProducer = SignalProducer<Form, FormRequestError>
    
    public enum FormRequestError: Error {
    
        case requestError(RequestError)
        case scriptExecutionError(ScriptExecutionResponse<Form>.ErrorStatus)
    }
    
    public struct Forms {
        
        let scriptId: String
        let devMode: Bool
        
        fileprivate init(scriptId: String, devMode: Bool) {
            self.scriptId = scriptId
            self.devMode = devMode
        }
        
        public func fetchForm(byId formId: String) -> FormResource {
            return GoogleAPI.scripts.run(
                scriptId: scriptId,
                parameters: ScriptParameters(
                    function: "fetchForm",
                    parameters: [.string(formId)],
                    devMode: devMode
                ),
                response: Form.self
            )
        }
        
    }
    
    public static func forms(usingScript scriptId: String, devMode: Bool = false) -> Forms {
        return Forms(scriptId: scriptId, devMode: devMode)
    }
    
}

public extension GoogleAPI.Resource where T == ScriptExecutionResponse<Form> {
    
    func execute(using token: GoogleAPI.Token,
                 with executor: GoogleAPIResourceExecutor = GoogleAPI.shared) -> GoogleAPI.FormProducer {
        return executor.execute(resource: self, token: token)
            .mapError(GoogleAPI.FormRequestError.requestError)
            .flatMap(.concat) { scriptResponse -> GoogleAPI.FormProducer in
                switch scriptResponse {
                case .success(let response):
                    return GoogleAPI.FormProducer(value: response.result)
                case .failure(let error):
                    return GoogleAPI.FormProducer(error: GoogleAPI.FormRequestError.scriptExecutionError(error))
                }
            }
    }
    
}

// MARK: - Data models

public struct Form: Decodable {
    
    public struct ChoiceItem: Decodable {
        
        public let value: String
        public let isCorrectAnswer: Bool
        
    }
    
    public enum ItemType {
        
        case text
        case paragraphText
        case multipleChoice(hasOtherOption: Bool, choices: [ChoiceItem])
        case list(hasOtherOption: Bool, choices: [ChoiceItem])
        case checkbox(hasOtherOption: Bool, choices: [ChoiceItem])
        case date(includesYear: Bool)
        case dateTime(includesYear: Bool)
        
        public var key: ItemTypeKey {
            switch self {
            case .text:             return .text
            case .paragraphText:    return .paragraphText
            case .multipleChoice:   return .multipleChoice
            case .list:             return .list
            case .checkbox:         return .checkbox
            case .date:             return .date
            case .dateTime:         return .dateTime
            }
        }
    }
    
    public struct Item: Decodable {
        
        public let title: String
        public let helpText: String
        public let itemType: ItemType
        public let isRequired: Bool
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = try container.decode(String.self, forKey: .title)
            helpText = try container.decode(String.self, forKey: .helpText)
            isRequired = try container.decode(Bool.self, forKey: .isRequired)
            
            switch try container.decode(ItemTypeKey.self, forKey: .itemType) {
            case .paragraphText:
                itemType = .paragraphText
            case .text:
                itemType = .text
            case .multipleChoice:
                itemType = .multipleChoice(
                    hasOtherOption: try container.decode(Bool.self, forKey: .hasOtherOption),
                    choices: try container.decode([ChoiceItem].self, forKey: .choices)
                )
            case .list:
                itemType = .list(
                    hasOtherOption: try container.decode(Bool.self, forKey: .hasOtherOption),
                    choices: try container.decode([ChoiceItem].self, forKey: .choices)
                )
            case .checkbox:
                itemType = .checkbox(
                    hasOtherOption: try container.decode(Bool.self, forKey: .hasOtherOption),
                    choices: try container.decode([ChoiceItem].self, forKey: .choices)
                )
            case .date:
                itemType = .date(includesYear: try container.decode(Bool.self, forKey: .includesYear))
            case .dateTime:
                itemType = .dateTime(includesYear: try container.decode(Bool.self, forKey: .includesYear))
            }
        }
        
        enum CodingKeys: CodingKey {
            
            case title
            case helpText
            case itemType
            case isRequired
            case choices
            case hasOtherOption
            case includesYear
            
        }
        
    }
    
    public enum ItemTypeKey: String, Decodable {
        
        case text = "TEXT"
        case paragraphText = "PARAGRAPH_TEXT"
        case multipleChoice = "MULTIPLE_CHOICE"
        case date = "DATE"
        case dateTime = "DATETIME"
        case list = "LIST"
        case checkbox = "CHECKBOX"
    }
    
    public struct ItemContainer: Decodable {
        
        public let isSupported: Bool
        public let item: Item?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            isSupported = try container.decode(Bool.self, forKey: .supported)
            if isSupported {
                item = try Item(from: decoder)
            } else {
                item = .none
            }
        }
        
        enum CodingKeys: CodingKey {
            
            case supported
            
        }
        
    }
    
    public let description: String
    public let title: String
    public let items: [ItemContainer]
    public var supportedItems: [Item] {
        return items
            .lazy
            .filter { $0.isSupported }
            .map { $0.item! }
    }
    
}
