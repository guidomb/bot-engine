//
//  Slack.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/5/18.
//

import Foundation
import ReactiveSwift
import Result
import SKClient
import SKCore
import SKRTMAPI
import SKWebAPI

public enum SlackServiceError: Swift.Error {
    
    case connectionAlreadyEstablished
    case webAPINotAvailable
    case sendMessageFailure(SlackError)
    case fetchUserInfoFailure(SlackError)
    case directMessageChannelNotAvailable
    case connectionFailure(Error)
    
}

public protocol SlackServiceProtocol {
    
    func start() -> SignalProducer<Event, SlackServiceError>
    
    func sendMessage(channel: String, text: String) -> SignalProducer<(), SlackServiceError>
    
    func sendMessage<ButtonType: ButtonMessage>(
        channel: String,
        text: String,
        buttonsSectionTitle: String,
        buttons: [ButtonType]) -> SignalProducer<ButtonType, SlackServiceError>
    
    func fetchUsers(userIds: [String]) -> SignalProducer<[SKCore.User], SlackServiceError>
    
    func fetchUserInfo(userId: String) -> SignalProducer<SKCore.User, SlackServiceError>

    func fetchUsersInChannel(_ channelId: String) -> SignalProducer<[SKCore.User], SlackServiceError>
    
    func openDirectMessageChannel(withUser userId: String) -> SignalProducer<String, SlackServiceError>
    
}

public protocol ButtonMessage {
    
    var text: String { get }
    var response: String { get }
    
    init?(from: String)
    
}

public final class SlackService: SlackServiceProtocol {
    
    private let middleware: SlackServiceActionMiddleware
    private let webAPI: WebAPI
    private let rtm: SKRTMAPI
    private let client = Client()
    
    private var observer: Signal<Event, SlackServiceError>.Observer?
    
    init(token: String, verificationToken: String) {
        self.webAPI = WebAPI(token: token)
        self.rtm = SKRTMAPI(withAPIToken: token, options: RTMOptions(), rtm: nil)
        self.middleware = SlackServiceActionMiddleware(verificationToken: verificationToken)
        self.rtm.adapter = self
    }
    
    public func registerActionHandler(with httpServer: BotEngine.HTTPServer) {
        httpServer.registerHandler(forPath: "/slackActions", handler: middleware.handleAction)
    }
    
    public func start() -> SignalProducer<Event, SlackServiceError> {
        guard observer == nil else {
            return SignalProducer(error: .connectionAlreadyEstablished)
        }
        return SignalProducer { observer, lifetime in
            self.observer = observer
            lifetime.observeEnded {
                self.middleware.stopActionHandlerCleaner()
            }
            self.middleware.startActionHandlerCleaner()
            self.rtm.connect()
        }
    }
    
    public func sendMessage(channel: String, text: String) -> SignalProducer<(), SlackServiceError> {
        return SignalProducer { [webAPI = self.webAPI] observer, _ in
            webAPI.sendMessage(
                channel: channel,
                text: text,
                success: { _ in observer.sendCompleted() },
                failure: { observer.send(error: .sendMessageFailure($0)) }
            )
        }
    }
    
    public func sendMessage<ButtonType: ButtonMessage>(
        channel: String,
        text: String,
        buttonsSectionTitle: String,
        buttons: [ButtonType]) -> SignalProducer<ButtonType, SlackServiceError> {
        let callbackID = "\(channel)-\(UUID().uuidString)"
        let actions = buttons.map {
            SKCore.Action(name: String(describing: ButtonType.self), text: $0.text, value: $0.text)
        }
        let fallbacks = text +
            buttons.enumerated().map { "\t\($0) - \($1.text)" }.joined(separator: "\n")
        let attachment = Attachment(fallback: fallbacks, title: buttonsSectionTitle, callbackID: callbackID, actions: actions)
        
        return SignalProducer { [middleware = self.middleware, webAPI = self.webAPI] observer, _ in
            middleware.registerObserver(observer, for: callbackID)
            webAPI.sendMessage(
                channel: channel,
                text: text,
                attachments: [attachment],
                success: { _ in print("DEBUG - Message with buttons sent. CallbackId: \(callbackID)") },
                failure: { observer.send(error: .sendMessageFailure($0)) }
            )
        }
    }
    
    public func fetchUsers(userIds: [String]) -> SignalProducer<[SKCore.User], SlackServiceError> {
        return SignalProducer.merge(userIds.map(fetchUserInfo)).collect()
    }
    
