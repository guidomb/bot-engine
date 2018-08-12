//
//  BotEngine.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation
@_exported import Result
@_exported import ReactiveSwift
@_exported import GoogleAPI

public protocol BotEngineAction {
    
    typealias Key = String
    
    var startingMessage: String? { get }
    
    func execute(using services: BotEngine.Services) -> BotEngine.ActionOutputMessageProducer
    
}

public extension BotEngineAction {
    
    var startingMessage: String? {
        return .none
    }
    
}

public struct SchedulableBotEngineAction: Persistable {
    
    public var id: Identifier<SchedulableBotEngineAction>?
    public let key: BotEngineAction.Key
    public let interval: SchedulerInterval
    
}

public protocol BotEngineCommand {
    
    associatedtype ParametersType
    
    var commandUsage: String { get }
    
    var permission: BotEngine.ExecutionPermission { get }
    
    func parseInput(_ input: String) -> ParametersType?
    
    func execute(using services: BotEngine.Services, parameters: ParametersType, senderId: BotEngine.UserId)
        -> BotEngine.Producer<String>
    
}

extension BotEngineCommand {
    
    public func canBeExecuted(by user: BotEngine.UserId) -> Bool {
        switch permission {
        case .all:
            return true
        case .only(let allowedUsers):
            return allowedUsers.contains(user)
        }
    }
    
}

public final class BotEngine {
    
    public struct Services {
        
        public let environment: [String : String]
        public let repository: ObjectRepository
        public let googleAPIResourceExecutor: GoogleAPIResourceExecutor
        public let googleProjectId: String
        public let slackService: SlackServiceProtocol?
        
        public init(
            environment: [String : String] = ProcessInfo.processInfo.environment,
            repository: ObjectRepository,
            googleAPIResourceExecutor: GoogleAPIResourceExecutor,
            googleProjectId: String,
            slackService: SlackServiceProtocol? = .none) {
            self.environment = environment
            self.repository = repository
            self.googleAPIResourceExecutor = googleAPIResourceExecutor
            self.slackService = slackService
            self.googleProjectId = googleProjectId
        }
        
    }
    
    public enum ExecutionPermission {
        
        case all
        case only([UserId])
        
    }
    
    public struct ActionOutputMessage: ExpressibleByStringLiteral {
        
        public let message: String
        public let channel: ChannelId?
        
        public init(message: String, channel: ChannelId? = .none) {
            self.channel = channel
            self.message = message
        }
        
        public init(stringLiteral value: String) {
            self.init(message: value)
        }
        
    }
    
    public struct ErrorMessage: Error, ExpressibleByStringLiteral {
        
        public let message: String
        
        public init(message: String) {
            self.message = message
        }
        
        public init(stringLiteral value: String) {
            self.init(message: value)
        }
        
        public init(error: Error) {
            self.init(message: "\(error)")
        }
        
        public var localizedDescription: String {
            return message
        }
    }
    
    public enum Input {
        
        case message(message: BehaviorMessage, context: BehaviorMessage.Context)
        case interactiveMessageAnswer(answer: String, channel: ChannelId, senderId: BotEngine.UserId)
        
        var channel: ChannelId {
            switch self {
            case .message(let message, _):
                return message.channel
            case .interactiveMessageAnswer(_, let channel, _):
                return channel
            }
        }
        
        var senderId: BotEngine.UserId {
            switch self {
            case .message(let message, _):
                return message.senderId
            case .interactiveMessageAnswer(_, _, let senderId):
                return senderId
            }
        }
        
    }
    
    public struct UserId: Equatable, Hashable, Codable {
        
        public let value: String
        
        public init(value: String) {
            self.value = value
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.init(value: try container.decode(String.self))
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(value)
        }
        
    }
    
    struct ImpersonatorId: Equatable, Hashable {
        
        public let value: String
        
        init(value: String) {
            self.value = value
        }
        
    }
    
