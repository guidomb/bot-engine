//
//  AddIntentBehavior.swift
//  BotEngineKit
//
//  Created by Guido Marucci Blas on 8/12/18.
//

import Foundation
import ReactiveSwift
import Result
import GoogleAPI

public struct AddIntentBehavior: BehaviorProtocol {
    
    public typealias _Behavior = Behavior<State, Effect>
    public typealias TransitionOutput = _Behavior.TransitionOutput
    public typealias Input = _Behavior.Input
    
    public var descriptionForCancellation: String {
        return "the intent creation process"
    }
    
    public init() { }
    
    public func createSchedulable(services: BotEngine.Services) -> BehaviorSchedulableJobs<NoBehaviorJobExecutor>? {
        return .none
    }
    
    public func createEffectPerformer(services: BotEngine.Services) -> EffectPerformer {
        return EffectPerformer(services: services)
    }
    
    public func create(message: BehaviorMessage, context: BehaviorMessage.Context) -> TransitionOutput? {
        let input = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input == "add new intent" else {
            return .none
        }
        
        return .waitingForIntentName
    }
    
    public func update(state: State, input: Input) -> TransitionOutput {
        switch input {
        case .message(let message, let context):
            return update(state: state, message: message, context: context)
        case .effectResult(let effectResult):
            return update(state: state, effectResult: effectResult)
        case .interactiveMessageAnswer(let answer, let senderId):
            return update(state: state, interactiveAnswer: answer, senderId: senderId)
        }
    }
    
}

extension AddIntentBehavior {
    
    public enum State: BehaviorState {
        
        case waitingForIntentName
        case validatingIfIntentExists(intentName: String)
        case intentAlreadyExists
        case waitingForIntentLanguage(intentName: String)
        case askingForTrainingPhrases(intentName: String, language: Intent.Language, trainingPhrases: [String])
        case intentValidationFailed(error: AddIntentBehavior.Effect.Error)
        case askingForIntentResponse(intentName: String, language: Intent.Language, trainingPhrases: [String])
        case creatingIntent(intentName: String, language: Intent.Language, trainingPhrases: [String], response: String)
        case intentCreationFailed(error: AddIntentBehavior.Effect.Error)
        case intentCreated(Intent)
        
        public var isFinalState: Bool {
            switch self {
            case .intentAlreadyExists, .intentValidationFailed, .intentCreated, .intentCreationFailed:
                return true
            default:
                return false
            }
        }
        
    }
    
}

extension AddIntentBehavior {
    
    public enum Effect: BehaviorEffect {
        
        public typealias ResponseType = Response
        public typealias ErrorType = Error
        public typealias JobMessageType = NoJobMessage
        
        public enum Error: Swift.Error, CustomStringConvertible {
    
            case userLanguageServiceError(AnyError)
            case dialogflowError(GoogleAPI.RequestError)
            
            public var localizedDescription: String {
                return description
            }
            
            public var description: String {
                switch self {
                case .dialogflowError:
                    return "Google Dialogflow API failure"
                case .userLanguageServiceError:
                    return "user language service failure"
                }
            }
            
        }
        
        public enum Response {
            
            case intentAlreadyExists
            case intentDoesNotExists
            case intentCreated(Intent)
        }
        
        case validateIfIntentExists(intentName: String)
        case createIntent(intentName: String, trainingPhrases: [String], response: String, language: Intent.Language)
        
    }
    
}

extension AddIntentBehavior {
    
    public struct EffectPerformer: BehaviorEffectPerformer {
        
        private let services: BotEngine.Services
        
        init(services: BotEngine.Services) {
            self.services = services
        }
        
