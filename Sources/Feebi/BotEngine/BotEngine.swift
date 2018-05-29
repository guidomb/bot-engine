//
//  BotEngine.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/15/18.
//

import Foundation
import Result
import ReactiveSwift

final class BotEngine {
    
    struct Services {
        
        var environment: [String : String]
        var repository: ObjectRepository
        var context: [String : Any]
        var slackService: SlackServiceProtocol?
        
        init(
            environment: [String : String] = ProcessInfo.processInfo.environment,
            repository: ObjectRepository,
            context: [String : Any] = [:],
            slackService: SlackServiceProtocol? = .none) {
            self.environment = environment
            self.repository = repository
            self.context = context
            self.slackService = slackService
        }
        
    }
    
    enum Input {
        
        case message(message: BehaviorMessage, context: BehaviorMessage.Context)
        case interactiveMessageAnswer(answer: String, channel: ChannelId, senderId: String)
        
        var channel: ChannelId {
            switch self {
            case .message(let message, _):
                return message.channel
            case .interactiveMessageAnswer(_, let channel, _):
                return channel
            }
        }
        
        var senderId: String {
            switch self {
            case .message(let message, _):
                return message.senderId
            case .interactiveMessageAnswer(_, _, let senderId):
                return senderId
            }
        }
        
    }
    
    typealias MessageWithContext = (message: BehaviorMessage, context: BehaviorMessage.Context)
    typealias InputProducer = SignalProducer<Input, NoError>
    typealias BehaviorFactory = (MessageWithContext) -> ActiveBehavior?
    typealias OutputSignal = Signal<ChanneledBehaviorOutput, NoError>
    
    private let inputProducer: InputProducer
    private let outputRenderer: BehaviorOutputRenderer
    private let output: OutputSignal
    private let outputObserver: OutputSignal.Observer
    private let services: Services
    private let jobScheduler: JobScheduler
    private let transformsRegistry = ResponseTransformRegistry()

    private var activeBehaviors: [ChannelId : ActiveBehavior] = [:]
    private var behaviorFactories: [BehaviorFactory] = []
    private var disposable = CompositeDisposable()
    
    fileprivate var repository: ObjectRepository {
        return services.repository
    }
    
    init(inputProducer: InputProducer,
         outputRenderer: BehaviorOutputRenderer,
         services: Services) {
        (output, outputObserver) =  OutputSignal.pipe()
        self.inputProducer = inputProducer
        self.outputRenderer = outputRenderer
        self.services = services
        self.jobScheduler = JobScheduler(
            services: services,
            outputRenderer: outputRenderer,
            transformsRegistry: transformsRegistry
        )
    }
    
    func start() {
        disposable.dispose()
        disposable = CompositeDisposable()
        disposable += inputProducer.startWithValues(handle(input:))
        output.observeValues { [unowned self] in self.render(output: $0) }
    }
    
    func registerBehaviorFactory(_ behaviorFactory: @escaping BehaviorFactory) {
        behaviorFactories.append(behaviorFactory)
    }
    
    func registerBehavior<BehaviorType: BehaviorProtocol>(_ behavior: BehaviorType) {
        registerBehaviorFactory(behavior.parse)
        scheduleJobs(from: behavior)
    }
    
}

fileprivate extension BotEngine {
    
    enum DefaultReply {
        
        case dontUnderstandMessage
        case nothingToCancel
        case cancelConfirmation(description: String)
        
        var message: String {
            switch self {
            case .dontUnderstandMessage:
                return "Sorry, I don't understand that."
            case .nothingToCancel:
                return "There is nothing for me to cancel."
            case .cancelConfirmation(let description):
                return "OK. I cancelled \(description)."
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
            handle(message: message, context: context)
        case .interactiveMessageAnswer(let answer, let channel, let senderId):
            handle(answer: answer, channel: channel, senderId: senderId)
        }
    }
    
    func handle(message: BehaviorMessage, context: BehaviorMessage.Context) {
        let channel = message.channel
        guard !message.isCancelMessage else {
            cancelActiveBehavior(for: channel)
            return
        }
        
        if let activeBehavior = activeBehaviors[channel] {
            handle(input: .message(message: message, context: context), with: activeBehavior)
        } else if let activeBehavior = findBehavior(for: (message, context)) {
            mount(behavior: activeBehavior, for: channel)
        } else {
            send(reply: .dontUnderstandMessage, for: channel)
        }
    }
    
    func handle(answer: String, channel: ChannelId, senderId: String) {
        guard let activeBehavior = activeBehaviors[channel] else {
            print("WARN - There is not active behavior for channel '\(channel)' to handle interactive message answer 'answer'")
            return
        }
        
        handle(input: .interactiveMessageAnswer(answer: answer, channel: channel, senderId: senderId), with: activeBehavior)
    }
    
    func handle(input: Input, with behavior: ActiveBehavior) {
        behavior.handle(input: input)
        if behavior.isInFinalState {
            activeBehaviors.removeValue(forKey: input.channel)
        }
        // TODO handle error state
        // if activeBehavior.isInErrorState
    }
    
    func mount(behavior: ActiveBehavior, for channel: ChannelId) {
        behavior.mount(
            using: BehaviorDependencies(scheduler: jobScheduler, services: services),
            with: outputObserver,
            for: channel
        )
        if !behavior.isInFinalState {
            activeBehaviors[channel] = behavior
        }
        // TODO handle error state
        // if activeBehavior.isInErrorState
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
            activeBehaviors.removeValue(forKey: channel)
            send(reply: .cancelConfirmation(description: activeBehavior.descriptionForCancellation), for: channel)
        } else {
            send(reply: .nothingToCancel, for: channel)
        }
    }
    
    func render(output: ChanneledBehaviorOutput) {
        transformsRegistry.registerTransforms(output.transforms, for: output.channel)
        outputRenderer.render(output: output.output, forChannel: output.channel)
    }
    
    func send(reply: DefaultReply, for channel: ChannelId) {
        send(message: reply.message, for: channel)
    }
    
    func send(message: String, for channel: ChannelId) {
        outputObserver.send(value: .init(output: .textMessage(message), channel: channel))
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
        guard let transforms = transformsByChannel[input.senderId] else {
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
    private let transformsRegistry: ResponseTransformRegistry
    
    private var repository: ObjectRepository {
        return services.repository
    }
    
    init(
        services: BotEngine.Services,
        outputRenderer: BehaviorOutputRenderer,
        transformsRegistry: ResponseTransformRegistry) {
        self.services = services
        self.outputRenderer = outputRenderer
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
                    break
                case .failure(let error):
                    // TODO report error
                    break
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
    
}


fileprivate extension BehaviorProtocol {
    
    func parse(message: BehaviorMessage, with context: BehaviorMessage.Context) -> ActiveBehavior? {
        return create(message: message, context: context).map { transition in
            Behavior.Runner<Self.BehaviorJobExecutorType>(initialTransition: transition, behavior: AnyBehavior(self))
        }
    }
    
}