    public typealias Producer<T> = SignalProducer<T, BotEngine.ErrorMessage>
    public typealias ActionOutputMessageProducer = Producer<ActionOutputMessage>
    public typealias InputProducer = SignalProducer<Input, NoError>
    public typealias MessageWithContext = (message: BehaviorMessage, context: BehaviorMessage.Context)
    public typealias BehaviorFactory = (MessageWithContext) -> ActiveBehavior?
    public typealias OutputSignal = Signal<ChanneledBehaviorOutput, NoError>
    
    public let services: Services
    public var admins: [UserId] = [] {
        didSet {
            registerInternalCommands()
        }
    }
    
    private let inputProducer: InputProducer
    private let outputRenderer: BehaviorOutputRenderer
    private let output: OutputSignal
    private let outputObserver: OutputSignal.Observer
    private let outputChannel: ChannelId
    private let jobScheduler: JobScheduler
    private let transformsRegistry = ResponseTransformRegistry()

    private var activeBehaviors: [ChannelId : ActiveBehavior] = [:]
    private var behaviorFactories: [BehaviorFactory] = []
    private var disposable = CompositeDisposable()
    private var boundActions: [String : BoundAction] = [:]
    private var commands: [RegisteredCommand] = []
    private var internalCommands: [RegisteredCommand] = []
    private var actionRegistry: [String : BotEngineAction] = [:]
    private var impersonators : [ImpersonatorId : UserId] = [:]
    
    fileprivate var repository: ObjectRepository {
        return services.repository
    }
    
    public init(inputProducer: InputProducer,
         outputRenderer: BehaviorOutputRenderer,
         outputChannel: ChannelId,
         services: Services) {
        (output, outputObserver) =  OutputSignal.pipe()
        self.inputProducer = inputProducer
        self.outputRenderer = outputRenderer
        self.services = services
        self.outputChannel = outputChannel
        self.jobScheduler = JobScheduler(
            services: services,
            outputRenderer: outputRenderer,
            outputChannel: outputChannel,
            transformsRegistry: transformsRegistry
        )
    }
    
    public func start() {
        disposable.dispose()
        disposable = CompositeDisposable()
        disposable += inputProducer.startWithValues(handle(input:))
        output.observeValues { [unowned self] in self.render(output: $0) }
        
        if actionRegistry.isEmpty {
            print("INFO - There are no registered schedulable actions.")
        } else {
            disposable += loadSchedulableActions().startWithResult { result in
                switch result {
                case .success(let actions):
                    print("INFO - \(actions.count) schedulable actions have been loaded")
                case .failure(let error):
                    print("ERROR - Schedulable actions could not be loaded: \(error.message)")
                    self.send(message: "Schedulable actions could not be loaded: \(error.message)")
                }
            }
        }
    }
    
    public func registerBehaviorFactory(_ behaviorFactory: @escaping BehaviorFactory) {
        behaviorFactories.append(behaviorFactory)
    }
    
    public func registerBehavior<BehaviorType: BehaviorProtocol>(_ behavior: BehaviorType) {
        registerBehaviorFactory(behavior.parse)
        scheduleJobs(from: behavior)
    }
    
    public func registerCommand<CommandType: BotEngineCommand>(_ command: CommandType) {
        commands.append(RegisteredCommand(command))
    }
    
    public func enqueueAction(_ action: BotEngineAction, interval: SchedulerInterval) {
        print("INFO - Enqueueing action '\(action.key)' to be executed \(interval)")
        jobScheduler.enqueueAction(action, interval: interval)
    }
    
    public func saveAction(_ action: BotEngineAction, interval: SchedulerInterval)
        -> SignalProducer<SchedulableBotEngineAction, ErrorMessage> {
        return services.repository.save(object:
            SchedulableBotEngineAction(
                id: .none,
                key: action.key,
                interval: interval
            )
        )
        .mapError(ErrorMessage.init(error:))
    }
    
    public func registerAction(_ action: BotEngineAction) {
        actionRegistry[action.key] = action
    }
    
