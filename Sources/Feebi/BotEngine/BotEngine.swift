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
    
    typealias MessageWithContext = (message: BehaviorMessage, context: BehaviorMessage.Context)
    typealias MessageProducer = SignalProducer<MessageWithContext, NoError>
    typealias BehaviorFactory = (MessageWithContext) -> ActiveBehavior?
    
    private let inputProducer: MessageProducer
    private let outputRenderer: BehaviorOutputRenderer
    private var activeBehaviors: [ChannelId : ActiveBehavior] = [:]
    private var behaviorFactories: [BehaviorFactory] = []
    private var disposable = CompositeDisposable()
    private let output: Signal<ChanneledBehaviorOutput, NoError>
    private let outputObserver: Signal<ChanneledBehaviorOutput, NoError>.Observer
    private let jobScheduler: JobScheduler
    
    init(inputProducer: SignalProducer<MessageWithContext, NoError>,
         outputRenderer: BehaviorOutputRenderer,
         repository: ObjectRepository) {
        self.inputProducer = inputProducer
        self.outputRenderer = outputRenderer
        self.jobScheduler = JobScheduler(repository: repository, outputRenderer: outputRenderer)
        (output, outputObserver) =  Signal<ChanneledBehaviorOutput, NoError>.pipe()
    }
    
    func start() {
        disposable.dispose()
        disposable = CompositeDisposable()
        disposable += inputProducer.startWithValues(handle(input:))
        output.observeValues { [weak self] in self?.outputRenderer.render(output: $0.output, forChannel: $0.channel) }
    }
    
    func registerBehaviorFactory(_ behaviorFactory: @escaping BehaviorFactory) {
        behaviorFactories.append(behaviorFactory)
    }
    
    func registerBehavior<BehaviorType: BehaviorProtocol>(_ behavior: BehaviorType) {
        registerBehaviorFactory(behavior.parse)
        scheduleJobs(from: behavior)
    }
    
    private func handle(input: MessageWithContext) {
        let channel = input.message.channel
        guard !input.message.isCancelMessage else {
            if let activeBehavior = activeBehaviors[channel] {
                activeBehaviors.removeValue(forKey: channel)
                send(reply: .cancelConfirmation(description: activeBehavior.descriptionForCancellation), for: channel)
            } else {
                send(reply: .nothingToCancel, for: channel)
            }
            return
        }
        
        if let activeBehavior = activeBehaviors[channel] {
            activeBehavior.handle(message: input.message, with: input.context)
            if activeBehavior.isInFinalState {
                activeBehaviors.removeValue(forKey: channel)
            }
            // TODO handle error state
            // if activeBehavior.isInErrorState
        } else if let activeBehavior = findBehavior(for: input) {
            activeBehavior.mount(with: outputObserver, scheduler: jobScheduler, for: channel)
            if !activeBehavior.isInFinalState {
                activeBehaviors[channel] = activeBehavior
            }
            // TODO handle error state
            // if activeBehavior.isInErrorState
        } else {
            send(reply: .dontUnderstandMessage, for: channel)
        }
    }
    
    private func findBehavior(for message: MessageWithContext) -> ActiveBehavior? {
        for behaviorFactory in behaviorFactories {
            if let activeBehavior = behaviorFactory(message) {
                return activeBehavior
            }
        }
        return .none
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
    
    func send(reply: DefaultReply, for channel: ChannelId) {
        send(message: reply.message, for: channel)
    }
    
    func send(message: String, for channel: ChannelId) {
        outputObserver.send(value: (.textMessage(message), channel))
    }
    
    private func send(output: BehaviorOutput, for channel: ChannelId) {
        outputObserver.send(value: (output, channel))
    }
    
}

fileprivate extension BotEngine {
    
    final class JobScheduler: BehaviorJobScheduler {
        
        private let queue = DispatchQueue(
            label: "BotEngine.JobScheduler.ScheduledJobsQueue",
            attributes: .concurrent
        )
        private let repository: ObjectRepository
        private let outputRenderer: BehaviorOutputRenderer
        
        init(repository: ObjectRepository, outputRenderer: BehaviorOutputRenderer) {
            self.repository = repository
            self.outputRenderer = outputRenderer
        }
        
        func startScheduledJobs<BehaviorType: BehaviorProtocol>(for behavior: BehaviorType) {
            guard let executor = behavior.schedulable?.executor else {
                return
            }
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
            guard let executor = behavior.schedulable?.executor else {
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
            queue.asyncAfter(deadline: .now() + scheduledJob.job.interval) {
                self.executeJob(scheduledJob, with: executor)
            }
        }
    
        func executeJob<BehaviorJobExecutorType: BehaviorJobExecutor>(_ scheduledJob: ScheduledJob<BehaviorJobExecutorType.JobMessageType>, with executor: BehaviorJobExecutorType) {
            executor.executeJob(with: scheduledJob.job.message).startWithResult { result in
                switch result {
                case .success(let output):
                    switch output {
                    case .completed:
                        if scheduledJob.isCancelable {
                            self.deleteJob(scheduledJob)
                        } else {
                            // TODO better handle this case
                            let jobId = scheduledJob.id?.description ?? ".none"
                            print("WARN - Cannot cancel a non-cancelable job. Job id: \(jobId)")
                        }
                    case .success:
                        self.enqueueJob(scheduledJob, with: executor)
                    case .value(let behaviorOutput, let channel):
                        self.outputRenderer.render(output: behaviorOutput, forChannel: channel)
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
        
    }
    
    func scheduleJobs<BehaviorType: BehaviorProtocol>(from behavior: BehaviorType) {
        guard let schedulable = behavior.schedulable else {
            return
        }
        
        jobScheduler.startScheduledJobs(for: behavior)
        schedulable.jobs.forEach {
            jobScheduler.enqueueJob($0.asLongLivedJob(), with: schedulable.executor)
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