    public func fetchUserInfo(userId: String) -> SignalProducer<SKCore.User, SlackServiceError> {
        return SignalProducer { [webAPI = self.webAPI] observer, _ in
            webAPI.userInfo(
                id: userId,
                success: { user in
                    observer.send(value: user)
                    observer.sendCompleted()
                },
                failure: { observer.send(error: .fetchUserInfoFailure($0)) }
            )
        }
    }
    
    public func fetchUsersInChannel(_ channelId: String) -> SignalProducer<[SKCore.User], SlackServiceError> {
        return .empty
    }
    
    public func openDirectMessageChannel(withUser userId: String) -> SignalProducer<String, SlackServiceError> {
        return SignalProducer { [webAPI = self.webAPI] observer, _ in
            webAPI.openIM(
                userID: userId,
                success: { response in
                    if let directMessageChannel = response {
                        observer.send(value: directMessageChannel)
                        observer.sendCompleted()
                    } else {
                        observer.send(error: .directMessageChannelNotAvailable)
                    }
                },
                failure: { observer.send(error: .fetchUserInfoFailure($0)) })
        }
    }
}

extension SlackService: RTMAdapter {
    
    public func initialSetup(json: [String : Any], instance: SKRTMAPI) {
        client.initialSetup(JSON: json)
    }
    
    public func notificationForEvent(_ event: Event, type: EventType, instance: SKRTMAPI) {
        guard let observer = self.observer else {
            print("WARN - Slack event received but there is no active observer")
            return
        }
        
        client.notificationForEvent(event, type: type)
        guard event.message?.user != nil else {
            // We ignore messages from non-authenticated users
            // to avoid something that looks like a SlackKit bug.
            //
            // It seems that every message we send back to the users
            // gets sent to this closure which means that we receive
            // the messages that we send to the user which generates
            // an infinite loop of messages.
            return
        }
        // TODO Only responde to mentions in group channels and start a direct conversation
        observer.send(value: event)
    }
    
    public func connectionClosed(with error: Error, instance: SKRTMAPI) {
        guard let observer = self.observer else {
            print("WARN - Slack connection closed but there is no active observer")
            return
        }
        observer.send(error: .connectionFailure(error))
    }
    
}

public struct SlackOutputRenderer: BehaviorOutputRenderer {
    
    let slackService: SlackServiceProtocol
    
    fileprivate let (signal, observer) = Signal<(answer: String, channel: ChannelId, senderId: String), NoError>.pipe()
    
    public init(slackService: SlackServiceProtocol) {
        self.slackService = slackService
    }
    
    public func render(output: BehaviorOutput, forChannel channel: ChannelId) {
        // If you send a message to a User channel the message is sent
        // by Slackbot not by your application's bot. That is why we
        // need to open a direct message channel with a user.
        // More info: https://api.slack.com/methods/chat.postMessage#channels
        let actualOutputChannel: SignalProducer<String, SlackServiceError>
        if channel.starts(with: "U") {
            actualOutputChannel = slackService.openDirectMessageChannel(withUser: channel)
        } else {
            actualOutputChannel = SignalProducer(value: channel)
        }
        
        switch output {
        case .textMessage(let message):
            actualOutputChannel.flatMap(.concat) {
                self.slackService.sendMessage(channel: $0, text: message)
            }
            .startWithFailed { self.handle(error: $0, for: channel) }
            
        case .confirmationQuestion(let message, let question):
            actualOutputChannel.flatMap(.concat) { actualChannel in
                self.slackService.sendMessage(
                    channel: actualChannel,
                    text: message,
                    buttonsSectionTitle: question,
                    buttons: ConfirmationButton.options
                )
                .map { ($0, actualChannel) }
            }
            .startWithResult { result in
                switch result {
                case .success((let answer, let actualChannel)):
                    self.observer.send(value: (answer.text, actualChannel, channel))
                case .failure(let error):
                    self.handle(error: error, for: channel)
                }
            }
        }
    }
    
}

public extension BotEngine {
    