    public func registerActions(_ actions: BotEngineAction...) {
        for action in actions {
            actionRegistry[action.key] = action
        }
    }
    
    public func loadSchedulableActions() -> SignalProducer<[SchedulableBotEngineAction], ErrorMessage> {
        return services.repository.fetchAll(SchedulableBotEngineAction.self)
            .on(failed: { print($0) })
            .mapError(ErrorMessage.init(error:))
            .on(starting: { print("INFO - Fetching schedulable actions ...") }, value: enqueueActions)
    }
    
    public func bindAction(_ action: BotEngineAction, to command: String, allow permission: ExecutionPermission = .all) {
        boundActions[command] = BoundAction(action: action, permission: permission)
    }
    
    public func executeAction(_ action: BotEngineAction) -> ActionOutputMessageProducer {
        return action.execute(using: services)
    }
    
}

fileprivate extension BotEngine {
    
    struct BoundAction {
        
        let action: BotEngineAction
        let permission: ExecutionPermission
        
        func canBeExecuted(by senderId: UserId) -> Bool {
            switch permission {
            case .all:
                return true
            case .only(let allowedSenders):
                return allowedSenders.contains(senderId)
            }
        }
        
    }
    
    enum DefaultReply {
        
        case dontUnderstandMessage
        case nothingToCancel
        case cancelConfirmation(description: String)
        case internalError
        
        var message: String {
            switch self {
            case .dontUnderstandMessage:
                return "Sorry, I don't understand that."
            case .nothingToCancel:
                return "There is nothing for me to cancel."
            case .cancelConfirmation(let description):
                return "OK. I cancelled \(description)."
            case .internalError:
                return "Oops! Something went wrong. I feel a little bit confused. Could you try that again later."
            }
        }
    }
    
    func handle(input: Input) {
        // Input transforms are registered by behavior
        // that start a conversation with a user.
        // Transforms are used to transforms the answer
        // a question a bot may have asked to user into
        // an input that can be understood by another
        // behavior to trigger a conversation.
        //
        // For example if a behavior starts an scheduled
        // job that asks a questions using interactive
        // buttons to a group of users, when a user
        // clicks on a button that actions sends
        // a text message as a response.
        //
        // Lets say that answer is the string "yes".
        // If we want to to trigger a behavior where the initial
        // input should "start process", we then
        // need to register an input transform the user's
        // channel to transform "yes" into "start process".
        //
        // Then the transformed input is handled as any
        // other input. There can only be one registered
        // input transform per channel. Which means that
        // you cannot ask user more than a question
        // at a given time.
        switch transformsRegistry.applyTransform(to: input) {
        case .message(let message, let context):
            handle(message: applyImpersonationIfNeeded(message), context: context)
        case .interactiveMessageAnswer(let answer, let channel, let senderId):
            handle(answer: answer, channel: channel, senderId: applyImpersonationIfNeeded(senderId))
        }
    }
    
    func handle(message: BehaviorMessage, context: BehaviorMessage.Context) {
        let channel = message.channel
        guard !message.isCancelMessage else {
            cancelActiveBehavior(for: channel)
            return
        }
        
        if let activeBehavior = activeBehaviors[channel] {
            activeBehavior.handle(input: .message(message: message, context: context))
        } else if let command = findCommand(for: message) {
            handle(command: command, with: message, channel: channel)
        } else if let action = boundActions[message.text] {
            handle(action: action, channel: channel, message: message)
        } else if let activeBehavior = findBehavior(for: (message, context)) {
            mount(behavior: activeBehavior, for: channel)
        } else {
            matchIntent(for: message, channel: channel)
        }
    }
    
    func handle(command: RegisteredCommand.BoundHandler, with message: BehaviorMessage, channel: ChannelId) {
        command(message.senderId, message.originalSenderId, services).startWithResult { result in
            switch result {
            case .success(let output):
                self.send(message: output, for: channel)
            case .failure(let error):
                self.send(message: error.message, for: channel)
            }
        }
    }
    
    func handle(action boundAction: BoundAction, channel: ChannelId, message: BehaviorMessage) {
        guard boundAction.canBeExecuted(by: message.originalSenderId) else {
            send(message: "Sorry, you are not allowed to execute such action", for: channel)
            return
        }
        
        func sendStartingMessage() {
            if let startingMessage = boundAction.action.startingMessage {
                send(message: startingMessage, for: channel)
            }
        }
        
        boundAction.action.execute(using: self.services)
            .on(starting: sendStartingMessage)
            .startWithResult { result in
                switch result {
                case .success(let output):
                    self.send(message: output.message, for: channel)
                    if let outputChannel = output.channel {
                        self.send(message: output.message, for: outputChannel)
                    }
                case .failure(let error):
                    self.send(message: "Action failed with error: \(error)", for: channel)
                }
        }
    }
    
    func handle(answer: String, channel: ChannelId, senderId: UserId) {
        guard let activeBehavior = activeBehaviors[channel] else {
            print("WARN - There is not active behavior for channel '\(channel)' to handle interactive message answer 'answer'")
            return
        }
        
        activeBehavior.handle(input: .interactiveMessageAnswer(answer: answer, channel: channel, senderId: senderId))
    }
    
    func mount(behavior: ActiveBehavior, for channel: ChannelId) {
        behavior.mount(
            using: BehaviorDependencies(scheduler: jobScheduler, services: services),
            with: outputObserver,
            for: channel
        )
        if !behavior.isInFinalState.value {
            activeBehaviors[channel] = behavior
            behavior.isInFinalState.signal
                .filter { $0 }
                .observeValues { [weak self] _ in self?.removeActiveBehavior(for: channel) }
            // TODO handle error state
            // We should observe if active behavior transitions to an error state, handle the error
            // by reporting it to the client and maybe creating an issue and the removing the
            // active behavior.
        }
        // TODO handle error state
        // if activeBehavior.isInErrorState
    }
    
    func matchIntent(for message: BehaviorMessage, channel: ChannelId) {
        services.intentMatcher.matchIntent(text: message.text, userId: message.senderId).startWithResult { result in
            switch result {
            case .success(let answer):
                self.send(message: answer, for: channel)
            case .failure(let error):
                print("ERROR - Could not match intent: \(error)")
                self.send(reply: .internalError, for: channel)
            }
        }
    }
    
    func findCommand(for message: BehaviorMessage) -> RegisteredCommand.BoundHandler? {
        for command in (commands + internalCommands) {
            if let handler = command.handle(input: message.text) {
                return handler
            }
        }
        return .none
    }
    
    func findBehavior(for message: MessageWithContext) -> ActiveBehavior? {
        for behaviorFactory in behaviorFactories {
            if let activeBehavior = behaviorFactory(message) {
                return activeBehavior
            }
        }
        return .none
    }
    
    func cancelActiveBehavior(for channel: ChannelId) {
        if let activeBehavior = activeBehaviors[channel] {
            removeActiveBehavior(for: channel)
            send(reply: .cancelConfirmation(description: activeBehavior.descriptionForCancellation), for: channel)
        } else {
            send(reply: .nothingToCancel, for: channel)
        }
    }
    
    func removeActiveBehavior(for channel: ChannelId) {
        activeBehaviors.removeValue(forKey: channel)
    }
    
    func render(output: ChanneledBehaviorOutput) {
        transformsRegistry.registerTransforms(output.transforms, for: output.channel)
        outputRenderer.render(output: output.output, forChannel: output.channel)
    }
    
    func send(reply: DefaultReply, for channel: ChannelId) {
        send(message: reply.message, for: channel)
    }
    
    func send(error: ErrorMessage, for channel: ChannelId? = .none) {
        send(message: error.message, for: channel ?? outputChannel)
    }
    
    func send(message: String, for channel: ChannelId? = .none) {
        outputObserver.send(value: .init(output: .textMessage(message), channel: channel ?? outputChannel))
    }
    
    func send(output: BehaviorOutput, for channel: ChannelId) {
        outputObserver.send(value: .init(output: output, channel: channel))
    }
    
    func scheduleJobs<BehaviorType: BehaviorProtocol>(from behavior: BehaviorType) {
        guard let schedulable = behavior.createSchedulable(services: services) else {
            return
        }
        
        jobScheduler.startScheduledJobs(for: behavior, with: schedulable.executor)
        schedulable.jobs.forEach {
            jobScheduler.enqueueJob($0.asLongLivedJob(), with: schedulable.executor)
        }
    }
    
    func enqueueActions(_ actions: [SchedulableBotEngineAction]) {
        guard !actions.isEmpty else {
            print("INFO - There are no schedulable actions to be enqueued")
            return
        }
        
        for schedulableAction in actions {
            guard let action = actionRegistry[schedulableAction.key] else {
                print("WARN - Cannot enqueue action because there is no action registered for key '\(schedulableAction.key)'")
                continue
            }
            enqueueAction(action, interval: schedulableAction.interval)
        }
    }
    
    func impersonate(user: UserId, with impersonator: ImpersonatorId) {
        impersonators[impersonator] = user
    }
        
    func registerInternalCommands() {
        internalCommands.append(impersonateUserCommand())
        internalCommands.append(clearImpersonationCommand())
        internalCommands.append(listCommandsCommand())
    }
    
    func applyImpersonationIfNeeded(_ sender: BotEngine.UserId) -> BotEngine.UserId {
        return impersonators[sender.asImpersonator] ?? sender
    }
    
    func applyImpersonationIfNeeded(_ message: BehaviorMessage) -> BehaviorMessage {
        return message.impersonate(user: applyImpersonationIfNeeded(message.senderId))
    }
    
}

