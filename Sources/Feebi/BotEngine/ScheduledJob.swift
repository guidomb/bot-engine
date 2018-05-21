//
//  ScheduledJob.swift
//  Feebi
//
//  Created by Guido Marucci Blas on 5/17/18.
//

import Foundation
import Result
import ReactiveSwift

enum BehaviorJobOutput {
    
    case completed
    case success
    case value(behaviorOutput: BehaviorOutput, channel: ChannelId)
    
}

protocol BehaviorJobExecutor {
    
    associatedtype JobMessageType: Codable
    
    func executeJob(with message: JobMessageType) -> SignalProducer<BehaviorJobOutput, AnyError>
    
}

protocol BehaviorJobScheduler {
    
    func schedule<BehaviorType: BehaviorProtocol>(
        job: SchedulableJob<BehaviorType.JobMessageType>,
        for behavior: BehaviorType
    )
    
}

struct NoJobMessage: Codable {
    
    private let neededToMakeItConformToCodable: Int
    
}

struct SchedulableJob<JobMessageType: Codable>: Codable {
    
    let interval: TimeInterval
    let message: JobMessageType
    
    func asLongLivedJob() -> ScheduledJob<JobMessageType> {
        return ScheduledJob<JobMessageType>.longLived(self)
    }
    
    func asCancelableJob() -> ScheduledJob<JobMessageType> {
        return ScheduledJob<JobMessageType>.cancelableJob(self)
    }
    
}

struct ScheduledJob<JobMessageType: Codable>: Persistable, Codable {
    
    static func cancelableJob<JobMessageType: Codable>(_ job: SchedulableJob<JobMessageType>) -> ScheduledJob<JobMessageType> {
        return .init(job: job, isCancelable: true)
    }
    
    static func longLived<JobMessageType: Codable>(_ job: SchedulableJob<JobMessageType>) -> ScheduledJob<JobMessageType> {
        return .init(job: job, isCancelable: false)
    }
    
    var id: Identifier<ScheduledJob>?
    let isCancelable: Bool
    let job: SchedulableJob<JobMessageType>
    
    private init(id: Identifier<ScheduledJob>? = .none, job: SchedulableJob<JobMessageType>,  isCancelable: Bool) {
        self.id = id
        self.isCancelable = isCancelable
        self.job = job
    }
    
}

struct AnyBehaviorJobExecutor<JobMessageType: Codable>: BehaviorJobExecutor {
    
    private let _executeJob: (JobMessageType) -> SignalProducer<BehaviorJobOutput, AnyError>
    
    init<ScheduledJobExecutorType: BehaviorJobExecutor>(_ executor: ScheduledJobExecutorType)
        where JobMessageType == ScheduledJobExecutorType.JobMessageType {
        self._executeJob = executor.executeJob
    }
    
    func executeJob(with message: JobMessageType) -> SignalProducer<BehaviorJobOutput, AnyError> {
        return _executeJob(message)
    }
    
}

struct NoBehaviorJobExecutor: BehaviorJobExecutor {
    
    private init() {}
    
    func executeJob(with message: NoJobMessage) -> SignalProducer<BehaviorJobOutput, AnyError> {
        return .empty
    }
    
}

struct BehaviorSchedulableJobs<BehaviorJobExecutorType: BehaviorJobExecutor> {
    
    typealias JobMessageType = BehaviorJobExecutorType.JobMessageType
    
    let jobs: [SchedulableJob<JobMessageType>]
    let executor: AnyBehaviorJobExecutor<JobMessageType>
    
    init(jobs: [SchedulableJob<JobMessageType>] = [], executor: BehaviorJobExecutorType) {
        self.jobs = jobs
        self.executor = AnyBehaviorJobExecutor(executor)
    }
}