        public func perform(effect: Effect, for channel: ChannelId) -> Effect.EffectOutputProducer {
            switch effect {
            case .validateIfIntentExists(let intentName):
                return listAllIntents()
                    .map(containsIntent(named: intentName))
                    .flatMapError(asEffectFailureResponse)
                
                
            case .createIntent(let intentName, let trainingPhrases, let response, let language):
                return GoogleAPI.dialogflow(projectId: services.googleProjectId)
                    .intents
                    .create(intent: createIntent(intentName, trainingPhrases, response), language: language)
                    .execute(with: services.googleAPIResourceExecutor)
                    .map(asEffectSuccessfulResponse)
                    .flatMapError(asEffectFailureResponse)
            }
        }
        
    }
    
}

fileprivate extension AddIntentBehavior.EffectPerformer {
    
    func asEffectFailureResponse(_ error: AddIntentBehavior.Effect.Error) -> AddIntentBehavior.Effect.EffectOutputProducer {
        return .init(value: (result: .failure(error), job: .none))
    }
    
    func asEffectFailureResponse(_ error: GoogleAPI.RequestError) -> AddIntentBehavior.Effect.EffectOutputProducer {
        return .init(value: (result: .failure(.dialogflowError(error)), job: .none))
    }
    
    func asEffectSuccessfulResponse(_ intent: Intent) -> AddIntentBehavior.Effect.EffectOutput {
        return  (result: .success(.intentCreated(intent)), job: .none)
    }
    
    func listAllIntents() -> SignalProducer<[Intent], AddIntentBehavior.Effect.Error> {
        return fetchAllPages(
            options: ListIntentsOptions(),
            using: listIntents,
            executor: services.googleAPIResourceExecutor,
            extract: \IntentList.intents
        )
        .mapError(AddIntentBehavior.Effect.Error.dialogflowError)
    }
    
    func listIntents(options: ListIntentsOptions) -> GoogleAPI.Resource<IntentList> {
        return GoogleAPI.dialogflow(projectId: services.googleProjectId)
            .intents
            .list(options: options)
    }
    
    func containsIntent(named intentName: String) -> ([Intent]) -> AddIntentBehavior.Effect.EffectOutput {
        return { intents in
            let included = intents.contains { $0.displayName == intentName }
            return (result: .success(included ? .intentAlreadyExists : .intentDoesNotExists), job: .none)
        }
    }
    
    func createIntent(_ intentName: String, _ trainingPhrases: [String], _ response: String) -> Intent {
        let action = intentName.lowercased().replacingOccurrences(of: " ", with: "_")
        return Intent(
            displayName: intentName,
            priority: 5000,
            action: action,
            webhookState: .unspecified,
            trainingPhrases: trainingPhrases.map {
                Intent.TrainingPhrase(type: .example, parts: [.init(text: $0)])
            },
            messages: [.init(text: response)]
        )
    }
    
}