fileprivate extension BotEngine {
    
    func impersonateUserCommand() -> RegisteredCommand {
        return .init(ImpersonateUser(admins: admins) { [unowned self] in self.impersonate(user: $0, with: $1) })
    }
    
    func clearImpersonationCommand() -> RegisteredCommand {
        return .init(SimpleCommand(command: "clear impersonation") { [unowned self] sender in
            // FIXME need originalSender to check impersonator dic
            if let impersonatee = self.impersonators[sender.asImpersonator] {
                return .init(value: "You stopped impersonating \(impersonatee.value)")
            } else {
                return .init(value: "You are not impersonating anyone")
            }
        })
    }
    
    func listCommandsCommand() -> RegisteredCommand {
        return .init(SimpleCommand(command: "list commands") { [unowned self] _ in
            let commandsList = (self.commands + self.internalCommands).map { "- *\($0.commandUsage)*" }
            let actionsList = self.boundActions.keys.map { "- *\($0)*" }
            let commands = (commandsList + actionsList).sorted().joined(separator: "\n")
            let message = """
            Commands:
            \(commands)
            """
            return .init(value: message)
        })
    }
    
}

extension BotEngine.UserId {
    
    var asImpersonator: BotEngine.ImpersonatorId {
        return .init(value: value)
    }
    
}