    static func slackBotEngine(
        server: BotEngine.HTTPServer,
        repository: ObjectRepository,
        context: [String : Any] = [:],
        environment: [String : String] = ProcessInfo.processInfo.environment) -> BotEngine {
        
        guard let token = environment["SLACK_API_TOKEN"] else {
            fatalError("ERROR - Missing Slack API token. You need to define SLACK_API_TOKEN env variable.")
        }
        guard let verificationToken = environment["SLACK_VERIFICATION_TOKEN"] else {
            fatalError("ERROR - Missing Slack verification token. You need to define SLACK_VERIFICATION_TOKEN env variable.")
        }
        
        let slackService = SlackService(token: token, verificationToken: verificationToken)
        slackService.registerActionHandler(with: server)
        
        let outputRenderer = SlackOutputRenderer(slackService: slackService)
        let messageProducer: BotEngine.InputProducer = slackService.start()
            .flatMapError { _ in .empty }
            .filterMap(eventToBehaviorMessage)
            .flatMap(.concat, addContextToBehaviorMessage(slackService: slackService))
        
        return BotEngine(
            inputProducer: BotEngine.InputProducer.merge([
                messageProducer,
                SignalProducer(outputRenderer.signal).map(BotEngine.Input.interactiveMessageAnswer)
                ]),
            outputRenderer: outputRenderer,
            services: BotEngine.Services(
                repository: repository,
                context: context,
                slackService: slackService
            )
        )
    }
    
}

fileprivate enum ConfirmationButton: String, ButtonMessage {
    
    static let options: [ConfirmationButton] = [.yes, .no]
    
    case yes
    case no
    
    var text: String {
        return self.rawValue
    }
    
    var response: String {
        return "👍"
    }
    
    init?(from: String) {
        self.init(rawValue: from)
    }
    
}

fileprivate extension SlackOutputRenderer {
    
    func handle(error: SlackServiceError, for channel: ChannelId) {
        print("Error sending message:")
        print("\tChannel: \(channel)")
        print("\tError: \(error)")
        print("")
    }
    
}

fileprivate extension UserEntityInfo {
    
    static func from(user: SKCore.User) -> UserEntityInfo {
        return UserEntityInfo(
            id: user.id!,
            name: user.name,
            email: user.profile?.email,
            firstName: user.profile?.firstName,
            lastName: user.profile?.lastName
        )
    }
    
}