fileprivate extension AddIntentBehavior {
    
    func update(state: State, message: BehaviorMessage, context: BehaviorMessage.Context) -> TransitionOutput {
        switch state {
            
        case .waitingForIntentName:
            let intentName = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return .validateIfIntentExists(intentName: intentName)
            
        case .validatingIfIntentExists:
            print("DEBUG - AddIntentBehavior: Ignoring messages while in validatingIfIntentExists state. Waiting for effect result")
            return .init(state: state)
            
        case .intentAlreadyExists, .intentValidationFailed:
            print("WARN - AddIntentBehavior: This should not happen. Cannot receive messages while in a final state.")
            return .init(state: state)
            
        case .waitingForIntentLanguage(let intentName):
            let language = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard language == "spanish" || language == "english" else {
                return .invalidIntentLanguage(intentName: intentName)
            }
            let intentLanguage: Intent.Language = language == "spanish" ? .spanish : .english
            return .askForFirstTrainingPhrase(intentName: intentName, language: intentLanguage)
            
        case .askingForTrainingPhrases(let intentName, let language, var trainingPhrases):
            let trainingPhrase = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trainingPhrase.isEmpty else {
                return .trainingPhraseCannotBeEmpty(intentName: intentName, language: language, trainingPhrases: trainingPhrases)
            }
            if trainingPhrase == "no" {
                if trainingPhrases.isEmpty {
                    return .trainingPhraseCannotBeEmpty(intentName: intentName, language: language, trainingPhrases: trainingPhrases)
                } else {
                    return .askForIntentResponse(intentName: intentName, language: language, trainingPhrases: trainingPhrases)
                }
            }
            
            trainingPhrases.append(trainingPhrase)
            return .askForNextTrainingPhrase(intentName: intentName, language: language, trainingPhrases: trainingPhrases)
            
        case .askingForIntentResponse(let intentName, let language, let trainingPhrases):
            let intentResponse = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !intentResponse.isEmpty else {
                return .intentResponseCannotBeEmpty(intentName: intentName, language: language, trainingPhrases: trainingPhrases)
            }
            return .createIntent(intentName: intentName, language: language, trainingPhrases: trainingPhrases, response: intentResponse)
            
        case .creatingIntent:
            print("DEBUG - AddIntentBehavior: Ignoring messages while in creatingIntent state. Waiting for effect result")
            return .init(state: state)
            
        case .intentCreationFailed:
            print("DEBUG - AddIntentBehavior: Ignoring messages while in intentCreationFailed state. Waiting for effect result")
            return .init(state: state)
            
        case .intentCreated:
            print("DEBUG - AddIntentBehavior: Ignoring messages while in intentCreated state. Waiting for effect result")
            return .init(state: state)
        }
    }
    
    func update(state: State, effectResult: Effect.EffectResult) -> TransitionOutput {
        switch (state, effectResult) {
        
        case (.validatingIfIntentExists(let intentName), .success(.intentAlreadyExists)):
            return .intentAlreadyExist(intentName: intentName)
            
        case (.validatingIfIntentExists(let intentName), .success(.intentDoesNotExists)):
            return .askForIntentLanguage(intentName: intentName)
            
        case (.validatingIfIntentExists(let intentName), .failure(let error)):
            return .validationError(intentName: intentName, error: error)
            
        case (.creatingIntent, .success(.intentCreated(let intent))):
            return .intentCreated(intent)
            
        case (.creatingIntent(let intentName, _, _, _), .failure(let error)):
            return .intentCreationError(intentName: intentName, error: error)
        
        default:
            print("WARN - AddIntentBehavior: Unexpected effect result while in state \(state)")
            return .init(state: state)
        
        }
    }
    
    func update(state: State, interactiveAnswer: String, senderId: BotEngine.UserId) -> TransitionOutput {
        print("ERROR - AddIntentBehavior: received an interactive answer '\(interactiveAnswer)' by '\(senderId.value)' when this behavior does not support interactive messages")
        return .init(state: state)
    }
    
}