fileprivate final class ResponseTransformRegistry {
    
    private var transformsByChannel: [ChannelId : [ResponseTransform]] = [:]
    
    func registerTransforms(_ transforms: [ResponseTransform], for channel: ChannelId) {
        guard !transforms.isEmpty else {
            return
        }
        transformsByChannel[channel] = transforms
    }
    
    func applyTransform(to input: BotEngine.Input) -> BotEngine.Input {
        if let transform = transform(for: input) {
            transformsByChannel.removeValue(forKey: input.channel)
            return transform.transformedResponse
        } else {
            return input
        }
    }
    
    func transform(for input: BotEngine.Input) -> ResponseTransform? {
        guard let transforms = transformsByChannel[input.senderId.value] else {
            return .none
        }
        
        return transforms.first { transform in
            switch (transform.expectedResponse, input) {
            case (.message(let expectedMessage, _), .message(let message, _)):
                return expectedMessage.text == message.text
            case (.interactiveMessageAnswer(let expectedAnswer, _, _), .interactiveMessageAnswer(let answer, _, _)):
                return expectedAnswer == answer
            default:
                return false
            }
        }
    }
    
}

fileprivate final class JobScheduler: BehaviorJobScheduler {
    
    private let queue = DispatchQueue(
        label: "BotEngine.JobScheduler.ScheduledJobsQueue",
        attributes: .concurrent
    )
    private let services: BotEngine.Services
    private let outputRenderer: BehaviorOutputRenderer
    private let outputChannel: ChannelId
    private let transformsRegistry: ResponseTransformRegistry
    
    private var repository: ObjectRepository {
        return services.repository
    }
    
    init(
        services: BotEngine.Services,
        outputRenderer: BehaviorOutputRenderer,
        outputChannel: ChannelId,
        transformsRegistry: ResponseTransformRegistry) {
        self.services = services
        self.outputRenderer = outputRenderer
        self.outputChannel = outputChannel
        self.transformsRegistry = transformsRegistry
    }
    
    func startScheduledJobs<BehaviorType: BehaviorProtocol>(
        for behavior: BehaviorType,
        with executor: AnyBehaviorJobExecutor<BehaviorType.JobMessageType>) {
        
        guard case .some(let result) = repository.fetchAll(ScheduledJob<BehaviorType.JobMessageType>.self).first() else {
            fatalError("ERROR - Unable to fetch scheduled jobs for behavior \(String(describing: BehaviorType.self))")
        }
        
        switch result {
        case .success(let scheduledJobs):
            scheduledJobs.forEach { enqueueJob($0, with: executor) }
        case .failure(let error):
            fatalError("ERROR - Unable to fetch scheduled jobs for behavior \(String(describing: BehaviorType.self)): \(error)")
        }
    }
    
    func schedule<BehaviorType: BehaviorProtocol>(job: SchedulableJob<BehaviorType.JobMessageType>,
                                                  for behavior: BehaviorType) {
        guard let executor = behavior.createSchedulable(services: services)?.executor else {
            fatalError("ERROR - Cannot schedule job without executor.")
        }
        
        repository.save(object: job.asCancelableJob())
            .on(value: { self.enqueueJob($0, with: executor) })
            .startWithResult { result in
                switch result {
                case .success(let jobIdentifier):
                    print("INFO - Job with identifier '\(jobIdentifier)' successfuly scheduled")
                case .failure(let error):
                    let message = "ERROR - Job could not be scheduled: \(error)"
                    print(message)
                    self.render(output: .init(message: message))
                }
        }
    }
    
    func enqueueJob<BehaviorJobExecutorType: BehaviorJobExecutor>(_ scheduledJob: ScheduledJob<BehaviorJobExecutorType.JobMessageType>, with executor: BehaviorJobExecutorType) {
        guard let interval = scheduledJob.job.interval.intervalSinceNow() else {
            fatalError("ERROR - Could not get enqueue job. Unable to get scheduled job interval since now.")
        }

        queue.asyncAfter(deadline: .now() + interval) {
            self.executeJob(scheduledJob, with: executor)
        }
    }
    
    func enqueueAction(_ action: BotEngineAction, interval: SchedulerInterval) {
        guard let intervalSinceNow = interval.intervalSinceNow() else {
            fatalError("ERROR - Unable to get job interval since now.")
        }
        
        func renderStartingMessage() {
            print("INFO - Executing action \(action.key) ...")
            if let startingMessage = action.startingMessage {
                render(output: .init(message: startingMessage))
            }
        }
        
        print("DEBUG - Current time \(Date()). Interval since now \(intervalSinceNow) seconds")
        queue.asyncAfter(deadline: .now() + intervalSinceNow) {
            action.execute(using: self.services)
                .on(starting: renderStartingMessage)
                .startWithResult { result in
                    switch result {
                    case .success(let output):
                        print("INFO - \(action.key) - Action successfully executed:")
                        print(output.message.split(separator: "\n").map { "\t\($0)" }.joined(separator: "\n"))
                        self.render(output: output)
                        self.enqueueAction(action, interval: interval)
                    case .failure(let error):
                        let message = "Scheduled job failed with error: \(error)"
                        print("ERROR - \(action.key) - \(message)")
                        self.render(output: .init(message: message))
                    }
            }
        }
    }
    
    func executeJob<BehaviorJobExecutorType: BehaviorJobExecutor>(_ scheduledJob: ScheduledJob<BehaviorJobExecutorType.JobMessageType>, with executor: BehaviorJobExecutorType) {
        executor.executeJob(with: scheduledJob.job.message).startWithResult { result in
            switch result {
            case .success(let output):
                switch output {
                case .completed(let channeledOutputs):
                    self.render(outputs: channeledOutputs)
                    if scheduledJob.isCancelable {
                        self.deleteJob(scheduledJob)
                    } else {
                        // TODO better handle this case
                        let jobId = scheduledJob.id?.description ?? ".none"
                        print("WARN - Cannot cancel a non-cancelable job. Job id: \(jobId)")
                    }
                case .success(let channeledOutputs):
                    self.render(outputs: channeledOutputs)
                    self.enqueueJob(scheduledJob, with: executor)
                }
            case .failure(let error):
                // TODO Better handle this
                print("ERROR - Unable to execute scheduled job: \(error)")
            }
        }
    }
    
    func deleteJob<JobMessageType: Codable>(_ scheduledJob: ScheduledJob<JobMessageType>) {
        repository.delete(object: scheduledJob).startWithFailed { error in
            // TODO Better handle this
            print("ERROR - Unable to delete scheduled job: \(error)")
        }
    }
    
    func render(outputs: [ChanneledBehaviorOutput]) {
        for channeledOutput in outputs {
            transformsRegistry.registerTransforms(channeledOutput.transforms, for: channeledOutput.channel)
            outputRenderer.render(output: channeledOutput.output, forChannel: channeledOutput.channel)
        }
    }
    
    func render(output: BotEngine.ActionOutputMessage) {
        outputRenderer.render(output: .textMessage(output.message), forChannel: output.channel ?? outputChannel)
    }
    
}