fileprivate final class SlackServiceActionMiddleware {
    
    struct InteractiveMessage: Decodable {
        
        struct SelectAction: Decodable {
            
            let value: String
            
        }
        
        enum Action: Decodable {
            
            enum CodingKeys: String, CodingKey {
                
                case type = "type"
                case name = "name"
                case value = "value"
                case selectedOptions  = "selected_options"
                
            }
            
            enum ActionType: String, Decodable {
                
                case button
                case select
                
            }
            
            case button(name: String, value: String)
            case select(name: String, selectedOptions: [SelectAction])

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let name = try container.decode(String.self, forKey: .name)
                switch try container.decode(ActionType.self, forKey: .type) {
                case .button:
                    let value = try container.decode(String.self, forKey: .value)
                    self = .button(name: name, value: value)
                case .select:
                    let selectedOptions = try container.decode([SelectAction].self, forKey: .selectedOptions)
                    self = .select(name: name, selectedOptions: selectedOptions)
                }
            }
            
        }
        
        let type: String
        let token: String
        let callbackId: String
        let actions: [Action]
        
    }
    
    struct Response: Codable {
        
        enum CodingKeys: String, CodingKey {
            
            case text = "text"
            case responseType = "response_type"
            case replaceOriginal = "replace_original"
            
        }
        
        enum ResponseType: String, Codable {
            
            case inChannel = "in_channel"
            case ephemeral = "ephemeral"
            
        }
        
        let text: String
        let responseType: ResponseType
        let replaceOriginal: Bool
        
        var responseContent: BotEngine.HTTPServer.ResponseContent {
            return .init(self)
        }
        
        init(text: String, responseType: ResponseType = .inChannel, replaceOriginal: Bool = true) {
            self.text = text
            self.responseType = responseType
            self.replaceOriginal = replaceOriginal
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(text, forKey: .text)
            try container.encode(responseType, forKey: .responseType)
            try container.encode(replaceOriginal, forKey: .replaceOriginal)
        }
        
    }
    
    struct ActionHandler {
        
        let timestamp: Date
        private let handler: (String) -> String?
        
        init(_ handler: @escaping (String) -> String?) {
            self.handler = handler
            self.timestamp = Date()
        }

        func handle(action: String) -> String? {
            return handler(action)
        }
        
    }
    
    // TODO Make this thread safe!
    private var actionResponseObservers: [String : ActionHandler] = [:]
    private let verificationToken: String
    private let queue = DispatchQueue(
        label: "SlackService.ActionMiddleware.ActionHandlerCleaner"
    )
    private let cleanerInterval: TimeInterval = 10 * 60 * 60 // 10 hours
    // TODO Make this variable thread safe!
    private var cleanerEnabled = false
    
    init(verificationToken: String) {
        self.verificationToken = verificationToken
    }
    
    func handleAction(request: BotEngine.HTTPServer.Request) -> SignalProducer<BotEngine.HTTPServer.Response, AnyError> {
        guard let payloadData = request.formURLEncodedBody?["payload"]?.data(using: .utf8) else {
            print("WARN - Received slack action request does not contain payload")
            return .init(value: .badRequest)
        }
        
        let decoder = JSONDecoder()
        guard let message = try? decoder.decode(InteractiveMessage.self, from: payloadData) else {
            print("WARN - Received slack action request payload cannot be deserialized")
            return .init(value: .badRequest)
        }
        guard message.type == "interactive_message" else {
            print("WARN - Unsupported slack action payload type '\(message.type)'")
            return .init(value: .badRequest)
        }
        guard message.token == verificationToken else {
            print("WARN - Slack action payload token is not valid")
            return .init(value: .badRequest)
        }
        guard message.actions.count == 1 else {
            print("WARN - Slack action payload has more than one action")
            return .init(value: .badRequest)
        }
        guard case .button(_, let actionValue) = message.actions[0] else {
            print("WARN - Unsupported Slack action \(message.actions[0])")
            return .init(value: .badRequest)
        }
        guard let observer = actionResponseObservers[message.callbackId] else {
            print("WARN - There is no registered observer for Slack action with callback ID '\(message.callbackId)'")
            return .init(value: .internalError)
        }
        guard let response = observer.handle(action: actionValue) else {
            print("WARN - Slack action request could not be handled. Observer could not return a response text.")
            return .init(value: .badRequest)
        }
        
        print("DEBUG - Handling Slack action request with callback ID '\(message.callbackId)' and value '\(actionValue)'. Responding '\(response)'")
        actionResponseObservers.removeValue(forKey: message.callbackId)
        return .init(value: .success(Response(text: response).responseContent))
    }
    

    func registerObserver<ButtonType: ButtonMessage>(_ observer: Signal<ButtonType, SlackServiceError>.Observer,
                                                     for callbackID: String) {
        actionResponseObservers[callbackID] = ActionHandler { response in
            guard let value = ButtonType(from: response) else {
                print("WARN - SlackService action response '\(response)' for callbakckID '\(callbackID)' could not be converted to \(String(describing: ButtonType.self))")
                return .none
            }
            observer.send(value: value)
            observer.sendCompleted()
            return value.response
        }
    }
    
    func startActionHandlerCleaner() {
        self.cleanerEnabled = true
        queue.asyncAfter(deadline: .now() + cleanerInterval) {
            guard self.cleanerEnabled else {
                return
            }
            
            print("\(String(describing: SlackServiceActionMiddleware.self)) - Running action handler cleaner ...")
            for (key, actionHandler) in self.actionResponseObservers {
                if actionHandler.timestamp < (Date() - self.cleanerInterval) {
                    print("\(String(describing: SlackServiceActionMiddleware.self)) - Removing action handler '\(key)' with timestamp \(actionHandler.timestamp)")
                    self.actionResponseObservers.removeValue(forKey: key)
                }
            }
            self.startActionHandlerCleaner()
        }
    }
    
    func stopActionHandlerCleaner() {
        self.cleanerEnabled = false
    }
    
}

fileprivate func eventToBehaviorMessage(_ event: Event) -> BehaviorMessage? {
    guard   let channel = event.message?.channel,
            let messageText = event.message?.text,
            let userId = event.user?.id else {
        return nil
    }
    return BehaviorMessage(channel: channel, senderId: userId, text: messageText)
}

fileprivate func addContextToBehaviorMessage(slackService: SlackService) -> (BehaviorMessage) -> BotEngine.InputProducer {
    return { message in
        guard !message.entities.isEmpty else {
            return .init(value: .message(message: message, context: BehaviorMessage.Context()))
        }
        
        return slackService.fetchUsers(userIds: message.slackUserIdEntities)
            .map { .message(message: message, context: .with(users: $0)) }
            .flatMapError { _ in .empty }
    }
}

fileprivate extension BehaviorMessage.Context {
    
    static func with(users: [SKCore.User]) -> BehaviorMessage.Context {
        return BehaviorMessage.Context(userEntitiesInfo: users.map(UserEntityInfo.from))
    }
    
}