fileprivate extension Behavior.TransitionOutput where
    StateType == AddIntentBehavior.State,
    EffectType == AddIntentBehavior.Effect {
    
    static var waitingForIntentName: AddIntentBehavior.TransitionOutput {
        return .init(state: .waitingForIntentName, output: .textMessage("What's the name of the intent?"))
    }
    
    static func validateIfIntentExists(intentName: String) -> AddIntentBehavior.TransitionOutput {
        return .init(
            state: .validatingIfIntentExists(intentName: intentName),
            output: .textMessage("Checking if an intent named '\(intentName)' already exists ..."),
            effect: .effect(.validateIfIntentExists(intentName: intentName))
        )
    }
    
    static func intentAlreadyExist(intentName: String) -> AddIntentBehavior.TransitionOutput {
        return .init(
            state: .intentAlreadyExists,
            output: .textMessage("Cannot add intent with name '\(intentName)' because it already exists")
        )
    }
    
    static func askForIntentLanguage(intentName: String) -> AddIntentBehavior.TransitionOutput {
        return .init(
            state: .waitingForIntentLanguage(intentName: intentName),
            output: .textMessage("Cool! There is no intent named '\(intentName)'.\nWhat's the intent language, spanish or english?")
        )
    }
    
    static func invalidIntentLanguage(intentName: String) -> AddIntentBehavior.TransitionOutput {
        return .init(
            state: .waitingForIntentLanguage(intentName: intentName),
            output: .textMessage("That's not a valid intent language. You need to pick between spanish or english")
        )
    }
    
    static func askForFirstTrainingPhrase(intentName: String, language: Intent.Language) -> AddIntentBehavior.TransitionOutput  {
        return .init(
            state: .askingForTrainingPhrases(intentName: intentName, language: language, trainingPhrases: []),
            output: .textMessage("I need at least one phrase example to associate with this intent. You can provide as many as you want.")
        )
    }
    
    static func askForNextTrainingPhrase(intentName: String, language: Intent.Language, trainingPhrases: [String]) -> AddIntentBehavior.TransitionOutput  {
        return .init(
            state: .askingForTrainingPhrases(intentName: intentName, language: language, trainingPhrases: trainingPhrases),
            output: .textMessage("Any other training phrase that you want to add? If not just say 'no'")
        )
    }
    
    static func validationError(intentName: String, error: AddIntentBehavior.Effect.Error) -> AddIntentBehavior.TransitionOutput  {
        return .init(
            state: .intentValidationFailed(error: error),
            output: .textMessage("Oops! There was an error while validating if an intent named '\(intentName)' already exists. Try again a little bit later. The error I got was a \(error)")
        )
    }
    
    static func trainingPhraseCannotBeEmpty(intentName: String, language: Intent.Language, trainingPhrases: [String]) -> AddIntentBehavior.TransitionOutput  {
        return .init(
            state: .askingForTrainingPhrases(intentName: intentName, language: language, trainingPhrases: trainingPhrases),
            output: .textMessage("The training phrase cannot be empty, please give me another one.")
        )
    }
    
    static func askForIntentResponse(intentName: String, language: Intent.Language, trainingPhrases: [String]) -> AddIntentBehavior.TransitionOutput  {
        return .init(
            state: .askingForIntentResponse(intentName: intentName, language: language, trainingPhrases: trainingPhrases),
            output: .textMessage("What should I responde when this intent is triggered?")
        )
    }
    
    static func intentResponseCannotBeEmpty(intentName: String, language: Intent.Language, trainingPhrases: [String]) -> AddIntentBehavior.TransitionOutput  {
        return .init(
            state: .askingForIntentResponse(intentName: intentName, language: language, trainingPhrases: trainingPhrases),
            output: .textMessage("The intent response cannot be empty, please give me another one.")
        )
    }
    
    static func createIntent(intentName: String, language: Intent.Language, trainingPhrases: [String], response: String) -> AddIntentBehavior.TransitionOutput  {
        return .init(
            state: .creatingIntent(intentName: intentName, language: language, trainingPhrases: trainingPhrases, response: response),
            output: .textMessage("Cool! I'm creating a new intent named '\(intentName)' ..."),
            effect: .effect(
                .createIntent(
                    intentName: intentName,
                    trainingPhrases: trainingPhrases,
                    response: response,
                    language: language
                )
            )
        )
    }
    
    static func intentCreationError(intentName: String, error: AddIntentBehavior.Effect.Error) -> AddIntentBehavior.TransitionOutput  {
        return .init(
            state: .intentCreationFailed(error: error),
            output: .textMessage("Oops! There was an error while creating the intent named '\(intentName)'. Try again a little bit later. The error I got was a \(error)")
        )
    }
    
    static func intentCreated(_ intent: Intent)  -> AddIntentBehavior.TransitionOutput  {
        return .init(
            state: .intentCreated(intent),
            output: .textMessage("Intent named '\(intent.displayName)' with ID *\(intent.id ?? "-")* successfully created.")
        )
    }
    
}