fileprivate extension BehaviorProtocol {
    
    func parse(message: BehaviorMessage, with context: BehaviorMessage.Context) -> ActiveBehavior? {
        return create(message: message, context: context).map { transition in
            Behavior.Runner<Self.BehaviorJobExecutorType>(initialTransition: transition, behavior: AnyBehavior(self))
        }
    }
    
}

fileprivate struct RegisteredCommand {
    
    typealias BoundHandler = (BotEngine.UserId, BotEngine.UserId, BotEngine.Services) -> SignalProducer<String, BotEngine.ErrorMessage>
    
    let commandUsage: String
    private let _handle: (String) -> BoundHandler?
    private let permission: BotEngine.ExecutionPermission
    
    init<CommandType: BotEngineCommand>(_ command: CommandType) {
        self.commandUsage = command.commandUsage
        self._handle = { input in
            return command.parseInput(input).map { parameters in
                return { senderId, originalSender, services in
                    guard command.canBeExecuted(by: originalSender) else {
                        return .init(error: "Sorry, you are not allowed to execute such command.")
                    }
                    // FIXME Pass originalSenderId
                    return command.execute(using: services, parameters: parameters, senderId: senderId)
                }
            }
        }
        self.permission = command.permission
    }
    
    func handle(input: String) -> BoundHandler? {
        return _handle(input)
    }
    
}

fileprivate extension BotEngineAction {
    
    var key: BotEngineAction.Key {
        return String(describing: Self.self)
    }
}

fileprivate extension BotEngine.Services {
    
    var intentMatcher: IntentMatcherService {
        guard let slackService = self.slackService else {
            fatalError("ERROR - Slack service is not available")
        }
        return .init(
            projectId: self.googleProjectId,
            executor: self.googleAPIResourceExecutor,
            slackService: slackService
        )
    }
    
}
