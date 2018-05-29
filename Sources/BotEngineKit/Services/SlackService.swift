//
//  Slack.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/5/18.
//

import Foundation
import ReactiveSwift
import SlackKit
import Result
import SKCore

public enum SlackServiceError: Swift.Error {
    
    case connectionAlreadyEstablished
    case webAPINotAvailable
    case sendMessageFailure(SlackError)
    case fetchUserInfoFailure(SlackError)
    case directMessageChannelNotAvailable
    
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
    
    private let token: String
    private let middleware: SlackServiceActionMiddleware
    private var slackKit: SlackKit?
    
    init(token: String, verificationToken: String) {
        self.token = token
        self.middleware = SlackServiceActionMiddleware(verificationToken: verificationToken)
    }
    
    public func start() -> SignalProducer<Event, SlackServiceError> {
        guard self.slackKit == nil else {
            return SignalProducer(error: .connectionAlreadyEstablished)
        }
        return SignalProducer { observer, lifetime in
            let slackKit = self.createSlackClient()
            let actions = RequestRoute(path: "/actions", middleware: self.middleware)
            let responder = SlackKitResponder(routes: [actions])
            slackKit.addServer(responder: responder)
            slackKit.notificationForEvent(.message) { event, _ in
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
            lifetime.observeEnded {
                self.slackKit = nil
                self.middleware.stopActionHandlerCleaner()
            }
            self.middleware.startActionHandlerCleaner()
        }
    }
    
    public func sendMessage(channel: String, text: String) -> SignalProducer<(), SlackServiceError> {
        guard let webAPI = self.slackKit?.webAPI else {
            return SignalProducer(error: .webAPINotAvailable)
        }
        return SignalProducer { observer, _ in
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
        guard let webAPI = self.slackKit?.webAPI else {
            return SignalProducer(error: .webAPINotAvailable)
        }
        
        let callbackID = "\(channel)-\(UUID().uuidString)"
        let actions = buttons.map {
            SKCore.Action(name: String(describing: ButtonType.self), text: $0.text, value: $0.text)
        }
        let fallbacks = text +
            buttons.enumerated().map { "\t\($0) - \($1.text)" }.joined(separator: "\n")
        let attachment = Attachment(fallback: fallbacks, title: buttonsSectionTitle, callbackID: callbackID, actions: actions)
        
        return SignalProducer { [middleware = self.middleware] observer, _ in
            middleware.registerObserver(observer, for: callbackID)
            webAPI.sendMessage(
                channel: channel,
                text: text,
                attachments: [attachment],
                success: { _ in print("Message with buttons sent. CallbackId: \(callbackID)") },
                failure: { observer.send(error: .sendMessageFailure($0)) }
            )
        }
    }
    
    public func fetchUsers(userIds: [String]) -> SignalProducer<[SKCore.User], SlackServiceError> {
        return SignalProducer.merge(userIds.map(fetchUserInfo)).collect()
    }
    
    public func fetchUserInfo(userId: String) -> SignalProducer<SKCore.User, SlackServiceError> {
        guard let webAPI = self.slackKit?.webAPI else {
            return SignalProducer(error: .webAPINotAvailable)
        }
        return SignalProducer { observer, _ in
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
        guard let webAPI = self.slackKit?.webAPI else {
            return SignalProducer(error: .webAPINotAvailable)
        }
        return SignalProducer { observer, _ in
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

fileprivate extension SlackService {
    
    func createSlackClient() -> SlackKit {
        slackKit = SlackKit()
        slackKit?.addRTMBotWithAPIToken(token)
        slackKit?.addWebAPIAccessWithToken(token)
        return slackKit!
    }
    
}

fileprivate final class SlackServiceActionMiddleware: Middleware {
    
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
    
    func respond(to request: (RequestType, ResponseType)) -> (RequestType, ResponseType) {
        if let form = request.0.formURLEncodedBody.first(where: {$0.name == "ssl_check"}), form.value == "1" {
            return (request.0, Response(200))
        }
        guard   let actionRequest = MessageActionRequest(request: request.0),
                let callbackId = actionRequest.callbackID,
                let requestToken = actionRequest.token,
                requestToken == verificationToken,
                let actionValue = actionRequest.action?.value,
                let observer = actionResponseObservers[callbackId] else {
            print("WARN - Slack action request could not be handled.")
            return (request.0, Response(400))
        }
        guard let response = observer.handle(action: actionValue) else {
            print("WARN - Slack action request could not be handled. Observer could not return a response text.")
            return (request.0, Response(400))
        }
        actionResponseObservers.removeValue(forKey: callbackId)
        return (request.0, Response(response: SKResponse(text: response)))
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
